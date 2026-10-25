// lib/screens/kurir/kurir_stats_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../member/reviews_list_screen.dart';
import '../../widgets/widgets.dart';

class KurirStatsScreen extends StatelessWidget {
  const KurirStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final auth = context.watch<AuthProvider>();
    final myId = auth.currentUser?.id ?? '';

    // Filter pesanan milik kurir ini yang sudah selesai
    final myOrders = orders.orders.where((o) =>
      o.kurirId == myId &&
      (o.orderStatus == OrderStatus.delivered || o.orderStatus == OrderStatus.done)
    ).toList();

    final now = DateTime.now();

    // ===== HARIAN: 7 hari terakhir =====
    Map<String, int> dailyCount = {};
    Map<String, double> dailyEarnings = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.day}/${day.month}';
      final dayOrders = myOrders.where((o) {
        final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
        return d.day == day.day && d.month == day.month && d.year == day.year;
      }).toList();
      dailyCount[key] = dayOrders.length;
      dailyEarnings[key] = dayOrders.length * 5000; // estimasi ongkir per antar
    }

    // ===== STATISTIK UMUM =====
    final today = myOrders.where((o) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
      return d.day == now.day && d.month == now.month && d.year == now.year;
    }).length;

    final thisMonth = myOrders.where((o) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
      return d.month == now.month && d.year == now.year;
    }).length;

    final totalAll = myOrders.length;
    final estimasiPenghasilan = totalAll * 5000.0;

    // List order (bukan cuma jumlah) untuk ditampilkan saat card ditekan
    final todayOrders = myOrders.where((o) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
      return d.day == now.day && d.month == now.month && d.year == now.year;
    }).toList();

    final thisMonthOrders = myOrders.where((o) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
      return d.month == now.month && d.year == now.year;
    }).toList();

    final maxCount = dailyCount.values.isEmpty ? 1 : dailyCount.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Pengantaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header kurir
          Card(
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                (auth.currentUser?.photoUrl ?? '').isNotEmpty
                  ? CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 28,
                      backgroundImage: FileImage(File(auth.currentUser!.photoUrl)),
                      onBackgroundImageError: (_, __) {},
                    )
                  : CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 28,
                      child: Text(
                        auth.currentUser?.name.isNotEmpty == true ? auth.currentUser!.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.currentUser?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const IconText(Icons.two_wheeler, 'Kurir Aktif', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Summary cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _statCard('Hari Ini', '$today antar', Icons.today, Colors.blue,
                onTap: () => _showOrderListSheet(context, 'Pengantaran Hari Ini', todayOrders)),
              _statCard('Bulan Ini', '$thisMonth antar', Icons.calendar_month, Colors.green,
                onTap: () => _showOrderListSheet(context, 'Pengantaran Bulan Ini', thisMonthOrders)),
              _statCard('Total Semua', '$totalAll antar', Icons.delivery_dining, AppColors.primary,
                onTap: () => _showOrderListSheet(context, 'Semua Pengantaran', myOrders)),
              _statCard('Est. Penghasilan', toRupiah(estimasiPenghasilan), Icons.attach_money, Colors.orange,
                onTap: () => _showEarningsSheet(context, totalAll, estimasiPenghasilan)),
            ],
          ),

          const SizedBox(height: 20),

          // Grafik harian
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconText(Icons.bar_chart, 'Grafik 7 Hari Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('Jumlah pengantaran per hari', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                totalAll == 0
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(children: [
                        Icon(Icons.delivery_dining, size: 48, color: AppColors.divider),
                        SizedBox(height: 8),
                        Text('Belum ada pengantaran selesai', style: TextStyle(color: AppColors.textSecondary)),
                      ]),
                    ))
                  : SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: dailyCount.entries.map((e) {
                          final barH = maxCount > 0 ? (e.value / maxCount) * 140 : 0.0;
                          final isMax = e.value == maxCount && maxCount > 0;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                if (e.value > 0) Text('${e.value}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMax ? AppColors.primary : AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  height: barH.toDouble(),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isMax
                                        ? [AppColors.primaryDark, AppColors.primaryLight]
                                        : [Colors.blue.shade300, Colors.blue.shade500],
                                    ),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(e.key, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Detail harian
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconText(Icons.assignment_outlined, 'Detail Per Hari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                ...dailyCount.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: e.value > 0 ? AppColors.primary : AppColors.divider,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                    Text('${e.value} antar', style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: e.value > 0 ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 13,
                    )),
                    const SizedBox(width: 12),
                    Text(e.value > 0 ? toRupiah(e.value * 5000) : '-', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ]),
                )),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total 7 Hari', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${dailyCount.values.fold(0, (a, b) => a + b)} antar', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Riwayat pesanan terakhir
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconText(Icons.schedule, 'Riwayat Pengantaran Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                myOrders.isEmpty
                  ? const Text('Belum ada riwayat', style: TextStyle(color: AppColors.textSecondary))
                  : Column(
                      children: myOrders.take(10).map((o) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(formatDate(o.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ])),
                          Text(toRupiah(o.totalAmount), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 12)),
                        ]),
                      )).toList(),
                    ),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Rating dari customer
          KurirReviewSection(kurirId: myId),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  // Bottom sheet: daftar pengantaran sesuai periode yang ditekan
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
                ? const Center(child: Text('Belum ada pengantaran', style: TextStyle(color: AppColors.textSecondary)))
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
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(formatDate(o.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ])),
                          Text(toRupiah(o.totalAmount), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
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

  // Bottom sheet: rincian perhitungan estimasi penghasilan
  void _showEarningsSheet(BuildContext context, int totalAll, double estimasiPenghasilan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const IconText(Icons.payments_outlined, 'Rincian Estimasi Penghasilan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total pengantaran selesai', style: TextStyle(color: AppColors.textSecondary)),
            Text('$totalAll antar', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Ongkir per antar', style: TextStyle(color: AppColors.textSecondary)),
            const Text('Rp 5.000', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Estimasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(toRupiah(estimasiPenghasilan), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
          ]),
          const SizedBox(height: 12),
          const Text('*Ini estimasi berdasarkan jumlah pengantaran x ongkir tetap, bukan penghasilan final/tercatat.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

class KurirReviewSection extends StatefulWidget {
  final String kurirId;
  const KurirReviewSection({super.key, required this.kurirId});
  @override
  State<KurirReviewSection> createState() => _KurirReviewSectionState();
}

class _KurirReviewSectionState extends State<KurirReviewSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ReviewProvider>().loadReviewsByTarget(widget.kurirId));
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReviewProvider>();
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const IconText(Icons.star, 'Rating Saya', iconColor: Colors.amber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              ReviewsListScreen(targetId: widget.kurirId, targetName: 'Kurir', target: ReviewTarget.kurir))),
            child: const Text('Lihat Semua'),
          ),
        ]),
        Row(children: [
          Text(rp.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: List.generate(5, (i) => Icon(i < rp.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 20))),
            Text('${rp.reviews.length} ulasan', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ]),
        if (rp.reviews.isNotEmpty) ...[
          const Divider(height: 12),
          ...rp.reviews.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 12))),
              const SizedBox(width: 6),
              Expanded(child: Text(r.comment.isEmpty ? 'Tanpa komentar' : r.comment, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          )),
        ],
      ])),
    );
  }
}
