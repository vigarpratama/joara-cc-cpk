// lib/screens/member/home_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/maps_service.dart';
import '../../widgets/widgets.dart';
import 'cart_screen.dart';
import 'detail_menu_screen.dart';
import 'track_order_screen.dart';
import 'location_picker_screen.dart';

class HomeTab extends StatelessWidget {
  final void Function({String? query})? onNavigateToMenu;
  const HomeTab({super.key, this.onNavigateToMenu});

  // Navigasi langsung pakai koordinat presisi (kalau rumah sudah di-pin di peta).
  // Buka 1 aplikasi (Google Maps) langsung ke titik itu, tanpa geocoding ulang alamat teks.
  Future<void> _navigateToCoord(BuildContext context, double lat, double lng) async {
    final gmapsApp = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final gmapsBrowser = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    try {
      if (await canLaunchUrl(gmapsApp)) {
        await launchUrl(gmapsApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(gmapsBrowser, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal buka Maps: $e')));
    }
  }

  // Navigasi ke rumah: pakai koordinat presisi kalau sudah di-pin, kalau belum fallback ke alamat teks.
  Future<void> _navigateHome(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && user.hasHomeLocation) {
      await _navigateToCoord(context, user.homeLat!, user.homeLng!);
      return;
    }
    final address = user?.address ?? '';
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi alamat di Profil dulu ya!'), backgroundColor: Colors.orange),
      );
      return;
    }
    await _openMaps(context, address);
  }

