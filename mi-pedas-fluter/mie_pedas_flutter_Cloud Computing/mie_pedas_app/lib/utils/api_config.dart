// lib/utils/api_config.dart
// Pengaturan koneksi ke backend microservice Joara.
//
// Contoh menjalankan:
//   emulator Android : flutter run                                   (default http://10.0.2.2)
//   HP asli (satu WiFi): flutter run --dart-define=API_HOST=http://192.168.1.10
//   server cloud     : flutter run --dart-define=USER_URL=https://user.domainmu.com \
//                                   --dart-define=ORDER_URL=https://order.domainmu.com \
//                                   --dart-define=PAYMENT_URL=https://pay.domainmu.com
//   mode lokal lama  : flutter run --dart-define=USE_BACKEND=false   (semua data tetap di SQLite)
import 'package:flutter/material.dart';

class ApiConfig {
  // true = login, pesanan, dan pembayaran lewat microservice. false = perilaku lama (SQLite lokal saja).
  static const bool useBackend = bool.fromEnvironment('USE_BACKEND', defaultValue: true);

  static const String _host = String.fromEnvironment('API_HOST', defaultValue: 'http://10.0.2.2');
  static const String _userUrl = String.fromEnvironment('USER_URL');
  static const String _orderUrl = String.fromEnvironment('ORDER_URL');
  static const String _paymentUrl = String.fromEnvironment('PAYMENT_URL');

  static String get userUrl => _userUrl.isNotEmpty ? _userUrl : '$_host:3001';
  static String get orderUrl => _orderUrl.isNotEmpty ? _orderUrl : '$_host:3002';
  static String get paymentUrl => _paymentUrl.isNotEmpty ? _paymentUrl : '$_host:3003';

  // Harus sama dengan APP_KEY di .env backend (dipakai untuk mendaftarkan akun admin toko/superadmin).
  static const String appKey = String.fromEnvironment('APP_KEY', defaultValue: 'ganti-app-key');

  // Dipakai ApiService untuk menampilkan pesan error dari mana saja tanpa butuh BuildContext.
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
}
