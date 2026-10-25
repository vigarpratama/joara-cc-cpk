// lib/screens/admin/admin_main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import 'admin_dashboard_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_menu_tab.dart';
import 'admin_users_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_voucher_tab.dart';
import 'admin_settings_tab.dart';
import '../../widgets/widgets.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _idx = 0;

  // Cache tab yang sudah pernah dibuka, supaya tiap tab hanya dibangun SEKALI
  // (lazy build) alih-alih ke-7 tab dibangun sekaligus di awal lewat IndexedStack.
  final Map<int, Widget> _builtTabs = {};

  void _goToTab(int index) => setState(() => _idx = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final storeId = auth.currentStoreId;
      context.read<OrderProvider>().loadStoreOrders(storeId);
      context.read<MenuProvider>().loadMenus(storeId: storeId);
      context.read<VoucherProvider>().loadVouchers(storeId: storeId);
    });
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0: return AdminDashboardTab(onNavigateTab: _goToTab);
      case 1: return const AdminOrdersTab();
      case 2: return const AdminMenuTab();
      case 3: return const AdminVoucherTab();
      case 4: return const AdminStatsTab();
      case 5: return const AdminUsersTab();
      case 6: return const AdminSettingsTab();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = context.watch<AuthProvider>().currentStore?.name ?? 'Admin Panel';

    // Hanya bangun tab yang aktif sekarang kalau belum pernah dibangun.
    // Tab lain yang sudah pernah dibuka tetap disimpan di cache (state-nya
    // tidak hilang saat pindah tab, sama seperti IndexedStack biasa), tapi
    // tab yang BELUM PERNAH dibuka tidak ikut dibangun di awal.
    _builtTabs.putIfAbsent(_idx, () => _buildTab(_idx));

    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: List.generate(7, (i) => _builtTabs[i] ?? const SizedBox.shrink()),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        // Banner nama toko
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4),
          color: AppColors.primary,
          child: IconText(Icons.storefront, '$storeName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _navItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                  _navItem(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Pesanan'),
                  _navItem(2, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'),
                  _navItem(3, Icons.discount_outlined, Icons.discount, 'Voucher'),
                  _navItem(4, Icons.bar_chart_outlined, Icons.bar_chart, 'Statistik'),
                  _navItem(5, Icons.people_outline, Icons.people, 'Pengguna'),
                  _navItem(6, Icons.settings_outlined, Icons.settings, 'Pengaturan'),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _navItem(int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _idx == index;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: () => setState(() => _idx = index),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
