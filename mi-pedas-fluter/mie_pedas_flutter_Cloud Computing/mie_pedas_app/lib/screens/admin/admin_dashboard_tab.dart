// lib/screens/admin/admin_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../../screens/auth/login_screen.dart';
import '../member/reviews_list_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const AdminDashboardTab({super.key, this.onNavigateTab});
  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // Ditarik keluar dari initState supaya bisa dipanggil ulang lewat
  // tombol refresh & pull-to-refresh — sebelumnya rating/ulasan cuma
  // dimuat SEKALI saat tab pertama kali dibuka, jadi rating baru dari
  // customer tidak pernah muncul sampai tab ini dibangun ulang.
  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<ReviewProvider>().loadReviewsByTarget(auth.currentStoreId);
    if (mounted) await context.read<OrderProvider>().loadStoreOrders(auth.currentStoreId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();
    final menus = context.watch<MenuProvider>();
    final reviews = context.watch<ReviewProvider>();
    final store = auth.currentStore;

    return Scaffold(
      appBar: AppBar(
        title: Text(store?.name ?? 'Dashboard Admin'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Muat ulang', onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await auth.logout();
            if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info toko
          Card(
            color: AppColors.primary,
            child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              const CircleAvatar(backgroundColor: Colors.white, radius: 24, child: Icon(Icons.store, color: AppColors.primary, size: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(store?.name ?? 'Toko', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(store?.address ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ])),
          ),
          const SizedBox(height: 16),

          // Stats
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
            children: [
              _statCard('Total Pesanan', '${orders.orders.length}', Icons.receipt_long, AppColors.primary, onTap: () => widget.onNavigateTab?.call(1)),
              _statCard('Pending', '${orders.pendingOrders.length}', Icons.hourglass_empty, Colors.orange, onTap: () => widget.onNavigateTab?.call(1)),
              _statCard('Pendapatan Hari Ini', toRupiah(orders.todayRevenue), Icons.attach_money, AppColors.success, onTap: () => widget.onNavigateTab?.call(4)),
              _statCard('Total Menu', '${menus.menus.length}', Icons.restaurant_menu, Colors.blue, onTap: () => widget.onNavigateTab?.call(2)),
            ],
          ),

          const SizedBox(height: 16),

          // Rating & Ulasan
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const IconText(Icons.star, 'Rating Toko', iconColor: Colors.amber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsListScreen(
                    targetId: auth.currentStoreId, targetName: store?.name ?? 'Toko', target: ReviewTarget.store,
                  ))),
                  child: const Text('Lihat Semua'),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(reviews.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: List.generate(5, (i) => Icon(i < reviews.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 20))),
                  Text('${reviews.reviews.length} ulasan', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ]),
              if (reviews.reviews.isNotEmpty) ...[
                const Divider(height: 16),
                const Text('Ulasan Terbaru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...reviews.reviews.take(3).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 14))),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.memberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      if (r.comment.isNotEmpty) Text(r.comment, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                )),
              ],
            ])),
          ),

          const SizedBox(height: 16),

          // Pesanan terbaru
          const Text('Pesanan Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...orders.orders.take(5).map((o) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: const Icon(Icons.receipt, color: AppColors.primary)),
              title: Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${o.id} • ${toRupiah(o.totalAmount)}'),
              trailing: OrderStatusChip(status: o.orderStatus),
            ),
          )),
        ]),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ])),
    ),
  );
}
