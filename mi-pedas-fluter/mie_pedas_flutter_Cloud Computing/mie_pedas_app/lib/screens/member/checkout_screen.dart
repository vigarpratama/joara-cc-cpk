// lib/screens/member/checkout_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/maps_service.dart';
import '../../widgets/widgets.dart';
import 'location_picker_screen.dart';
import 'qris_payment_screen.dart';
import '../../utils/api_config.dart';

class CheckoutScreen extends StatefulWidget {
  final VoidCallback? onCheckoutDone;
  const CheckoutScreen({super.key, this.onCheckoutDone});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  PaymentMethod _payment = PaymentMethod.cash;
  bool _loading = false;
  bool _loadingOngkir = false;
  Voucher? _appliedVoucher;
  double _ongkir = 10000;
  double _distanceKm = 0;
  bool _ongkirCalculated = false;
  LatLng? _pickedCoord; // koordinat dari location picker (kalau ada, prioritas dari teks)
  bool _suppressAddressChange = false; // guard biar autofill alamat gak ngehapus _pickedCoord
  String? _paymentProofPath; // foto bukti transfer/e-wallet/QRIS sebelum order dibuat

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _addressCtrl.text = user?.address ?? '';
    // Load data toko (buat ambil QRIS & koordinat toko yang BENAR, sesuai isi keranjang —
    // bukan dari sesi login, karena member gak punya "toko yang sedang login").
    // Ditunda sampai frame selesai supaya notifyListeners() tidak dipanggil saat build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StoreProvider>().loadStores();
    });
    // Auto hitung ongkir kalau alamat sudah ada
    if (user?.address.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hitungOngkir());
    }
  }

  // Toko tempat menu di keranjang ini berasal — SATU-SATUNYA sumber yang benar,
  // karena auth.currentStore cuma keisi untuk sesi ADMIN, bukan member.
  Store? _currentCartStore(BuildContext context) {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return null;
    final storeId = cart.items.first.menu.storeId;
    return context.read<StoreProvider>().stores.where((s) => s.id == storeId).firstOrNull;
  }

  Future<void> _hitungOngkir() async {
    setState(() => _loadingOngkir = true);

    final store = _currentCartStore(context);
    // Kalau toko punya koordinat sendiri, pakai itu. Kalau belum, fallback ke
    // titik default lama (biar gak error total, tapi jaraknya mungkin gak akurat).
    final storeCoord = (store != null && store.hasLocation)
      ? LatLng(store.latitude, store.longitude)
      : MapsService.storeLocation;

    // Kalau user udah pilih titik di peta, langsung pakai itu (lebih akurat, skip geocoding teks)
    if (_pickedCoord != null) {
      final result = await MapsService.getOngkirFromCoord(_pickedCoord!, storeCoord: storeCoord);
      if (!mounted) return;
      setState(() {
        _ongkir = result.ongkir;
        _distanceKm = result.distanceKm;
        _ongkirCalculated = result.success;
        _loadingOngkir = false;
      });
      return;
    }

    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      setState(() => _loadingOngkir = false);
      return;
    }
    final storeAddress = store?.address ?? '';
    final result = await MapsService.getOngkir(
      storeAddress: storeAddress,
      customerAddress: address,
      storeCoord: storeCoord,
    );
    if (!mounted) return;
    setState(() {
      _ongkir = result.ongkir;
      _distanceKm = result.distanceKm;
      _ongkirCalculated = result.success;
      _loadingOngkir = false;
    });
  }

  Future<void> _pilihLokasiPeta() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: _pickedCoord)),
    );
    if (result == null || !mounted) return;

    setState(() {
      _pickedCoord = result;
      _ongkirCalculated = false;
      _loadingOngkir = true;
    });

    // Auto-isi field alamat pakai reverse geocode, biar validasi "alamat gak
    // boleh kosong" lolos TANPA harus ngetik manual (yang bisa ngehapus pin).
    final label = await MapsService.reverseGeocode(result);
    if (!mounted) return;
    _suppressAddressChange = true;
    _addressCtrl.text = label ??
        'Lokasi dari peta (${result.lat.toStringAsFixed(5)}, ${result.lng.toStringAsFixed(5)})';

    await _hitungOngkir();
  }

  Future<void> _pickPaymentProof() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _paymentProofPath = picked.path);
  }

  double get _discount => _appliedVoucher?.calculateDiscount(context.read<CartProvider>().subtotal) ?? 0;

  // Mode backend + QRIS: QR dibuat payment-service (bukan foto QRIS toko), jadi tanpa dialog & tanpa upload bukti
  bool get _usesBackendQris => ApiConfig.useBackend && _payment == PaymentMethod.qris;

  Future<void> _placeOrder() async {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Alamat pengiriman tidak boleh kosong'), backgroundColor: AppColors.error));
      return;
    }

    // Cek ulang stok TERBARU sebelum lanjut checkout — stok bisa saja berubah
    // sejak item ditambahkan ke keranjang (mis. laku ke pembeli lain duluan).
    // CATATAN: getAllMenus()/getMenusByStore() cuma ambil isAvailable=1, dan
    // decrementMenuStock() otomatis mematikan menu begitu stoknya 0 — jadi
    // kalau menu gak ketemu lagi di sini, anggap aja itu tanda stoknya habis,
    // JANGAN fallback ke data lama dari keranjang (bisa salah/basi).
    final cartCheck = context.read<CartProvider>();
    await context.read<MenuProvider>().loadMenus();
    final latestMenus = context.read<MenuProvider>().menus;
    for (final item in cartCheck.items) {
      final latest = latestMenus.where((m) => m.id == item.menu.id).firstOrNull;
      if (latest == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${item.menu.name} sudah tidak tersedia (stok habis), hapus dulu dari keranjang'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
      if (latest.stock <= 0 || latest.stock < item.quantity) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(latest.stock <= 0
            ? '${item.menu.name} stoknya habis, hapus dulu dari keranjang'
            : '${item.menu.name} sisa stok cuma ${latest.stock}, kurangi jumlahnya dulu'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }

    if (_payment == PaymentMethod.qris && !_usesBackendQris) {
      final confirm = await _showQrisDialog();
      if (!confirm) return;
    } else if (_payment == PaymentMethod.transfer) {
      final confirm = await _showTransferDialog();
      if (!confirm) return;
    } else if (_payment == PaymentMethod.ewallet) {
      final confirm = await _showEwalletDialog();
      if (!confirm) return;
    }

    // Bukti pembayaran wajib buat metode non-tunai (transfer/e-wallet/QRIS)
    if (_payment != PaymentMethod.cash && !_usesBackendQris && _paymentProofPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Upload bukti pembayaran dulu sebelum pesan'), backgroundColor: AppColors.error));
      return;
    }

    // Hitung ongkir kalau belum, atau retry kalau sebelumnya gagal
    if (!_ongkirCalculated) await _hitungOngkir();

    if (!_ongkirCalculated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menghitung ongkir. Cek kembali alamat pengiriman, lalu coba lagi.'),
        backgroundColor: AppColors.error,
      ));
      return; // JANGAN lanjut order pakai ongkir default/fallback
    }

    setState(() => _loading = true);
    final cart = context.read<CartProvider>();
    final user = context.read<AuthProvider>().currentUser!;
    // PENTING: storeId HARUS dari menu di keranjang, bukan auth.currentStoreId —
    // itu cuma valid untuk sesi admin, member gak punya "toko yang sedang login".
    final storeId = cart.items.isNotEmpty ? cart.items.first.menu.storeId : '';

    Order? placed;
    try {
      placed = await context.read<OrderProvider>().placeOrder(
        member: user, items: cart.items,
        address: _addressCtrl.text.trim(),
        paymentMethod: _payment, note: _noteCtrl.text,
        discount: _discount,
        promoCode: _appliedVoucher?.code ?? '',
        storeId: storeId,
        deliveryFee: _ongkir,
        paymentProofPath: _paymentProofPath,
      );
    } catch (e) {
      // Gagal membuat pesanan di server: keranjang JANGAN dikosongkan, biarkan user coba lagi
      if (mounted) setState(() => _loading = false);
      return;
    }

    cart.clear();
    if (!mounted) return;
    await context.read<MenuProvider>().loadMenus();
    setState(() => _loading = false);

    // Callback kalau dari "Beli Langsung"
    widget.onCheckoutDone?.call();

    // QRIS lewat backend: lanjut ke layar bayar (menggantikan layar checkout)
    if (_usesBackendQris && placed != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => QrisPaymentScreen(order: placed!, popExtra: widget.onCheckoutDone != null)));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 64),
          const SizedBox(height: 16),
          const Text('Pesanan Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Pesanan kamu sedang diproses.\nEstimasi 30 menit.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ]),
        actions: [ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
            if (widget.onCheckoutDone != null) Navigator.pop(context);
          },
          child: const Text('OK'),
        )],
      ),
    );
  }

  Widget _qrisPlaceholder() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.qr_code_2, size: 120, color: AppColors.textPrimary),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
      child: const Text('QRIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 4)),
    ),
    const SizedBox(height: 6),
    const Text('Joara Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
  ]);

  Future<bool> _showQrisDialog() async {
    final store = _currentCartStore(context);
    final qrisPath = store?.qrisImageUrl ?? '';
    final hasQris = qrisPath.isNotEmpty && File(qrisPath).existsSync();
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.qr_code, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Bayar dengan QRIS'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Scan QR Code berikut untuk membayar:',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(12), color: Colors.white,
              ),
              child: hasQris
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(File(qrisPath), fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _qrisPlaceholder()),
                  )
                : _qrisPlaceholder(),
            ),
            const SizedBox(height: 16),
            if (!hasQris)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Toko belum mengunggah QRIS asli. Hubungi toko sebelum membayar.', style: TextStyle(fontSize: 11, color: AppColors.error))),
                ]),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 6),
                  Text('Cara Bayar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ]),
                SizedBox(height: 6),
                Text('1. Buka m-banking / dompet digital\n2. Pilih Scan QR / QRIS\n3. Scan QR Code di atas\n4. Masukkan nominal sesuai total\n5. Konfirmasi pembayaran',
                  style: TextStyle(fontSize: 12, height: 1.6)),
              ]),
            ),
            const SizedBox(height: 12),
            Consumer<CartProvider>(
              builder: (_, cart, __) => Text('Total: ${toRupiah(cart.grandTotal - _discount)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check), label: const Text('Sudah Bayar'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _copyableAmount(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    ]),
  );

  Future<bool> _showTransferDialog() async {
    final store = _currentCartStore(context);
    final hasBank = (store?.bankAccountNumber ?? '').isNotEmpty && (store?.bankName ?? '').isNotEmpty;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.account_balance, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Transfer Bank'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Transfer sejumlah total pesanan ke rekening toko berikut:',
              style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            if (hasBank) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                child: Text(store!.bankName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              _copyableAmount('No. Rekening', store.bankAccountNumber),
              const SizedBox(height: 10),
              _copyableAmount('Atas Nama', store.bankAccountName),
            ] else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Toko belum mendaftarkan rekening bank. Hubungi toko sebelum transfer.', style: TextStyle(fontSize: 11, color: AppColors.error))),
                ]),
              ),
            const SizedBox(height: 14),
            Consumer<CartProvider>(
              builder: (_, cart, __) => Text('Total: ${toRupiah(cart.grandTotal - _discount)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check), label: const Text('Sudah Transfer'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showEwalletDialog() async {
    final store = _currentCartStore(context);
    final options = <Map<String, String>>[
      if ((store?.gopayNumber ?? '').isNotEmpty) {'type': 'GoPay', 'number': store!.gopayNumber},
      if ((store?.ovoNumber ?? '').isNotEmpty) {'type': 'OVO', 'number': store!.ovoNumber},
      if ((store?.danaNumber ?? '').isNotEmpty) {'type': 'DANA', 'number': store!.danaNumber},
    ];
    String? selected = options.isNotEmpty ? options.first['type'] : null;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.account_balance_wallet, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Bayar dengan E-Wallet'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (options.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Toko belum mendaftarkan nomer e-wallet. Hubungi toko sebelum membayar.', style: TextStyle(fontSize: 11, color: AppColors.error))),
                  ]),
                )
              else ...[
                const Text('Pilih e-wallet yang mau kamu pakai:', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ...options.map((o) => RadioListTile<String>(
                  value: o['type']!, groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v),
                  title: Text(o['type']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 8),
                _copyableAmount(
                  'Nomer ${selected ?? ''} Toko',
                  options.firstWhere((o) => o['type'] == selected)['number']!,
                ),
              ],
              const SizedBox(height: 14),
              Consumer<CartProvider>(
                builder: (_, cart, __) => Text('Total: ${toRupiah(cart.grandTotal - _discount)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            ElevatedButton.icon(
              onPressed: options.isEmpty ? null : () => Navigator.pop(context, true),
              icon: const Icon(Icons.check), label: const Text('Sudah Bayar'),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final grandTotal = cart.subtotal + _ongkir - _discount;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Alamat
          _section('Alamat Pengiriman', icon: Icons.location_on_outlined,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  hintText: 'Masukkan alamat lengkap...',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 3,
                onChanged: (_) {
                  if (_suppressAddressChange) { _suppressAddressChange = false; return; }
                  setState(() { _ongkirCalculated = false; _pickedCoord = null; });
                },
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingOngkir ? null : _hitungOngkir,
                    icon: _loadingOngkir
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(_loadingOngkir ? 'Menghitung...' : 'Hitung Otomatis'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadingOngkir ? null : _pilihLokasiPeta,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Pilih di Peta'),
                  ),
                ),
              ]),
              if (_pickedCoord != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.pin_drop, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Lokasi dari peta digunakan (lebih akurat)', style: TextStyle(fontSize: 11, color: AppColors.primary))),
                    TextButton(
                      onPressed: () => setState(() { _pickedCoord = null; _ongkirCalculated = false; }),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      child: const Text('Hapus', style: TextStyle(fontSize: 11)),
                    ),
                  ]),
                ),
              ],
              if (_ongkirCalculated) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.route, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Jarak: ${_distanceKm.toStringAsFixed(1)} km', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w500))),
                    Text(toRupiah(_ongkir), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 14),

          // Metode Pembayaran
          _section('Metode Pembayaran', icon: Icons.credit_card,
            Column(children: PaymentMethod.values.map((p) => RadioListTile<PaymentMethod>(
              value: p, groupValue: _payment,
              onChanged: (v) => setState(() {
                _payment = v!;
                if (_payment == PaymentMethod.cash) _paymentProofPath = null;
              }),
              title: Row(children: [
                Text(_paymentLabel(p)),
                if (p == PaymentMethod.qris) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Recommended', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              subtitle: Text(_paymentDesc(p)),
              secondary: Icon(_paymentIcon(p), color: p == PaymentMethod.qris ? Colors.green : AppColors.primary),
              contentPadding: EdgeInsets.zero,
            )).toList()),
          ),

          if (_payment != PaymentMethod.cash && !_usesBackendQris) ...[
            const SizedBox(height: 14),
            _section('Bukti Pembayaran', icon: Icons.receipt_long,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _payment == PaymentMethod.qris
                    ? 'Scan QRIS di atas, transfer/bayar, lalu upload screenshot bukti bayarnya di sini.'
                    : 'Transfer/bayar sesuai info di atas, lalu upload screenshot atau foto bukti bayarnya di sini.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickPaymentProof,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 140, width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _paymentProofPath == null ? AppColors.divider : AppColors.success),
                    ),
                    child: _paymentProofPath == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                          Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 32),
                          SizedBox(height: 8),
                          Text('Upload bukti pembayaran', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ])
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(fit: StackFit.expand, children: [
                            Image.file(File(_paymentProofPath!), fit: BoxFit.cover),
                            Positioned(
                              right: 6, top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: Colors.white, size: 16),
                              ),
                            ),
                          ]),
                        ),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 14),

          // Voucher
          _section('Voucher', icon: Icons.confirmation_number_outlined,
            _appliedVoucher != null
              ? Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.4))),
                    child: Row(children: [
                      const Icon(Icons.discount, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text(_appliedVoucher!.code, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('(-${toRupiah(_discount)})', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                    onPressed: () => setState(() => _appliedVoucher = null)),
                ])
              : OutlinedButton.icon(
                  onPressed: () => _showVoucherPicker(cart.subtotal),
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('Pakai Voucher'),
                ),
          ),

          const SizedBox(height: 14),

          // Detail Pesanan
          _section('Detail Pesanan', icon: Icons.ramen_dining,
            Column(children: [
              ...cart.items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i.menu.name} x${i.quantity}', overflow: TextOverflow.ellipsis),
                    if (i.menu.spicyLevel > 0)
                      Text('Level pedas: ${i.spicyLevel}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  Text(toRupiah(i.subtotal), style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              )),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Subtotal'), Text(toRupiah(cart.subtotal)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ongkir'),
                  if (_distanceKm > 0)
                    Text('${_distanceKm.toStringAsFixed(1)} km × Rp 2.300',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
                _loadingOngkir
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _ongkirCalculated ? toRupiah(_ongkir) : 'Gagal hitung',
                        style: TextStyle(
                          color: _ongkirCalculated ? AppColors.success : AppColors.error,
                          fontWeight: _ongkirCalculated ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (!_ongkirCalculated) IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                        tooltip: 'Coba hitung ulang',
                        onPressed: _hitungOngkir,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ]),
              ]),
              if (_discount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Diskon Voucher'),
                Text('-${toRupiah(_discount)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)),
              ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(toRupiah(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              ]),
            ]),
          ),

          const SizedBox(height: 14),

          // Catatan
          _section('Catatan', icon: Icons.edit_note,
            TextField(controller: _noteCtrl,
              decoration: const InputDecoration(hintText: 'Catatan tambahan (opsional)...'), maxLines: 2)),

          const SizedBox(height: 24),

          LoadingButton(
            onPressed: _placeOrder, isLoading: _loading,
            label: 'Pesan Sekarang — ${toRupiah(grandTotal)}',
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _showVoucherPicker(double subtotal) async {
    final cart = context.read<CartProvider>();
    final storeId = cart.items.isNotEmpty ? cart.items.first.menu.storeId : '';
    final vouchers = await context.read<VoucherProvider>().loadVouchers(storeId: storeId).then((_) => context.read<VoucherProvider>().vouchers);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6,
        builder: (_, ctrl) => Column(children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const Text('Pilih Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(controller: ctrl, padding: const EdgeInsets.all(16),
              children: vouchers.where((v) => v.isAvailable).map((v) {
                final disc = v.calculateDiscount(subtotal);
                final canUse = subtotal >= v.minOrder;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: canUse ? AppColors.primary.withOpacity(0.1) : AppColors.background, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.discount, color: canUse ? AppColors.primary : AppColors.divider)),
                    title: Text(v.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${v.description}\n${canUse ? "Hemat ${toRupiah(disc)}" : "Min. order ${toRupiah(v.minOrder)}"}'),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: canUse ? () {
                        Navigator.pop(context);
                        setState(() => _appliedVoucher = v);
                      } : null,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      child: const Text('Pakai', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, Widget child, {IconData? icon}) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        icon != null
          ? IconText(icon, title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        child,
      ],
    )),
  );

  String _paymentLabel(PaymentMethod p) => switch (p) {
    PaymentMethod.cash => 'Bayar Tunai (COD)',
    PaymentMethod.transfer => 'Transfer Bank',
    PaymentMethod.ewallet => 'E-Wallet',
    PaymentMethod.qris => 'QRIS',
  };
  String _paymentDesc(PaymentMethod p) => switch (p) {
    PaymentMethod.cash => 'Bayar saat pesanan tiba',
    PaymentMethod.transfer => 'Transfer ke rekening bank toko',
    PaymentMethod.ewallet => 'GoPay / OVO / DANA',
    PaymentMethod.qris => 'Scan QR - semua bank & dompet digital',
  };
  IconData _paymentIcon(PaymentMethod p) => switch (p) {
    PaymentMethod.cash => Icons.money,
    PaymentMethod.transfer => Icons.account_balance,
    PaymentMethod.ewallet => Icons.account_balance_wallet,
    PaymentMethod.qris => Icons.qr_code,
  };

  @override
  void dispose() { _addressCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }
}
