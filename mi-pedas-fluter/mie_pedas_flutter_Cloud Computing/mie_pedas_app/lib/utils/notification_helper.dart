// lib/utils/notification_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_helper.dart';

class NotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _channel = MethodChannel('mie_pedas_app/notification');

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    debugPrint('🔔 NotificationHelper.init() dipanggil');
    await _plugin.initialize(settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 [NotificationHelper] Notification tapped: payload="${details.payload}"');
        if (details.payload != null && details.payload!.isNotEmpty) {
          PushNotificationHelper.onNotificationTap?.call(details.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackgroundHandler,
    );
    debugPrint('🔔 NotificationHelper.init() selesai, plugin sudah terdaftar');
    const androidChannel = AndroidNotificationChannel(
      'joara_orders', 'Pesanan Baru',
      description: 'Notifikasi pesanan masuk dari pembeli',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);
    _initialized = true;
  }

  /// Kategori notifikasi yang bisa di-toggle user di halaman Notifikasi.
  /// 'pesanan' -> update status pesanan, 'promo' -> promo & voucher.
  /// [payload] dipakai untuk navigasi saat notifikasi ditekan, contoh:
  /// 'chat:ORD123', 'new_order:ORD123', 'order_ready:ORD123'.
  static Future<void> showOrderNotification({
    required String title,
    required String body,
    int id = 0,
    String category = 'pesanan',
    String? payload,
  }) async {
    await init();

    // Cek dulu apakah kategori ini diaktifkan user di halaman Notifikasi.
    final enabled = await isCategoryEnabled(category);
    if (!enabled) return; // user matiin kategori ini, jangan tampilin

    final soundOn = await isSoundEnabled();
    final androidDetails = AndroidNotificationDetails(
      'joara_orders', 'Pesanan Baru',
      channelDescription: 'Notifikasi pesanan masuk dari pembeli',
      importance: Importance.max,
      priority: Priority.high,
      playSound: soundOn,
      enableVibration: soundOn,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(id, title, body, NotificationDetails(android: androidDetails), payload: payload);
  }

  /// Cek preferensi kategori notifikasi ('pesanan' atau 'promo').
  /// Default true (aktif) kalau user belum pernah ubah.
  static Future<bool> isCategoryEnabled(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = category == 'promo' ? 'notif_promo' : 'notif_pesanan';
    return prefs.getBool(key) ?? true;
  }

  static Future<void> playNotificationSound() async {
    try {
      await _channel.invokeMethod('playSound');
    } catch (_) {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    }
  }

  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_sound') ?? true;
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_sound', enabled);
  }

  static void showInAppNotification(BuildContext context, String title, String message, {Color color = const Color(0xFF0288D1)}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ]),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}
