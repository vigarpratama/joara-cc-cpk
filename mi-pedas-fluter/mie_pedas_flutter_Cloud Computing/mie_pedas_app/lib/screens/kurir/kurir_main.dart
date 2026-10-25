// lib/screens/kurir/kurir_main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/notification_helper.dart';
import '../../utils/push_notification_helper.dart';
import '../../utils/database_helper.dart';
import '../../utils/maps_helper.dart';
import '../../utils/maps_service.dart' as ms;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../../widgets/widgets.dart';
import '../auth/login_screen.dart';
import '../shared/chat_screen.dart';
import 'kurir_stats_screen.dart';
import 'kurir_profile_screen.dart';

class KurirMainScreen extends StatefulWidget {
  const KurirMainScreen({super.key});
  @override
  State<KurirMainScreen> createState() => _KurirMainScreenState();
}

class _KurirMainScreenState extends State<KurirMainScreen> {
  int _idx = 0;
  Timer? _timer;
  int _lastReadyCount = 0;
  bool _soundEnabled = true;
  bool _isOnline = false;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) context.read<OrderProvider>().loadKurirOrders(user.id);
      context.read<StoreProvider>().loadStores(); // buat ambil koordinat resto (navigasi 3 titik)
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkReadyOrders());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = await NotificationHelper.isSoundEnabled();
    _isOnline = prefs.getBool('kurir_online') ?? false;
    setState(() {});
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isTogglingStatus = true);
    await Future.delayed(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kurir_online', value);
    setState(() { _isOnline = value; _isTogglingStatus = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(value ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(value ? 'Kamu sekarang ONLINE!' : 'Kamu sekarang OFFLINE'),
        ]),
        backgroundColor: value ? AppColors.success : Colors.grey.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  Future<void> _checkReadyOrders() async {
    if (!_isOnline) return;
    final orders = !mounted ? null : context.read<OrderProvider>();
    final user = !mounted ? null : context.read<AuthProvider>().currentUser;
    if (orders == null || user == null) return;
    await orders.loadKurirOrders(user.id);
    final readyOrders = orders.orders.where((o) => o.orderStatus == OrderStatus.ready).toList();
    final readyCount = readyOrders.length;
    if (readyCount > _lastReadyCount && _lastReadyCount >= 0) {
      for (final o in readyOrders.take(readyCount - _lastReadyCount)) {
        await PushNotificationHelper.showOrderReadyNotification(
          orderId: o.id, memberName: o.memberName, address: o.deliveryAddress);
      }
      if (_soundEnabled) await NotificationHelper.playNotificationSound();
      if (mounted) NotificationHelper.showInAppNotification(
        context, 'Pesanan Siap!', 'Ada $readyCount pesanan siap diambil!', color: Colors.green);
    }
    _lastReadyCount = readyCount;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();
    final readyOrders = orders.orders.where((o) => o.orderStatus == OrderStatus.ready).toList();
    final myOrders = orders.orders.where((o) =>
      o.orderStatus == OrderStatus.delivering && o.kurirId == auth.currentUser?.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Kurir'),
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              await NotificationHelper.setSoundEnabled(!_soundEnabled);
              setState(() => _soundEnabled = !_soundEnabled);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _toggleOnline(false);
              await auth.logout();
              if (context.mounted) Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
          ),
        ],
      ),
      body: Column(children: [
        // Toggle Online/Offline bar
        _buildOnlineToggle(),
        Expanded(
          child: IndexedStack(index: _idx, children: [
            _buildOrderList(context, 'Pesanan Siap Diambil', Icons.two_wheeler, readyOrders, true),
            _buildOrderList(context, 'Pengantaran Saya', Icons.inventory_2_outlined, myOrders, false),
            const KurirStatsScreen(),
            KurirProfileScreen(
              isOnline: _isOnline,
              soundEnabled: _soundEnabled,
              onToggleOnline: _toggleOnline,
              onToggleSound: (v) async {
                await NotificationHelper.setSoundEnabled(v);
                setState(() => _soundEnabled = v);
              },
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: [
          NavigationDestination(
            icon: Badge(label: Text('${readyOrders.length}'), isLabelVisible: readyOrders.isNotEmpty && _isOnline,
              child: const Icon(Icons.home_outlined)),
            selectedIcon: Badge(label: Text('${readyOrders.length}'), isLabelVisible: readyOrders.isNotEmpty && _isOnline,
              child: const Icon(Icons.home)),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Badge(label: Text('${myOrders.length}'), isLabelVisible: myOrders.isNotEmpty,
              child: const Icon(Icons.delivery_dining_outlined)),
            selectedIcon: Badge(label: Text('${myOrders.length}'), isLabelVisible: myOrders.isNotEmpty,
              child: const Icon(Icons.delivery_dining)),
            label: 'Pengantaran',
          ),
          const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Statistik'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _isOnline ? AppColors.success.withOpacity(0.08) : Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: _isOnline ? AppColors.success.withOpacity(0.3) : AppColors.divider)),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: _isOnline ? AppColors.success : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: _isOnline ? [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)] : [],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isOnline ? 'Kamu Sedang ONLINE' : 'Kamu Sedang OFFLINE',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
              color: _isOnline ? AppColors.success : Colors.grey.shade600)),
          Text(_isOnline ? 'Siap menerima pesanan' : 'Aktifkan untuk menerima pesanan',
            style: TextStyle(fontSize: 11, color: _isOnline ? AppColors.success.withOpacity(0.8) : Colors.grey.shade500)),
        ])),
        _isTogglingStatus
          ? const SizedBox(width: 44, height: 24, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
          : Transform.scale(
              scale: 1.1,
              child: Switch(
                value: _isOnline, onChanged: _toggleOnline,
                activeColor: Colors.white, activeTrackColor: AppColors.success,
                inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.grey.shade400,
              ),
            ),
      ]),
    );
  }

  Widget _buildOrderList(BuildContext context, String title, IconData titleIcon, List<Order> orderList, bool canPickUp) {
    final orders = context.read<OrderProvider>();
    final auth = context.read<AuthProvider>();

    if (canPickUp && !_isOnline) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 90, height: 90,
                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                child: Icon(Icons.power_settings_new, size: 48, color: Colors.grey.shade400)),
              const SizedBox(height: 20),
              const Text('Kamu Sedang Offline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Text('Aktifkan toggle Online untuk mulai menerima pesanan',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _toggleOnline(true),
                icon: const Icon(Icons.power_settings_new), label: const Text('Aktifkan Online'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconText(titleIcon, title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () async {
                final user = auth.currentUser;
                if (user != null) await orders.loadKurirOrders(user.id);
              }),
          ]),
        ),
        Expanded(
          child: orderList.isEmpty
            ? EmptyState(
                icon: canPickUp ? Icons.hourglass_empty : Icons.delivery_dining_outlined,
                title: canPickUp ? 'Tidak ada pesanan siap' : 'Tidak ada pengantaran aktif')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: orderList.length,
                itemBuilder: (_, i) {
                  final o = orderList[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: canPickUp ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        if (o.storeName.isNotEmpty) ...[
                          Row(children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: o.storePhotoUrl.isNotEmpty ? FileImage(File(o.storePhotoUrl)) : null,
                              child: o.storePhotoUrl.isEmpty ? const Icon(Icons.storefront, size: 12, color: AppColors.primary) : null,
                            ),
                            const SizedBox(width: 6),
                            IconText(Icons.storefront, '${o.storeName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ]),
                          const SizedBox(height: 6),
                        ],
                        Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconText(Icons.phone_android, '${o.memberPhone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Row(children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 14),
                          const SizedBox(width: 4),
                          Expanded(child: Text(o.deliveryAddress,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          GestureDetector(
                            onTap: () {
                              final store = context.read<StoreProvider>().stores.where((s) => s.id == o.storeId).firstOrNull;
                              MapsHelper.showFullRouteNavigation(
                                context,
                                storeLat: store?.latitude ?? 0,
                                storeLng: store?.longitude ?? 0,
                                storeAddress: store?.address ?? o.storeName,
                                customerLat: o.customerLat,
                                customerLng: o.customerLng,
                                customerAddress: o.deliveryAddress,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.navigation, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Navigasi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),
                        ]),
                        const Divider(height: 12),
                        if (canPickUp) ...[
                          Builder(builder: (_) {
                            final store = context.read<StoreProvider>().stores.where((s) => s.id == o.storeId).firstOrNull;
                            return MiniRouteMap(
                              storeLat: store?.latitude ?? 0,
                              storeLng: store?.longitude ?? 0,
                              customerLat: o.customerLat,
                              customerLng: o.customerLng,
                            );
                          }),
                          const SizedBox(height: 10),
                        ],
                        ...o.items.map((item) => Text('• ${item.menuName} x${item.quantity}',
                          style: const TextStyle(fontSize: 12))),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(toRupiah(o.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                          Row(children: [
                            if (!canPickUp) Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    orderId: o.id,
                                    memberName: o.memberName,
                                    memberPhotoUrl: o.memberPhotoUrl,
                                    memberPhone: o.memberPhone,
                                    kurirName: auth.currentUser?.name ?? 'Kurir',
                                    kurirPhotoUrl: auth.currentUser?.photoUrl ?? '',
                                    kurirPhone: auth.currentUser?.phone ?? '',
                                    isKurir: true,
                                  ),
                                )),
                                icon: const Icon(Icons.chat_outlined, size: 16),
                                label: const Text('Chat', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            if (canPickUp)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final taken = await orders.takeOrder(o, auth.currentUser!);
                                  if (taken && context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: IconText(Icons.check_circle, 'Pesanan diambil!'), backgroundColor: AppColors.success));
                                },
                                icon: const Icon(Icons.delivery_dining, size: 16),
                                label: const Text('Ambil'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await orders.updateStatus(o.id, OrderStatus.delivered);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: IconText(Icons.check_circle, 'Pesanan terkirim!'), backgroundColor: AppColors.success));
                                },
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Terkirim'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                              ),
                          ]),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
        ),
      ]),
    );
  }
}

