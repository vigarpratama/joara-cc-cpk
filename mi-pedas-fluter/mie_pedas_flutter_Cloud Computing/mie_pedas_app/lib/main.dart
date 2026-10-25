// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'utils/database_helper.dart';
import 'utils/push_notification_helper.dart';
import 'utils/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/member/member_main.dart';
import 'screens/admin/admin_main.dart';
import 'screens/kurir/kurir_main.dart';
import 'screens/superadmin/superadmin_main.dart';
import 'screens/shared/chat_screen.dart';
import 'models/models.dart';
import 'utils/api_config.dart';

// Navigator key global — dipakai supaya bisa navigasi dari luar widget tree
// (misalnya saat notifikasi ditekan, tanpa perlu BuildContext).
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    initializeDateFormatting('id_ID', null),
  ]);
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    DatabaseHelper.initDesktop();
  }
  PushNotificationHelper.onNotificationTap = _handleNotificationTap;
  await PushNotificationHelper.init(); // Init push notification
  runApp(const JoaraDeliveryApp());
}

// Diarahkan sesuai isi payload notifikasi: 'chat:<orderId>', 'new_order:<orderId>', 'order_ready:<orderId>'
Future<void> _handleNotificationTap(String payload) async {
  debugPrint('🧭 _handleNotificationTap dipanggil dengan payload: $payload');
  final sepIdx = payload.indexOf(':');
  if (sepIdx == -1) { debugPrint('⚠️ Payload tidak punya format type:id yang valid'); return; }
  final type = payload.substring(0, sepIdx);
  final orderId = payload.substring(sepIdx + 1);
  debugPrint('🧭 type=$type, orderId=$orderId');

  // navigatorKey mungkin belum siap (misal cold start, MaterialApp belum mount).
  // Tunggu sebentar sampai currentState tersedia, maksimal ~3 detik.
  NavigatorState? nav = navigatorKey.currentState;
  var attempts = 0;
  while (nav == null && attempts < 15) {
    await Future.delayed(const Duration(milliseconds: 200));
    nav = navigatorKey.currentState;
    attempts++;
  }
  if (nav == null) { debugPrint('❌ navigatorKey.currentState tetap null setelah ditunggu, navigasi dibatalkan'); return; }
  if (orderId.isEmpty) { debugPrint('⚠️ orderId kosong'); return; }

  switch (type) {
    case 'chat':
      final order = await DatabaseHelper().getOrderById(orderId);
      if (order == null) { debugPrint('❌ Order dengan id $orderId tidak ditemukan di database'); return; }
      final prefs = await SharedPreferences.getInstance();
      final myUserId = prefs.getString('userId');
      final isKurir = myUserId != null && myUserId.isNotEmpty && myUserId == order.kurirId;
      debugPrint('🧭 Navigasi ke ChatScreen. myUserId=$myUserId, order.kurirId=${order.kurirId}, isKurir=$isKurir');
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(
        orderId: order.id,
        memberName: order.memberName,
        kurirName: order.kurirName.isEmpty ? 'Kurir' : order.kurirName,
        isKurir: isKurir,
      )));
      break;
    case 'new_order':
      debugPrint('🧭 Navigasi ke AdminMainScreen');
      nav.push(MaterialPageRoute(builder: (_) => const AdminMainScreen()));
      break;
    case 'order_ready':
      debugPrint('🧭 Navigasi ke KurirMainScreen');
      nav.push(MaterialPageRoute(builder: (_) => const KurirMainScreen()));
      break;
    case 'order_update':
      debugPrint('🧭 Navigasi ke MemberMainScreen (update status pesanan untuk pembeli)');
      nav.push(MaterialPageRoute(builder: (_) => const MemberMainScreen()));
      break;
    default:
      debugPrint('⚠️ Tipe payload tidak dikenali: $type');
  }
}

class JoaraDeliveryApp extends StatelessWidget {
  const JoaraDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: ApiConfig.messengerKey,
        title: 'Joara Delivery',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final auth = context.read<AuthProvider>();
    // Splash tetap tampil minimal 1,8 dtk, tapi sesi dimuat bersamaan (bukan berurutan)
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      auth.loadSession(),
    ]);
    if (!mounted) return;

    if (!auth.isLoggedIn) { _go(const LoginScreen()); return; }

    final screen = switch (auth.currentUser!.role) {
      UserRole.member    => const MemberMainScreen(),
      UserRole.admin     => const AdminMainScreen(),
      UserRole.kurir     => const KurirMainScreen(),
      UserRole.superadmin => const SuperAdminMainScreen(),
    };
    _go(screen);

    // Kalau app dibuka (cold start) karena notifikasi ditekan, lanjutkan
    // navigasi ke layar yang sesuai setelah home screen terpasang.
    final launchPayload = await PushNotificationHelper.getLaunchPayload();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _handleNotificationTap(launchPayload);
    }
  }

  void _go(Widget screen) => Navigator.pushReplacement(context,
    PageRouteBuilder(pageBuilder: (_, __, ___) => screen, transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child), transitionDuration: const Duration(milliseconds: 400)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF4A148C), AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
                child: const Icon(Icons.delivery_dining, size: 68, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Joara Delivery', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Platform UMKM Kuliner Terpadu', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 60),
            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}
