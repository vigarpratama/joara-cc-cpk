// lib/screens/member/member_main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import 'home_tab.dart';
import 'menu_tab.dart';
import 'orders_tab.dart';
import 'profile_tab.dart';

class MemberMainScreen extends StatefulWidget {
  const MemberMainScreen({super.key});
  @override
  State<MemberMainScreen> createState() => _MemberMainScreenState();
}

class _MemberMainScreenState extends State<MemberMainScreen> {
  int _currentIndex = 0;
  String? _menuQuery;

  void _goToMenu({String? query}) {
    setState(() {
      _currentIndex = 1;
      _menuQuery = query;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenus();
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) context.read<OrderProvider>().loadMemberOrders(user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Badge di tab "Pesanan" pakai jumlah pesanan yang masih aktif (belum
    // selesai/dibatalkan) — BUKAN jumlah item di keranjang. Jadi setelah
    // checkout, badge langsung terhitung 1 pesanan, bukan ikut isi keranjang.
    final activeOrderCount = context.watch<OrderProvider>().orders
        .where((o) => o.orderStatus != OrderStatus.done && o.orderStatus != OrderStatus.cancelled)
        .length;
    final screens = [
      HomeTab(onNavigateToMenu: ({String? query}) => _goToMenu(query: query)),
      MenuTab(initialQuery: _menuQuery),
      const OrdersTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          const NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(
            icon: Badge(label: Text('$activeOrderCount'), isLabelVisible: activeOrderCount > 0, child: const Icon(Icons.receipt_long_outlined)),
            selectedIcon: Badge(label: Text('$activeOrderCount'), isLabelVisible: activeOrderCount > 0, child: const Icon(Icons.receipt_long)),
            label: 'Pesanan',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
