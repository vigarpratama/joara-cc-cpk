// lib/utils/push_notification_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// WAJIB top-level function (bukan method di dalam class) + pragma ini,
// supaya Android bisa panggil handler ini di isolate terpisah saat
// notifikasi ditekan dalam kondisi app tertutup total (killed).
@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse details) {
  debugPrint('🔔 [BACKGROUND] Notification tapped while app killed: ${details.payload}');
  if (details.payload != null && details.payload!.isNotEmpty) {
    PushNotificationHelper.onNotificationTap?.call(details.payload!);
  }
}

class PushNotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Callback dipanggil saat notifikasi ditekan. Diisi dari main.dart supaya
  // helper ini tidak perlu import screen (hindari circular import).
  static void Function(String payload)? onNotificationTap;

  // Channel details dengan suara default sistem
  static const _orderChannel = AndroidNotificationChannel(
    'new_order_channel',
    'Pesanan Baru',
    description: 'Notifikasi pesanan baru masuk',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFD32F2F),
  );

  static const _readyChannel = AndroidNotificationChannel(
    'order_ready_channel',
    'Pesanan Siap',
    description: 'Notifikasi pesanan siap diambil kurir',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF4CAF50),
  );

  static const _chatChannel = AndroidNotificationChannel(
    'chat_channel',
    'Pesan Chat',
    description: 'Notifikasi pesan chat baru',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    debugPrint('🔔 PushNotificationHelper.init() dipanggil');
    await _plugin.initialize(settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 [FOREGROUND/BACKGROUND] Notification tapped: payload="${details.payload}"');
        if (details.payload != null && details.payload!.isNotEmpty) {
          if (onNotificationTap == null) {
            debugPrint('⚠️ onNotificationTap masih null! Pastikan sudah di-set sebelum init() dipanggil.');
          } else {
            debugPrint('✅ Memanggil onNotificationTap dengan payload: ${details.payload}');
            onNotificationTap?.call(details.payload!);
          }
        } else {
          debugPrint('⚠️ Payload kosong/null, tidak ada aksi navigasi.');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackgroundHandler,
    );
    debugPrint('🔔 PushNotificationHelper.init() selesai, plugin sudah terdaftar');

    // Daftarkan channel ke Android
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_orderChannel);
    await androidImpl?.createNotificationChannel(_readyChannel);
    await androidImpl?.createNotificationChannel(_chatChannel);

    // Minta permission Android 13+
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  // Notifikasi pesanan baru (Admin)
  static Future<void> showNewOrderNotification({
    required String orderId,
    required String memberName,
    required double totalAmount,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      _orderChannel.id,
      _orderChannel.name,
      channelDescription: _orderChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        '$memberName memesan • ${_formatRupiah(totalAmount)}',
        summaryText: 'Pesanan Baru',
      ),
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFD32F2F),
      ticker: 'Pesanan baru dari $memberName',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      orderId.hashCode.abs() % 10000,
      '🔔 Pesanan Baru Masuk!',
      '$memberName • ${_formatRupiah(totalAmount)}',
      details,
      payload: 'new_order:$orderId',
    );
  }

  // Notifikasi pesanan siap (Kurir)
  static Future<void> showOrderReadyNotification({
    required String orderId,
    required String memberName,
    required String address,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      _readyChannel.id,
      _readyChannel.name,
      channelDescription: _readyChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF4CAF50),
      styleInformation: BigTextStyleInformation(
        'Antar ke: $address',
        summaryText: 'Pesanan $memberName',
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      (orderId.hashCode.abs() % 10000) + 1,
      '🛵 Pesanan Siap Diambil!',
      'Dari: $memberName → $address',
      details,
      payload: 'order_ready:$orderId',
    );
  }

  // Notifikasi chat baru
  static Future<void> showChatNotification({
    required String orderId,
    required String senderName,
    required String message,
    required bool isKurir,
    String? senderPhotoUrl,
  }) async {
    await init();
    final hasPhoto = senderPhotoUrl != null && senderPhotoUrl.isNotEmpty && File(senderPhotoUrl).existsSync();
    final androidDetails = AndroidNotificationDetails(
      _chatChannel.id,
      _chatChannel.name,
      channelDescription: _chatChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: hasPhoto ? FilePathAndroidBitmap(senderPhotoUrl) : null,
      styleInformation: MessagingStyleInformation(
        Person(
          name: senderName,
          important: true,
          icon: hasPhoto ? BitmapFilePathAndroidIcon(senderPhotoUrl) : null,
        ),
        messages: [Message(
          message, DateTime.now(),
          Person(
            name: senderName,
            icon: hasPhoto ? BitmapFilePathAndroidIcon(senderPhotoUrl) : null,
          ),
        )],
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      (orderId.hashCode.abs() % 10000) + 2,
      '💬 ${isKurir ? "Kurir" : "Pembeli"}: $senderName',
      message.length > 60 ? '${message.substring(0, 60)}...' : message,
      details,
      payload: 'chat:$orderId',
    );
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();

  // Cek apakah app baru saja dibuka (cold start) karena notifikasi ditekan.
  // Perlu dipanggil setelah init() dan setelah navigatorKey siap dipakai.
  static Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    debugPrint('🔔 getLaunchPayload: didNotificationLaunchApp=${details?.didNotificationLaunchApp}, payload=${details?.notificationResponse?.payload}');
    if (details?.didNotificationLaunchApp == true) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  static String _formatRupiah(double value) {
    if (value >= 1000000) return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${value.toStringAsFixed(0)}';
  }
}
