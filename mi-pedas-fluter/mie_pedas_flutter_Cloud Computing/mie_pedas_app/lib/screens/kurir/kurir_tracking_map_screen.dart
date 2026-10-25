// lib/screens/kurir/kurir_tracking_map_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/database_helper.dart';
import '../../utils/maps_helper.dart';

class KurirTrackingMapScreen extends StatefulWidget {
  final Order order;
  const KurirTrackingMapScreen({super.key, required this.order});

  @override
  State<KurirTrackingMapScreen> createState() => _KurirTrackingMapScreenState();
}

class _KurirTrackingMapScreenState extends State<KurirTrackingMapScreen> {
  LatLng? _start;   // titik 1: posisi kurir sekarang
  LatLng? _store;   // titik 2: resto
  LatLng? _customer; // titik 3: customer
  Store? _storeData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Titik 1: posisi kurir sekarang (GPS HP)
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
          setState(() { _loading = false; _error = 'Izin lokasi ditolak. Aktifkan izin lokasi untuk melihat rute.'; });
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      _start = LatLng(pos.latitude, pos.longitude);

      // Titik 2: resto
      _storeData = await DatabaseHelper().getStoreById(widget.order.storeId);
      if (_storeData != null && _storeData!.hasLocation) {
        _store = LatLng(_storeData!.latitude, _storeData!.longitude);
      }

      // Titik 3: customer
      if (widget.order.hasCustomerLocation) {
        _customer = LatLng(widget.order.customerLat, widget.order.customerLng);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Gagal mengambil lokasi: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rute 3 Titik')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_off, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
              ]),
            ))
          : Column(children: [
              _buildStoreInfoCard(),
              _buildStatusBanner(),
              Expanded(child: _buildMap()),
            ]),
    );
  }

  Widget _buildStoreInfoCard() {
    final photoUrl = widget.order.storePhotoUrl;
    if (photoUrl.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(photoUrl), width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56, height: 56, color: AppColors.divider,
              child: const Icon(Icons.store, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tampak depan resto', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(
            widget.order.storeName.isEmpty ? 'Resto' : widget.order.storeName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ])),
      ]),
    );
  }

  Widget _buildStatusBanner() {
    final missing = <String>[];
    if (_store == null) missing.add('lokasi resto');
    if (_customer == null) missing.add('lokasi customer');
    if (missing.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.orange.withOpacity(0.1),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.orange, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('Belum ada ${missing.join(' & ')} — titik itu tidak ditampilkan di peta. Titik lain tetap bisa dipakai untuk navigasi manual lewat tombol Navigasi.', style: const TextStyle(color: Colors.orange, fontSize: 12))),
      ]),
    );
  }

  Widget _buildMap() {
    final points = [_start, _store, _customer].whereType<LatLng>().toList();
    if (points.isEmpty) return const Center(child: Text('Tidak ada titik yang bisa ditampilkan'));

    final center = _start ?? points.first;

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.joara.delivery',
        ),
        if (points.length >= 2)
          PolylineLayer(polylines: [
            Polyline(points: points, strokeWidth: 4, color: AppColors.primary),
          ]),
        MarkerLayer(markers: [
          if (_start != null) _marker(_start!, Icons.two_wheeler, Colors.blue, 'Kamu'),
          if (_store != null) _marker(_store!, Icons.store, Colors.orange, widget.order.storeName.isEmpty ? 'Resto' : widget.order.storeName),
          if (_customer != null) _marker(_customer!, Icons.person_pin_circle, Colors.green, widget.order.memberName),
        ]),
      ],
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color, String label) => Marker(
    point: point, width: 120, height: 60,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(height: 2),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ]),
  );
}