// ==================== PETA MINI RUTE 3 TITIK ====================
// Kurir (posisi sekarang) -> Toko (pickup) -> Pembeli (drop-off)
class MiniRouteMap extends StatefulWidget {
  final double storeLat, storeLng;
  final double customerLat, customerLng;
  const MiniRouteMap({
    super.key,
    required this.storeLat, required this.storeLng,
    required this.customerLat, required this.customerLng,
  });

  @override
  State<MiniRouteMap> createState() => _MiniRouteMapState();
}

class _MiniRouteMapState extends State<MiniRouteMap> {
  ll.LatLng? _myPos;
  List<ll.LatLng>? _route;
  bool _loading = true;
  bool _hasStore = false, _hasCustomer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _hasStore = widget.storeLat != 0 && widget.storeLng != 0;
    _hasCustomer = widget.customerLat != 0 && widget.customerLng != 0;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
              .timeout(const Duration(seconds: 6));
          _myPos = ll.LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // gak apa kalau gagal ambil GPS, peta tetep tampil tanpa titik kurir
    }

    // Susun titik-titik yang tersedia buat digambar rutenya
    final points = <ms.LatLng>[];
    if (_myPos != null) points.add(ms.LatLng(_myPos!.latitude, _myPos!.longitude));
    if (_hasStore) points.add(ms.LatLng(widget.storeLat, widget.storeLng));
    if (_hasCustomer) points.add(ms.LatLng(widget.customerLat, widget.customerLng));

    if (points.length >= 2) {
      final route = await ms.MapsService.getRouteThroughPoints(points);
      if (route != null) _route = route.map((p) => ll.LatLng(p.lat, p.lng)).toList();
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 150,
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (!_hasStore && !_hasCustomer) {
      return Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Koordinat toko/pembeli belum tersedia', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
      );
    }

    final markers = <Marker>[];
    if (_myPos != null) markers.add(Marker(point: _myPos!, width: 34, height: 34,
      child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 28)));
    if (_hasStore) markers.add(Marker(point: ll.LatLng(widget.storeLat, widget.storeLng), width: 34, height: 34,
      child: const Icon(Icons.storefront, color: AppColors.primary, size: 28)));
    if (_hasCustomer) markers.add(Marker(point: ll.LatLng(widget.customerLat, widget.customerLng), width: 34, height: 34,
      child: const Icon(Icons.location_pin, color: AppColors.error, size: 30)));

    final center = markers.isNotEmpty ? markers[markers.length ~/ 2].point : const ll.LatLng(-7.05, 112.57);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 150,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.joara.delivery'),
              if (_route != null) PolylineLayer(polylines: [Polyline(points: _route!, color: AppColors.primary, strokeWidth: 4)]),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ),
    );
  }
}
