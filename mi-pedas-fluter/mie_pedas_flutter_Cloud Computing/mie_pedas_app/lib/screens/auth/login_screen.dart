// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/utils.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import 'register_screen.dart';
import 'admin_login_screen.dart';
import 'superadmin_login_screen.dart';
import '../member/member_main.dart';
import '../kurir/kurir_main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _emailError, _passError;

  void _login() async {
    setState(() { _emailError = null; _passError = null; });
    if (!isValidEmail(_emailCtrl.text)) { setState(() => _emailError = 'Format email tidak valid'); return; }
    if (_passCtrl.text.isEmpty) { setState(() => _passError = 'Password tidak boleh kosong'); return; }
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      final role = auth.currentUser!.role;
      if (role == UserRole.member) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MemberMainScreen()));
      else if (role == UserRole.kurir) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KurirMainScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Login gagal'), backgroundColor: AppColors.error));
    }
  }

  void _demoLogin(UserRole role) async {
    final email = role == UserRole.kurir ? 'kurir@demo.com' : 'member@demo.com';
    final ok = await context.read<AuthProvider>().login(email, 'demo123');
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<AuthProvider>().error ?? 'Login demo gagal'), backgroundColor: AppColors.error));
      return;
    }
    if (role == UserRole.kurir) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KurirMainScreen()));
    else Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MemberMainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 32),
            // Logo & Nama App
            Column(children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.delivery_dining, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 14),
              const Text('Joara Delivery', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const Text('Platform UMKM Kuliner Terpadu', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 36),
            Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Selamat Datang', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Masuk ke akunmu', style: TextStyle(color: AppColors.textSecondary)),
            ])),
            const SizedBox(height: 20),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), errorText: _emailError)),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password', prefixIcon: const Icon(Icons.lock_outlined), errorText: _passError,
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
              ),
            ),
            const SizedBox(height: 20),
            LoadingButton(onPressed: _login, isLoading: auth.isLoading, label: 'Masuk'),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text.rich(TextSpan(children: [
                TextSpan(text: 'Belum punya akun? ', style: TextStyle(color: AppColors.textSecondary)),
                TextSpan(text: 'Daftar Sekarang', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ])),
            ),
            const SizedBox(height: 20),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Demo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))), Expanded(child: Divider())]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _demoLogin(UserRole.member), style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue)), child: const IconText(Icons.person_outline, 'Member'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _demoLogin(UserRole.kurir), style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)), child: const IconText(Icons.two_wheeler, 'Kurir'))),
            ]),
            const SizedBox(height: 24),
            // Panel Login
            Container(
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                ListTile(
                  leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.store, color: AppColors.primary)),
                  title: const Text('Login Admin UMKM', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Kelola toko & pesananmu', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.admin_panel_settings, color: Colors.purple)),
                  title: const Text('Login Superadmin Joara', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Kelola semua UMKM & platform', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminLoginScreen())),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }
}
