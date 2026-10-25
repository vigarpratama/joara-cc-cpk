// lib/utils/maps_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class MapsService {
  static const double _ratePerKm = 2300;
  static const double _minOngkir = 2300;
  // Batas wajar jarak antar order (delivery lokal). Kalau lebih dari ini,
  // hampir pasti salah satu titik salah geocode ke tempat lain.
  static const double _maxWajarKm = 40;

  // Titik tetap lokasi toko (Jalan Raya Bungah 2, Gresik).
  // Diambil manual dari Google Maps supaya akurat & gak perlu geocode ulang tiap checkout.
  static const LatLng storeLocation = LatLng(-7.051611, 112.573431);

  // Geocode alamat teks → koordinat via Nominatim (OpenStreetMap, GRATIS)
  // Coba full address dulu, kalau gagal coba versi yang disederhanakan bertahap.
  static Future<LatLng?> geocode(String address) async {
    final candidates = _simplifyAddress(address);
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      if (i > 0) await Future.delayed(const Duration(milliseconds: 1100));
      final result = await _geocodeRaw(candidate);
      if (result != null) {
        debugPrint('[MapsService] geocode OK untuk "$candidate" -> ${result.lat},${result.lng}');
        return result;
      }
      debugPrint('[MapsService] geocode GAGAL untuk "$candidate", coba versi lebih simpel...');
    }
    debugPrint('[MapsService] geocode GAGAL TOTAL untuk alamat asli: "$address"');
    return null;
  }

  // Bikin daftar variasi alamat dari paling detail ke paling umum.
  static List<String> _simplifyAddress(String address) {
    final candidates = <String>[address.trim()];

    // Buang detail No/RT/RW yang bikin query terlalu spesifik buat OSM
    final cleaned = address
        .replaceAll(RegExp(r'\bRT\s*\.?\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bRW\s*\.?\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bNo\.?\s*\d+\w*\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isNotEmpty && cleaned != address.trim()) candidates.add(cleaned);

    // Kalau alamat pakai koma, potong dari belakang (kelurahan/kecamatan/kota)
    final commaParts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (int i = 1; i < commaParts.length; i++) {
      candidates.add(commaParts.sublist(i).join(', '));
    }

    // Kalau gak ada koma (kayak "Jl. Raya Bungah No. 46 Bungah Gresik"),
    // coba ambil beberapa kata terakhir — biasanya itu kecamatan + kabupaten/kota
    final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();
    for (final n in [4, 3, 2]) {
      if (words.length > n) candidates.add(words.sublist(words.length - n).join(' '));
    }

    return candidates.toSet().toList(); // dedupe, jaga urutan
  }

  static Future<LatLng?> _geocodeRaw(String address) async {
    try {
      final encoded = Uri.encodeComponent('$address, Indonesia');
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1'
      );
      final res = await http.get(url, headers: {'User-Agent': 'JoaraDelivery/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('[MapsService] Nominatim status ${res.statusCode} untuk "$address"');
        return null;
      }
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;
      return LatLng(
        double.parse(data[0]['lat'].toString()),
        double.parse(data[0]['lon'].toString()),
      );
    } catch (e) {
      debugPrint('[MapsService] Exception geocode "$address": $e');
      return null;
    }
  }

  // Reverse geocode: koordinat → teks alamat (buat auto-isi field alamat
  // pas user pilih titik di peta, biar validasi "alamat gak boleh kosong" lolos
  // dan kurir tetap bisa baca alamatnya dalam bentuk teks).
  static Future<String?> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${point.lat}&lon=${point.lng}&format=json'
      );
      final res = await http.get(url, headers: {'User-Agent': 'JoaraDelivery/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return data['display_name'] as String?;
    } catch (e) {
      debugPrint('[MapsService] Exception reverseGeocode: $e');
      return null;
    }
  }

  // Ambil bentuk rute (garis polyline) melewati beberapa titik berurutan,
  // dipakai buat peta mini "kurir -> toko -> pembeli" di panel kurir.
  static Future<List<LatLng>?> getRouteThroughPoints(List<LatLng> points) async {
    if (points.length < 2) return null;
    try {
      final coordStr = points.map((p) => '${p.lng},${p.lat}').join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordStr'
        '?overview=full&geometries=geojson'
      );
      final res = await http.get(url, headers: {'User-Agent': 'JoaraDelivery/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data['code'] != 'Ok') return null;
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      return coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
    } catch (e) {
      debugPrint('[MapsService] Exception getRouteThroughPoints: $e');
      return null;
    }
  }

  // Hitung jarak via OSRM (OpenStreetMap Routing Machine, GRATIS)
  static Future<double?> getDistanceKm(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.lng},${origin.lat};${destination.lng},${destination.lat}'
        '?overview=false'
      );
      final res = await http.get(url, headers: {'User-Agent': 'JoaraDelivery/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data['code'] != 'Ok') return null;
      final meters = data['routes'][0]['distance'] as num;
      return meters / 1000.0; // konversi ke km
    } catch (_) { return null; }
  }

  // Hitung ongkir berdasarkan jarak
  static double calculateOngkir(double distanceKm) {
    final ongkir = distanceKm * _ratePerKm;
    return ongkir < _minOngkir ? _minOngkir : ongkir;
  }

  // Geocode alamat pembeli + hitung ongkir dari titik toko.
  // storeCoord opsional: kalau dikasih (mis. toko punya lokasi sendiri hasil
  // GPS 3 titik saat daftar), dipakai itu. Kalau tidak, fallback ke titik
  // default lama (storeLocation) biar tetap kompatibel/gak error.
  static Future<({double ongkir, double distanceKm, bool success})> getOngkir({
    required String storeAddress,
    required String customerAddress,
    LatLng? storeCoord,
  }) async {
    final effectiveStoreCoord = storeCoord ?? storeLocation;

    final custCoord = await geocode(customerAddress);
    if (custCoord == null) return (ongkir: 10000.0, distanceKm: 0.0, success: false);

    return _finishOngkir(effectiveStoreCoord, custCoord);
  }

  // Hitung ongkir langsung dari koordinat pilihan peta (dari location picker).
  // Jauh lebih akurat karena skip geocoding teks sepenuhnya.
  // storeCoord opsional, sama seperti getOngkir() di atas.
  static Future<({double ongkir, double distanceKm, bool success})> getOngkirFromCoord(
    LatLng customerCoord, {
    LatLng? storeCoord,
  }) {
    return _finishOngkir(storeCoord ?? storeLocation, customerCoord);
  }

  static Future<({double ongkir, double distanceKm, bool success})> _finishOngkir(
    LatLng storeCoord, LatLng custCoord,
  ) async {
    final distKm = await getDistanceKm(storeCoord, custCoord);
    if (distKm == null) return (ongkir: 10000.0, distanceKm: 0.0, success: false);

    if (distKm > _maxWajarKm) {
      debugPrint('[MapsService] Jarak $distKm km TIDAK WAJAR (>$_maxWajarKm km). Pembeli: ${custCoord.lat},${custCoord.lng}');
      return (ongkir: 10000.0, distanceKm: distKm, success: false);
    }

    return (ongkir: calculateOngkir(distKm), distanceKm: distKm, success: true);
  }
}
