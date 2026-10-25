// lib/screens/member/orders_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';
import 'review_screen.dart';
import 'track_order_screen.dart';
import 'qris_payment_screen.dart';
import '../../utils/api_config.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Saya')),
      body: orders.isLoading
        ? const Center(child: CircularProgressIndicator())
        : orders.orders.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Belum ada pesanan', subtitle: 'Yuk, pesan mie pedas favoritmu!')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.orders.length,
              itemBuilder: (_, i) {
                final o = orders.orders[i];
                final canReview = o.orderStatus == OrderStatus.delivered || o.orderStatus == OrderStatus.done;
                final needsConfirmation = o.kurirId.isNotEmpty && !o.customerConfirmed;
                final needsQrisPay = ApiConfig.useBackend && o.paymentMethod == PaymentMethod.qris &&
                    o.paymentStatus == PaymentStatus.pending && o.orderStatus != OrderStatus.cancelled;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  shape: needsConfirmation
                    ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.orange, width: 1.5))
                    : null,
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrderScreen(order: o))),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (needsConfirmation) Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.priority_high_rounded, size: 13, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('Butuh konfirmasi kamu', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                          OrderStatusChip(status: o.orderStatus),
                        ]),
                        const SizedBox(height: 8),
                        ...o.items.take(2).map((item) => Text('• ${item.menuName} x${item.quantity}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                        if (o.items.length > 2) Text('+${o.items.length - 2} item lainnya', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (needsQrisPay) Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrisPaymentScreen(order: o))),
                            icon: const Icon(Icons.qr_code_2, size: 18),
                            label: const Text('Bayar dengan QRIS'),
                          )),
                        ),
                        const Divider(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(formatDate(o.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(toRupiah(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
                          ]),
                          if (canReview)
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(order: o))),
                              icon: const Icon(Icons.star_outline, size: 16),
                              label: const Text('Beri Nilai', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            )
                          else
                            const Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Lihat Detail', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
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
