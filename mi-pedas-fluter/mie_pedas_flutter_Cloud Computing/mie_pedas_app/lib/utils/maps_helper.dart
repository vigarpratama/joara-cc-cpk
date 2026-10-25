// lib/utils/maps_helper.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/widgets.dart';

class MapsHelper {
  // Buka Google Maps navigasi dari posisi saat ini ke tujuan
  static Future<void> navigateTo(BuildContext context, String destinationAddress) async {
    if (destinationAddress.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat tujuan tidak tersedia'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final encoded = Uri.encodeComponent(destinationAddress);

    // Coba buka Google Maps app dulu
    final googleMapsApp = Uri.parse('google.navigation:q=$encoded&mode=d');
    // Fallback ke browser jika app tidak ada
    final googleMapsBrowser = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsApp)) {
        await launchUrl(googleMapsApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsBrowser, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka Maps: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Buka Waze sebagai alternatif
  static Future<void> navigateWithWaze(BuildContext context, String destinationAddress) async {
    final encoded = Uri.encodeComponent(destinationAddress);
    final wazeUri = Uri.parse('waze://?q=$encoded&navigate=yes');
    final wazeBrowser = Uri.parse('https://waze.com/ul?q=$encoded&navigate=yes');

    try {
      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(wazeBrowser, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka Waze: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Navigasi 3 titik: posisi kurir SEKARANG -> toko (pickup) -> pembeli (drop-off).
  // Dipakai kurir SEBELUM mengantar (masih perlu mampir ambil pesanan di toko dulu).
  static Future<void> showFullRouteNavigation(
    BuildContext context, {
    required double storeLat,
    required double storeLng,
    required String storeAddress,
    double customerLat = 0,
    double customerLng = 0,
    required String customerAddress,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: IconText(Icons.location_on, 'Mengambil lokasi kamu...'), duration: Duration(seconds: 2)));

    Position? pos;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
              .timeout(const Duration(seconds: 8));
        }
      }
    } catch (_) {
      // gagal ambil GPS — biarin null, Google Maps yang nentuin titik awal otomatis
    }

    final waypoint = (storeLat != 0 && storeLng != 0) ? '$storeLat,$storeLng' : Uri.encodeComponent(storeAddress);
    final destination = (customerLat != 0 && customerLng != 0) ? '$customerLat,$customerLng' : Uri.encodeComponent(customerAddress);

    final params = <String, String>{
      'api': '1',
      'destination': destination,
      'waypoints': waypoint,
      'travelmode': 'driving',
    };
    if (pos != null) params['origin'] = '${pos.latitude},${pos.longitude}';

    final uri = Uri.https('www.google.com', '/maps/dir/', params);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Gagal membuka Maps: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Tampilkan dialog pilih aplikasi navigasi
  static Future<void> showNavigationOptions(BuildContext context, String address) async {
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat pembeli tidak tersedia'), backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconText(Icons.map_outlined, 'Navigasi ke Pembeli', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 20),
            // Google Maps
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map, color: Colors.blue, size: 26),
              ),
              title: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Navigasi GPS real-time'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () { Navigator.pop(context); navigateTo(context, address); },
            ),
            const Divider(height: 8),
            // Waze
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.navigation, color: Colors.lightBlue, size: 26),
              ),
              title: const Text('Waze', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Navigasi dengan info lalu lintas'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () { Navigator.pop(context); navigateWithWaze(context, address); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
