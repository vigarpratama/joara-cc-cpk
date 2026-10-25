// lib/screens/member/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../../utils/theme.dart';
import '../../utils/maps_service.dart' as maps;

/// Screen buat pilih titik lokasi pengiriman langsung di peta (OpenStreetMap).
/// Return-nya adalah maps.LatLng (bukan latlong2.LatLng) lewat Navigator.pop.
class LocationPickerScreen extends StatefulWidget {
  final maps.LatLng? initialLocation;
  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  late ll.LatLng _picked;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialLocation ?? maps.MapsService.storeLocation;
    _picked = ll.LatLng(init.lat, init.lng);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMsg('Aktifkan GPS/Location Service dulu ya.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMsg('Izin lokasi ditolak.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showMsg('Izin lokasi diblokir permanen. Aktifkan lewat Setting HP.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      final newPos = ll.LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = newPos);
      _mapController.move(newPos, 16);
    } catch (e) {
      _showMsg('Gagal ambil lokasi GPS: $e');
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _confirm() {
    Navigator.pop(context, maps.LatLng(_picked.latitude, _picked.longitude));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi Pengiriman'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Pilih', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 15,
              onTap: (tapPos, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.joara.delivery',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _picked,
                  width: 44, height: 44,
                  child: const Icon(Icons.location_pin, color: AppColors.error, size: 44),
                ),
              ]),
            ],
          ),
          // Info bar atas
          Positioned(
            top: 12, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Ketuk peta atau geser buat nentuin titik lokasi kamu', style: TextStyle(fontSize: 12))),
              ]),
            ),
          ),
          // Tombol lokasi saya ini
          Positioned(
            bottom: 90, right: 16,
            child: FloatingActionButton(
              heroTag: 'gps_btn',
              backgroundColor: Colors.white,
              onPressed: _loadingGps ? null : _useCurrentLocation,
              child: _loadingGps
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
          // Koordinat + tombol konfirmasi bawah
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
              ]),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${_picked.latitude.toStringAsFixed(6)}, ${_picked.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Gunakan Titik Ini'),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
