// lib/screens/admin/admin_stats_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class AdminStatsTab extends StatefulWidget {
  const AdminStatsTab({super.key});
  @override
  State<AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<AdminStatsTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  // ===== HELPERS =====
  List<Order> _doneOrders(List<Order> all) => all.where((o) =>
    o.orderStatus == OrderStatus.done || o.orderStatus == OrderStatus.delivered).toList();

  // Harian: 7 hari terakhir
  Map<String, double> _dailyStats(List<Order> orders) {
    final now = DateTime.now();
    final Map<String, double> result = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.day}/${day.month}';
      result[key] = orders.where((o) {
        final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
        return d.day == day.day && d.month == day.month && d.year == day.year;
      }).fold(0.0, (s, o) => s + o.totalAmount);
    }
    return result;
  }

  // Bulanan: 12 bulan terakhir
  Map<String, double> _monthlyStats(List<Order> orders) {
    final now = DateTime.now();
    final List<String> monthNames = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final Map<String, double> result = {};
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${monthNames[month.month - 1]} ${month.year}';
      result[key] = orders.where((o) {
        final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
        return d.month == month.month && d.year == month.year;
      }).fold(0.0, (s, o) => s + o.totalAmount);
    }
    return result;
  }

  // Tahunan: 5 tahun terakhir
  Map<String, double> _yearlyStats(List<Order> orders) {
    final now = DateTime.now();
    final Map<String, double> result = {};
    for (int i = 4; i >= 0; i--) {
      final year = now.year - i;
      final key = '$year';
      result[key] = orders.where((o) {
        final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
        return d.year == year;
      }).fold(0.0, (s, o) => s + o.totalAmount);
    }
    return result;
  }

  // Menu terlaris
  Map<String, int> _topMenus(List<Order> orders) {
    final Map<String, int> result = {};
    for (final o in orders) {
      for (final item in o.items) {
        result[item.menuName] = (result[item.menuName] ?? 0) + item.quantity;
      }
    }
    final sorted = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final done = _doneOrders(orders.orders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Penjualan'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Harian'),
            Tab(text: 'Bulanan'),
            Tab(text: 'Tahunan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildStatsView(_dailyStats(done), done, 'Harian', '7 hari terakhir'),
          _buildStatsView(_monthlyStats(done), done, 'Bulanan', '12 bulan terakhir'),
          _buildStatsView(_yearlyStats(done), done, 'Tahunan', '5 tahun terakhir'),
        ],
      ),
    );
  }

  Widget _buildStatsView(Map<String, double> data, List<Order> allDone, String period, String subtitle) {
    final total = data.values.fold(0.0, (s, v) => s + v);
    final maxVal = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);
    final topMenus = _topMenus(allDone);
    final totalOrders = allDone.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(children: [
            Expanded(child: _summaryCard('Total Pendapatan', toRupiah(total), Icons.attach_money, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _summaryCard('Total Pesanan', '$totalOrders', Icons.receipt_long, Colors.blue)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _summaryCard('Rata-rata/Pesanan', totalOrders > 0 ? toRupiah(total / totalOrders) : 'Rp 0', Icons.analytics, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _summaryCard('Periode', subtitle, Icons.calendar_today, Colors.green)),
          ]),

          const SizedBox(height: 20),

          // Bar Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grafik Penjualan $period', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  data.isEmpty || total == 0
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(children: [
                          Icon(Icons.bar_chart, size: 48, color: AppColors.divider),
                          SizedBox(height: 8),
                          Text('Belum ada data penjualan', style: TextStyle(color: AppColors.textSecondary)),
                        ]),
                      ))
                    : SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: data.entries.map((e) {
                            final barHeight = maxVal > 0 ? (e.value / maxVal) * 160 : 0.0;
                            final isHighest = e.value == maxVal && maxVal > 0;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (e.value > 0)
                                      Text(
                                        _shortRupiah(e.value),
                                        style: TextStyle(fontSize: 8, color: isHighest ? AppColors.primary : AppColors.textSecondary, fontWeight: isHighest ? FontWeight.bold : FontWeight.normal),
                                        textAlign: TextAlign.center,
                                      ),
                                    const SizedBox(height: 2),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 600),
                                      height: barHeight.toDouble(),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: isHighest
                                            ? [AppColors.primaryDark, AppColors.primaryLight]
                                            : [AppColors.primary.withOpacity(0.5), AppColors.primary.withOpacity(0.8)],
                                        ),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(e.key.split(' ').first, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Detail tabel
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail $period', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  ...data.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: e.value > 0 ? AppColors.primary : AppColors.divider,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                        Text(
                          e.value > 0 ? toRupiah(e.value) : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: e.value > 0 ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(toRupiah(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Top menu
          if (topMenus.isNotEmpty) Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconText(Icons.emoji_events, 'Menu Terlaris', iconColor: Colors.amber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  ...topMenus.entries.toList().asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final name = entry.value.key;
                    final qty = entry.value.value;
                    final colors = [Colors.amber, Colors.grey, Colors.brown, AppColors.primary, Colors.teal];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: colors[rank - 1].withOpacity(0.15), shape: BoxShape.circle),
                            child: Center(child: Text('$rank', style: TextStyle(fontWeight: FontWeight.bold, color: colors[rank - 1], fontSize: 13))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text('$qty porsi', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    ),
  );

  String _shortRupiah(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}jt';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}rb';
    return val.toStringAsFixed(0);
  }
}