  // Pin/ubah lokasi rumah lewat peta, supaya navigasi selanjutnya pakai koordinat presisi.
  Future<void> _pinLokasiRumah(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    final current = (user != null && user.hasHomeLocation) ? LatLng(user.homeLat!, user.homeLng!) : null;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: current)),
    );
    if (result == null || !context.mounted) return;
    final ok = await context.read<AuthProvider>().updateHomeLocation(result.lat, result.lng);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: IconText(ok ? Icons.check_circle : Icons.error_outline, ok ? 'Lokasi rumah berhasil disimpan' : 'Gagal menyimpan lokasi'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi alamat di Profil dulu ya!'), backgroundColor: Colors.orange),
      );
      return;
    }
    final encoded = Uri.encodeComponent(address);

    // Coba Google Maps app dulu, fallback ke browser
    final gmapsApp = Uri.parse('google.navigation:q=$encoded&mode=d');
    final gmapsBrowser = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving');

    try {
      if (await canLaunchUrl(gmapsApp)) {
        await launchUrl(gmapsApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(gmapsBrowser, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal buka Maps: $e')));
    }
  }

  Future<void> _openCustomAddress(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Navigasi ke Alamat'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Masukkan alamat tujuan...', prefixIcon: Icon(Icons.search))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Navigasi')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      await _openMaps(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final menus = context.watch<MenuProvider>();
    final cart = context.watch<CartProvider>();
    final orders = context.watch<OrderProvider>();
    final vp = context.watch<VoucherProvider>();

    // Load voucher kalau belum
    if (vp.vouchers.isEmpty && !vp.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => vp.loadVouchers());
    }
    final name = auth.currentUser?.name.split(' ').first ?? 'Pelanggan';
    final address = auth.currentUser?.address ?? '';

    // Pesanan aktif terbaru
    final activeOrder = orders.orders.where((o) =>
      [OrderStatus.pending, OrderStatus.processing, OrderStatus.ready, OrderStatus.delivering].contains(o.orderStatus)
    ).firstOrNull;

    final banners = [
      ('Promo Spesial!', 'Diskon 20% untuk semua menu Extra Pedas', AppColors.primaryDark, Icons.local_fire_department, 'pedas'),
      ('Menu Baru!', 'Coba Mie Pedas Seafood Special kami!', AppColors.primary, Icons.new_releases, 'seafood'),
      ('Gratis Ongkir!', 'Belanja min. Rp 50.000 gratis ongkir', AppColors.accent, Icons.delivery_dining, null),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => menus.loadMenus(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ===== HEADER =====
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Halo, $name!', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,),),
                      const Text('Mau pesan apa hari ini?', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                    Stack(children: [
                      IconButton(icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))),
                      if (cart.count > 0) Positioned(right: 6, top: 6, child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                        child: Text('${cart.count}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      )),
                    ]),
                  ]),
                  // Alamat + navigasi
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _navigateHome(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(address, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.navigation, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          const Text('Navigasi', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),

              // ===== LACAK PESANAN AKTIF =====
              if (activeOrder != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrderScreen(order: activeOrder))),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.delivery_dining, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const IconText(Icons.ramen_dining, 'Pesanan Sedang Diproses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(orderStatusLabel(activeOrder.orderStatus), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                          child: const Row(children: [
                            Text('Lacak', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],

              // ===== BANNER =====
              const SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.9),
                  itemCount: banners.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => onNavigateToMenu?.call(query: banners[i].$5),
                      child: BannerCard(title: banners[i].$1, subtitle: banners[i].$2, color: banners[i].$3, icon: banners[i].$4),
                    ),
                  ),
                ),
              ),

              // ===== VOUCHER AKTIF =====
              Consumer<VoucherProvider>(
                builder: (_, vp, __) {
                  final activeVouchers = vp.vouchers.where((v) => v.isAvailable && !v.isExpired).toList();
                  if (activeVouchers.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const IconText(Icons.confirmation_number_outlined, 'Voucher Tersedia', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${activeVouchers.length} voucher', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: activeVouchers.length,
                        itemBuilder: (_, i) {
                          final v = activeVouchers[i];
                          return GestureDetector(
                            onTap: () => _showVoucherDetail(context, v),
                            child: Container(
                              width: 220,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.discount_outlined, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text(v.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                                    const SizedBox(height: 3),
                                    Text(v.description, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 3),
                                    Text(
                                      v.type == DiscountType.percentage ? 'Diskon ${v.value.toInt()}%' : 'Hemat ${toRupiah(v.value)}',
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ])),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ]);
                },
              ),

              // ===== NAVIGASI =====
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const IconText(Icons.location_on, 'Navigasi', iconColor: Colors.red, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateHome(context),
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text('Navigasi ke Rumahku'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openCustomAddress(context),
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Alamat Lain'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      // Status & tombol pin lokasi presisi
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (auth.currentUser?.hasHomeLocation ?? false) ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(
                            (auth.currentUser?.hasHomeLocation ?? false) ? Icons.check_circle : Icons.info_outline,
                            color: (auth.currentUser?.hasHomeLocation ?? false) ? Colors.green : Colors.orange, size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            (auth.currentUser?.hasHomeLocation ?? false)
                              ? 'Lokasi rumah sudah presisi (dari pin peta)'
                              : 'Belum ada titik presisi — navigasi masih pakai alamat teks',
                            style: TextStyle(fontSize: 11, color: (auth.currentUser?.hasHomeLocation ?? false) ? Colors.green.shade800 : Colors.orange.shade800),
                          )),
                          TextButton(
                            onPressed: () => _pinLokasiRumah(context),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: Text((auth.currentUser?.hasHomeLocation ?? false) ? 'Ubah' : 'Pin di Peta', style: const TextStyle(fontSize: 11)),
                          ),
                        ]),
                      ),
                      if (address.isEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 14),
                            SizedBox(width: 6),
                            Expanded(child: Text('Isi alamat di Profil agar Navigasi ke Rumahku aktif', style: TextStyle(fontSize: 11, color: Colors.orange))),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),

              // ===== BEST SELLERS =====
              const SizedBox(height: 20),
              _sectionHeader('Best Seller'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: menus.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: menus.bestSellers.length,
                      itemBuilder: (_, i) {
                        final m = menus.bestSellers[i];
                        return SizedBox(width: 160, child: Padding(padding: const EdgeInsets.only(right: 12), child: MenuCard(
                          menu: m,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailMenuScreen(menu: m))),
                          onAddToCart: () { context.read<CartProvider>().addItem(m); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.name} ditambahkan!'), duration: const Duration(seconds: 1), backgroundColor: AppColors.success)); },
                        )));
                      },
                    ),
              ),

              // ===== REKOMENDASI =====
              const SizedBox(height: 20),
              _sectionHeader('Rekomendasi'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: menus.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
                      itemCount: menus.menus.length > 6 ? 6 : menus.menus.length,
                      itemBuilder: (_, i) {
                        final m = menus.menus[i];
                        return MenuCard(
                          menu: m,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailMenuScreen(menu: m))),
                          onAddToCart: () => context.read<CartProvider>().addItem(m),
                        );
                      },
                    ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, [IconData? icon, Color? iconColor]) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: icon != null
      ? IconText(icon, title, iconColor: iconColor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))
      : Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
  );

  void _showVoucherDetail(BuildContext context, Voucher v) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            child: Text(v.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2)),
          ),
          const SizedBox(height: 16),
          Text(v.description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            v.type == DiscountType.percentage
              ? 'Diskon ${v.value.toInt()}%${v.maxDiscount > 0 ? " (maks. ${toRupiah(v.maxDiscount)})" : ""}'
              : 'Potongan ${toRupiah(v.value)}',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text('Min. belanja: ${toRupiah(v.minOrder)}', style: const TextStyle(color: AppColors.textSecondary)),
          Text('Berlaku s/d: ${formatDate(v.expiredAt)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Kode "${v.code}" disalin! Pakai saat checkout.'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3),
                ));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Salin Kode & Gunakan'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

}
