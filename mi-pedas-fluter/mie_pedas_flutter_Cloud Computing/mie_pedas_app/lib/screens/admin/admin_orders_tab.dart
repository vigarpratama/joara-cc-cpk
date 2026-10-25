// lib/screens/admin/admin_orders_tab.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/notification_helper.dart';
import '../../widgets/widgets.dart';
import 'print_struk_screen.dart';

class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});
  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  Timer? _timer;
  int _lastOrderCount = 0;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSoundSetting();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkNewOrders());
  }

  Future<void> _loadSoundSetting() async {
    _soundEnabled = await NotificationHelper.isSoundEnabled();
    setState(() {});
  }

  Future<void> _checkNewOrders() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrderProvider>();
    // PENTING: reload cuma pesanan TOKO INI, jangan loadAllOrders() —
    // itu narik pesanan dari SEMUA toko dan bikin data toko lain nyasar ke sini.
    await orders.loadStoreOrders(auth.currentStoreId);
    final pendingCount = orders.pendingOrders.length;
    if (pendingCount > _lastOrderCount && _lastOrderCount >= 0) {
      final newCount = pendingCount - _lastOrderCount;
      if (_soundEnabled) await NotificationHelper.playNotificationSound();
      // Notifikasi sistem Android (muncul di status bar)
      await NotificationHelper.showOrderNotification(
        title: '🔔 Pesanan Baru!',
        body: 'Ada $newCount pesanan baru masuk! Segera proses.',
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      if (mounted) {
        NotificationHelper.showInAppNotification(context, 'Pesanan Baru!', 'Ada $newCount pesanan baru masuk!', color: AppColors.primary);
      }
    }
    _lastOrderCount = pendingCount;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Widget _memberAvatar(String photoUrl, String name) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: FileImage(File(photoUrl)),
        onBackgroundImageError: (_, __) {}, // fallback diam-diam kalau file rusak/hilang, tetap tampil lingkaran kosong
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showOrderDetail(BuildContext context, Order o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75, maxChildSize: 0.92,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('Detail Pesanan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              OrderStatusChip(status: o.orderStatus),
            ]),
            Text(o.id, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Divider(height: 28),

            // Info pembeli
            const IconText(Icons.person_outline, 'Pembeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              _memberAvatar(o.memberPhotoUrl, o.memberName),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                IconText(Icons.phone_android, '${o.memberPhone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 10),
            IconText(Icons.location_on, '${o.deliveryAddress}', iconColor: Colors.red, style: const TextStyle(fontSize: 13)),
            if (o.orderNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              IconText(Icons.edit_note, 'Catatan: ${o.orderNote}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            const Divider(height: 28),

            // Item pesanan
            const IconText(Icons.restaurant, 'Item Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...o.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item.menuName} x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (item.spicyLevel > 0) Text('Level pedas: ${item.spicyLevel}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (item.note.isNotEmpty) Text('Catatan: ${item.note}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ])),
                Text(toRupiah(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            )),
            const Divider(height: 24),

            // Rincian pembayaran
            _rowLabel('Subtotal', toRupiah(o.subtotal)),
            _rowLabel('Ongkir', toRupiah(o.deliveryFee)),
            if (o.discount > 0) _rowLabel('Diskon${o.promoCode.isNotEmpty ? " (${o.promoCode})" : ""}', '- ${toRupiah(o.discount)}', valueColor: AppColors.success),
            const Divider(height: 16),
            _rowLabel('Total', toRupiah(o.totalAmount), bold: true),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Metode Bayar', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _paymentStatusColor(o.paymentStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('${_paymentLabel(o.paymentMethod)} • ${o.paymentStatus.name.toUpperCase()}',
                  style: TextStyle(color: _paymentStatusColor(o.paymentStatus), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            if (o.kurirName.isNotEmpty) _rowLabel('Kurir', o.kurirName),
            _rowLabel('Waktu Pesan', formatDate(o.createdAt)),

            // Bukti pembayaran dari customer (buat metode non-tunai) + tombol konfirmasi lunas
            if (o.paymentMethod != PaymentMethod.cash) ...[
              const SizedBox(height: 16),
              const IconText(Icons.receipt_long, 'Bukti Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (o.paymentProofUrl.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text('Customer belum upload bukti pembayaran', style: TextStyle(fontSize: 12, color: Colors.orange))),
                  ]),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: GestureDetector(
                    onTap: () => showDialog(context: context, builder: (_) => Dialog(
                      child: InteractiveViewer(child: Image.file(File(o.paymentProofUrl))),
                    )),
                    child: Image.file(File(o.paymentProofUrl), height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 180, color: AppColors.background,
                        child: const Center(child: Text('Gagal memuat foto', style: TextStyle(color: AppColors.textSecondary)))),
                    ),
                  ),
                ),
              if (o.paymentStatus != PaymentStatus.paid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await context.read<OrderProvider>().updatePaymentStatus(o.id, PaymentStatus.paid);
                      setModalState(() {}); // o dimutasi langsung oleh provider, tinggal re-render sheet ini
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Pembayaran ditandai Lunas, pesanan siap diproses'), backgroundColor: AppColors.success));
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tandai Lunas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.divider,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
          ]),
        ),
        ),
      ),
    );
  }

  Color _paymentStatusColor(PaymentStatus status) => switch (status) {
    PaymentStatus.paid => AppColors.success,
    PaymentStatus.pending => Colors.orange,
    PaymentStatus.failed => AppColors.error,
    PaymentStatus.refunded => AppColors.textSecondary,
  };

  String _paymentLabel(PaymentMethod m) => switch (m) {
    PaymentMethod.cash => 'Cash (COD)',
    PaymentMethod.transfer => 'Transfer Bank',
    PaymentMethod.ewallet => 'E-Wallet',
    PaymentMethod.qris => 'QRIS',
  };

  Widget _rowLabel(String label, String value, {Color? valueColor, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: bold ? 15 : 13)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 16 : 13, color: valueColor ?? (bold ? AppColors.primary : null))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pesanan'),
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              await NotificationHelper.setSoundEnabled(!_soundEnabled);
              setState(() => _soundEnabled = !_soundEnabled);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: IconText(_soundEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, _soundEnabled ? 'Notifikasi suara aktif' : 'Dimatikan'),
                duration: const Duration(seconds: 2),
              ));
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => context.read<OrderProvider>().loadStoreOrders(context.read<AuthProvider>().currentStoreId)),
        ],
      ),
      body: orders.isLoading
        ? const Center(child: CircularProgressIndicator())
        : orders.orders.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Belum ada pesanan')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.orders.length,
              itemBuilder: (_, i) {
                final o = orders.orders[i];
                final isNew = o.orderStatus == OrderStatus.pending;
                final needsPaymentCheck = o.paymentMethod != PaymentMethod.cash && o.paymentStatus != PaymentStatus.paid;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isNew ? const BorderSide(color: AppColors.primary, width: 2) : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => _showOrderDetail(context, o),
                    child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Wrap (bukan Row) supaya label + chip status turun ke baris bawah kalau tidak muat
                      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isNew) Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                            child: const Text('BARU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary)),
                          if (needsPaymentCheck) Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: const Text('CEK BUKTI BAYAR', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        OrderStatusChip(status: o.orderStatus),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        _memberAvatar(o.memberPhotoUrl, o.memberName),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          IconText(Icons.phone_android, '${o.memberPhone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                      ]),
                      IconText(Icons.location_on, '${o.deliveryAddress}', iconColor: Colors.red, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      ...o.items.map((item) => Text('• ${item.menuName} x${item.quantity}', style: const TextStyle(fontSize: 12))),
                      const Divider(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(toRupiah(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Row(children: [
                          // Tombol Cetak Struk
                          IconButton(
                            icon: const Icon(Icons.print_outlined, color: AppColors.primary),
                            tooltip: 'Cetak Struk',
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrintStrukScreen(order: o))),
                          ),
                          DropdownButton<OrderStatus>(
                            value: o.orderStatus,
                            isDense: true,
                            items: OrderStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(orderStatusLabel(s), style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (s) { if (s != null) orders.updateStatus(o.id, s); },
                          ),
                        ]),
                      ]),
                    ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
