// lib/screens/superadmin/superadmin_main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import 'superadmin_dashboard.dart';
import 'superadmin_stores.dart';
import 'superadmin_orders.dart';
import 'superadmin_settings.dart';
import 'superadmin_reviews_screen.dart';

class SuperAdminMainScreen extends StatefulWidget {
  const SuperAdminMainScreen({super.key});
  @override
  State<SuperAdminMainScreen> createState() => _SuperAdminMainScreenState();
}

class _SuperAdminMainScreenState extends State<SuperAdminMainScreen> {
  int _idx = 0;
  final _screens = const [SuperAdminDashboard(), SuperAdminStores(), SuperAdminOrders(), SuperAdminReviewsScreen(), SuperAdminSettings()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
      context.read<OrderProvider>().loadAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _idx, children: _screens),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _idx,
      onDestinationSelected: (i) => setState(() => _idx = i),
      backgroundColor: const Color(0xFF6A1B9A),
      indicatorColor: Colors.white.withOpacity(0.2),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined, color: Colors.white70), selectedIcon: Icon(Icons.dashboard, color: Colors.white), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.store_outlined, color: Colors.white70), selectedIcon: Icon(Icons.store, color: Colors.white), label: 'UMKM'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined, color: Colors.white70), selectedIcon: Icon(Icons.receipt_long, color: Colors.white), label: 'Pesanan'),
        NavigationDestination(icon: Icon(Icons.star_outline, color: Colors.white70), selectedIcon: Icon(Icons.star, color: Colors.white), label: 'Ulasan'),
        NavigationDestination(icon: Icon(Icons.settings_outlined, color: Colors.white70), selectedIcon: Icon(Icons.settings, color: Colors.white), label: 'Pengaturan'),
      ],
    ),
  );
}
