// lib/screens/superadmin/superadmin_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import 'store_commission_report_screen.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<StoreProvider>();
    final orders = context.watch<OrderProvider>();

    final totalRevenue = orders.orders.fold(0.0, (s, o) => s + o.totalAmount);
    final todayOrders = orders.orders.where((o) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
      final now = DateTime.now();
      return d.day == now.day && d.month == now.month && d.year == now.year;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF6A1B9A),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text('Joara Superadmin', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 8),
                      Text('Platform UMKM Kuliner Terpadu', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () { context.read<StoreProvider>().loadStores(); context.read<OrderProvider>().loadAllOrders(); }),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Stats
                GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
                  children: [
                    _statCard('Total UMKM', '${stores.stores.length}', Icons.store, Colors.blue,
                      onTap: () => _showStoreListSheet(context, 'Semua UMKM', stores.stores)),
                    _statCard('UMKM Aktif', '${stores.activeStores.length}', Icons.check_circle, Colors.green,
                      onTap: () => _showStoreListSheet(context, 'UMKM Aktif', stores.activeStores)),
                    _statCard('Menunggu Approval', '${stores.pendingStores.length}', Icons.pending, Colors.orange,
                      onTap: () => _showStoreListSheet(context, 'Menunggu Approval', stores.pendingStores)),
                    _statCard('Total Pesanan', '${orders.orders.length}', Icons.receipt_long, Colors.purple,
                      onTap: () => _showOrderListSheet(context, 'Semua Pesanan', orders.orders)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _bigCard('Total Revenue', toRupiah(totalRevenue), Icons.monetization_on, const Color(0xFF6A1B9A),
                    onTap: () => _showOrderListSheet(context, 'Semua Pesanan (Revenue)', orders.orders))),
                  const SizedBox(width: 12),
                  Expanded(child: _bigCard('Pesanan Hari Ini', '${todayOrders.length}', Icons.today, Colors.teal,
                    onTap: () => _showOrderListSheet(context, 'Pesanan Hari Ini', todayOrders))),
                ]),

                const SizedBox(height: 20),

                // UMKM yang perlu approval
                if (stores.pendingStores.isNotEmpty) ...[
                  Row(children: [
                    const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text('Menunggu Approval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: Text('${stores.pendingStores.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ...stores.pendingStores.map((s) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.store, color: Colors.white)),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(s.ownerName),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(onPressed: () => context.read<StoreProvider>().activateStore(s.id), child: const Text('Approve', style: TextStyle(color: Colors.green))),
                        TextButton(onPressed: () => context.read<StoreProvider>().suspendStore(s.id), child: const Text('Tolak', style: TextStyle(color: AppColors.error))),
                      ]),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],

                // Daftar UMKM aktif
                const Text('UMKM Terdaftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...stores.stores.map((s) {
                  final storeOrders = orders.orders.where((o) => o.storeId == s.id).toList();
                  final storeRevenue = storeOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
                  final statusColor = switch (s.status) { StoreStatus.active => Colors.green, StoreStatus.suspended => AppColors.error, StoreStatus.pending => Colors.orange };
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          s.storefrontPhotoUrl.isNotEmpty
                            ? CircleAvatar(
                                backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                                backgroundImage: FileImage(File(s.storefrontPhotoUrl)),
                                onBackgroundImageError: (_, __) {},
                              )
                            : CircleAvatar(backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1), child: Text(s.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(s.ownerName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))),
                            child: Text(s.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          _miniStat('${storeOrders.length} pesanan', Icons.receipt),
                          const SizedBox(width: 16),
                          _miniStat(toRupiah(storeRevenue), Icons.attach_money),
                          const SizedBox(width: 16),
                          _miniStat(formatDate(s.createdAt).split(',').first, Icons.calendar_today),
                        ]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreCommissionReportScreen(store: s))),
                            icon: const Icon(Icons.receipt_long, size: 14, color: Color(0xFF6A1B9A)),
                            label: const Text('Lihat Laporan', style: TextStyle(color: Color(0xFF6A1B9A), fontSize: 12)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6A1B9A)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                          ),
                          const SizedBox(width: 8),
                          if (s.status == StoreStatus.active)
                            OutlinedButton.icon(
                              onPressed: () => _confirmSuspend(context, s),
                              icon: const Icon(Icons.block, size: 14, color: AppColors.error),
                              label: const Text('Suspend', style: TextStyle(color: AppColors.error, fontSize: 12)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            )
                          else if (s.status == StoreStatus.suspended) ...[
                            OutlinedButton.icon(
                              onPressed: () => context.read<StoreProvider>().activateStore(s.id),
                              icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                              label: const Text('Aktifkan', style: TextStyle(color: Colors.green, fontSize: 12)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _confirmDeleteStore(context, s),
                              icon: const Icon(Icons.delete_forever, size: 14, color: AppColors.error),
                              label: const Text('Hapus', style: TextStyle(color: AppColors.error, fontSize: 12)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSuspend(BuildContext context, Store s) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Suspend UMKM'),
      content: Text('Yakin ingin suspend "${s.name}"? Toko tidak bisa login.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () { context.read<StoreProvider>().suspendStore(s.id); Navigator.pop(context); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Suspend'),
        ),
      ],
    ));
  }

  void _confirmDeleteStore(BuildContext context, Store s) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error),
        SizedBox(width: 8),
        Text('Hapus Permanen'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Yakin ingin menghapus "${s.name}" secara PERMANEN?'),
        const SizedBox(height: 10),
        const Text('Tindakan ini tidak bisa dibatalkan. Semua menu, voucher, dan akun admin milik resto ini akan ikut terhapus.\n\nRiwayat pesanan tetap disimpan untuk keperluan laporan.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () async {
            await context.read<StoreProvider>().deleteStore(s.id);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${s.name}" berhasil dihapus'), backgroundColor: AppColors.success));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Hapus Permanen'),
        ),
      ],
    ));
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ])),
    ),
  );

  Widget _bigCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => Card(
    color: color,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ])),
    ),
  );

  Widget _miniStat(String label, IconData icon) => Row(children: [
    Icon(icon, size: 12, color: AppColors.textSecondary),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ]);

  // Bottom sheet: daftar UMKM sesuai kategori yang ditekan
  void _showStoreListSheet(BuildContext context, String title, List<Store> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${list.length} UMKM', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: list.isEmpty
                ? const Center(child: Text('Tidak ada data', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      final statusColor = switch (s.status) { StoreStatus.active => Colors.green, StoreStatus.suspended => AppColors.error, StoreStatus.pending => Colors.orange };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          s.storefrontPhotoUrl.isNotEmpty
                            ? CircleAvatar(
                                backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                                backgroundImage: FileImage(File(s.storefrontPhotoUrl)),
                                onBackgroundImageError: (_, __) {},
                              )
                            : CircleAvatar(backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1), child: Text(s.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(s.ownerName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))),
                            child: Text(s.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      );
                    },
                  ),
            ),
          ]),
        ),
      ),
    );
  }

  // Bottom sheet: daftar pesanan sesuai kategori yang ditekan
  void _showOrderListSheet(BuildContext context, String title, List<Order> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${list.length} pesanan', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: list.isEmpty
                ? const Center(child: Text('Tidak ada pesanan', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final o = list[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.receipt_long, color: Color(0xFF6A1B9A), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(formatDate(o.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ])),
                          Text(toRupiah(o.totalAmount), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600, fontSize: 12)),
                        ]),
                      );
                    },
                  ),
            ),
          ]),
        ),
      ),
    );
  }
}
