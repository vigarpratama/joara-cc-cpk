// lib/screens/member/qris_payment_screen.dart
// Layar bayar QRIS DINAMIS (MPM): minta QR ke payment-service (nominal + batas waktu tertanam di server),
// tampilkan, lalu pantau sampai lunas / kedaluwarsa.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/api_service.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';

class QrisPaymentScreen extends StatefulWidget {
  final Order order;
  // true kalau layar ini dibuka dari alur "Beli Langsung" (ada 1 layar detail menu lagi di bawahnya)
  final bool popExtra;
  const QrisPaymentScreen({super.key, required this.order, this.popExtra = false});
  @override
  State<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends State<QrisPaymentScreen> {
  Map<String, dynamic>? _payment;
  bool _loading = true;
  bool _paid = false;
  String? _error;
  Duration _left = Duration.zero;
  DateTime? _deadline; // batas waktu = (jam HP saat QR diterima) + secondsLeft dari server
  Timer? _poll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await ApiService.createQris(widget.order.id);
      if (!mounted) return;
      final sec = (p['secondsLeft'] as num?)?.toInt();
      _deadline = sec != null ? DateTime.now().add(Duration(seconds: sec)) : null;
      setState(() { _payment = p; _loading = false; });
      _startTimers();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 = pesanan sudah lunas
      if (e.statusCode == 409) { _onPaid(); return; }
      setState(() { _loading = false; _error = e.message; });
    }
  }

  void _startTimers() {
    _poll?.cancel();
    _tick?.cancel();
    _updateLeft();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateLeft());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
  }

  void _updateLeft() {
    final exp = _deadline ?? DateTime.tryParse(_payment?['expiresAt'] ?? '');
    if (exp == null || !mounted) return;
    final d = exp.difference(DateTime.now());
    setState(() => _left = d.isNegative ? Duration.zero : d);
  }

  bool get _expired => _payment != null && _left == Duration.zero && !_paid;

  DateTime? get _expiresAt => _deadline ?? DateTime.tryParse(_payment?['expiresAt'] ?? '')?.toLocal();
  String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _checkStatus() async {
    if (_paid || _payment == null) return;
    try {
      final p = await ApiService.getPaymentByOrder(widget.order.id);
      if (p != null && p['status'] == 'paid') _onPaid();
      // Server menandai QR kedaluwarsa -> langsung tampilkan layar "kedaluwarsa"
      if (p != null && p['status'] == 'expired' && mounted) setState(() => _left = Duration.zero);
    } catch (_) {}
  }

  Future<void> _onPaid() async {
    _poll?.cancel();
    _tick?.cancel();
    if (!mounted) return;
    setState(() => _paid = true);
    // Segarkan pesanan lokal supaya status "paid" muncul di daftar pesanan
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) await context.read<OrderProvider>().loadMemberOrders(user.id);
  }

  Future<void> _mockPay() async {
    final id = _payment?['paymentId'];
    if (id == null) return;
    try {
      await ApiService.mockPay(id);
      await _onPaid();
    } on ApiException {/* pesan sudah ditampilkan ApiService */}
  }

  void _finish() {
    Navigator.pop(context);
    if (widget.popExtra && Navigator.canPop(context)) Navigator.pop(context);
  }

  String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: const Text('Bayar dengan QRIS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Ringkasan pesanan: order id, waktu, nominal
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _row('No. Pesanan', o.id, bold: true),
            _row('Waktu', formatDate(o.createdAt)),
            _row('Toko', o.storeName.isEmpty ? '-' : o.storeName),
            const Divider(height: 20),
            _row('Total Bayar', toRupiah(o.totalAmount), bold: true, color: AppColors.primary),
          ]))),
          const SizedBox(height: 16),
          if (_loading) const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
          else if (_error != null) _errorBox()
          else if (_paid) _paidBox()
          else if (_expired) _expiredBox()
          else _qrBox(),
          const SizedBox(height: 12),
          if (!_paid) TextButton(onPressed: _finish, child: const Text('Bayar nanti (pesanan tetap tersimpan)')),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(width: 12),
      Flexible(child: Text(value, textAlign: TextAlign.right,
        style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 15 : 13, color: color))),
    ]),
  );

  Widget _qrBox() {
    final p = _payment!;
    final qrString = (p['qrString'] ?? '') as String;
    final qrUrl = (p['qrUrl'] ?? '') as String;
    final isMock = p['provider'] == 'mock';
    final amount = (p['amount'] as num?)?.toDouble() ?? widget.order.totalAmount;
    final exp = _expiresAt;
    return Column(children: [
      const Text('QRIS Dinamis (MPM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: qrString.isNotEmpty
          ? QrImageView(data: qrString, version: QrVersions.auto, size: 240, backgroundColor: Colors.white)
          : (qrUrl.isNotEmpty
              ? Image.network(qrUrl, width: 240, height: 240)
              : const SizedBox(width: 240, height: 240, child: Center(child: Text('QR tidak tersedia')))),
      ),
      const SizedBox(height: 12),
      // Nominal sudah tertanam di dalam QR (pembeli tidak mengetik nominal)
      Text('Nominal ${toRupiah(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('Berlaku ${_mmss(_left)}${exp != null ? '  (sampai ${_hhmm(exp)})' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      const Text('Scan dengan GoPay, OVO, DANA, ShopeePay, atau m-banking apa saja.\nHalaman ini otomatis berubah saat pembayaran diterima.',
        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      if (isMock) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Text('Mode demo: QRIS dinamis ini dibuat sistem (merchant fiktif), tidak ada uang sungguhan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _mockPay, icon: const Icon(Icons.bolt), label: const Text('Simulasi Bayar'))),
          ]),
        ),
      ],
    ]);
  }

  Widget _paidBox() => Column(children: [
    const Icon(Icons.check_circle, color: AppColors.success, size: 80),
    const SizedBox(height: 12),
    const Text('Pembayaran Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('Pesananmu diteruskan ke toko.', style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _finish, child: const Text('Selesai'))),
  ]);

  Widget _expiredBox() => Column(children: [
    const Icon(Icons.timer_off_outlined, color: AppColors.error, size: 64),
    const SizedBox(height: 10),
    const Text('QRIS sudah kedaluwarsa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(height: 14),
    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Buat QRIS Baru')),
  ]);

  Widget _errorBox() => Column(children: [
    const Icon(Icons.error_outline, color: AppColors.error, size: 56),
    const SizedBox(height: 10),
    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
    const SizedBox(height: 14),
    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
  ]);
}
