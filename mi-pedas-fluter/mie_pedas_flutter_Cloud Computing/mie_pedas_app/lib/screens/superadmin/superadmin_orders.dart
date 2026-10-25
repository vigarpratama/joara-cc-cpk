// lib/screens/superadmin/superadmin_orders.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class SuperAdminOrders extends StatelessWidget {
  const SuperAdminOrders({super.key});

  Widget _memberAvatar(String photoUrl, String name) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
        backgroundImage: FileImage(File(photoUrl)),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final stores = context.watch<StoreProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semua Pesanan'),
        backgroundColor: const Color(0xFF6A1B9A),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => context.read<OrderProvider>().loadAllOrders())],
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
                final store = stores.stores.where((s) => s.id == o.storeId).firstOrNull;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showOrderDetail(context, o, store),
                    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                      OrderStatusChip(status: o.orderStatus),
                    ]),
                    const SizedBox(height: 4),
                    if (store != null) Row(children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                        backgroundImage: o.storePhotoUrl.isNotEmpty ? FileImage(File(o.storePhotoUrl)) : null,
                        child: o.storePhotoUrl.isEmpty ? const Icon(Icons.storefront, size: 10, color: Color(0xFF6A1B9A)) : null,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: IconText(Icons.storefront, '${store.name}', style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      _memberAvatar(o.memberPhotoUrl, o.memberName),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ]),
                    if (o.kurirId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        _memberAvatar(o.kurirPhotoUrl, o.kurirName),
                        const SizedBox(width: 8),
                        Expanded(child: IconText(Icons.two_wheeler, '${o.kurirName}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    IconText(Icons.location_on, '${o.deliveryAddress}', iconColor: Colors.red, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(formatDate(o.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(toRupiah(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ]),
                  ])),
                  ),
                );
              },
            ),
    );
  }

  void _showOrderDetail(BuildContext context, Order o, Store? store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              OrderStatusChip(status: o.orderStatus),
            ]),
            const SizedBox(height: 4),
            Text(formatDate(o.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Divider(height: 24),

            if (store != null) ...[
              const IconText(Icons.storefront, 'Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
            ],

            const IconText(Icons.person_outline, 'Pembeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (o.memberPhone.isNotEmpty) Text(o.memberPhone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),

            if (o.kurirId.isNotEmpty) ...[
              const IconText(Icons.two_wheeler, 'Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text(o.kurirName, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (o.kurirPhone.isNotEmpty) Text(o.kurirPhone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
            ],

            const IconText(Icons.location_on, 'Alamat Pengiriman', iconColor: Colors.red, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(o.deliveryAddress, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),

            const IconText(Icons.ramen_dining, 'Item Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...o.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text('${item.menuName} x${item.quantity}', style: const TextStyle(fontSize: 13))),
                Text(toRupiah(item.price * item.quantity), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            )),
            if (o.orderNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Catatan: ${o.orderNote}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ],
            const Divider(height: 24),

            _priceRow('Subtotal', o.subtotal),
            _priceRow('Ongkir', o.deliveryFee),
            if (o.discount > 0) _priceRow('Diskon', -o.discount, color: AppColors.success),
            const Divider(height: 16),
            _priceRow('Total', o.totalAmount, bold: true),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.payment, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(_paymentLabel(o.paymentMethod), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _paymentStatusColor(o.paymentStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(o.paymentStatus.name.toUpperCase(), style: TextStyle(color: _paymentStatusColor(o.paymentStatus), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            if (o.paymentProofUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              const IconText(Icons.receipt_long, 'Bukti Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => Dialog(
                    child: InteractiveViewer(child: Image.file(File(o.paymentProofUrl))),
                  )),
                  child: Image.file(File(o.paymentProofUrl), height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 160, color: AppColors.background,
                      child: const Center(child: Text('Gagal memuat foto', style: TextStyle(color: AppColors.textSecondary)))),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ]),
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

  Widget _priceRow(String label, double value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(toRupiah(value), style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
    ]),
  );

  String _paymentLabel(PaymentMethod p) => switch (p) {
    PaymentMethod.cash => 'Bayar Tunai (COD)',
    PaymentMethod.transfer => 'Transfer Bank',
    PaymentMethod.ewallet => 'E-Wallet',
    PaymentMethod.qris => 'QRIS',
  };
}
