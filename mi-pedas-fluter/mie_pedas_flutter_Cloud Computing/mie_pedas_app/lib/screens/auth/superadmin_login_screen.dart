// lib/screens/auth/superadmin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../superadmin/superadmin_main.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});
  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _login() async {
    setState(() => _error = null);
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) { setState(() => _error = 'Username dan password wajib diisi'); return; }
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginSuperAdmin(_userCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperAdminMainScreen()));
    } else {
      setState(() => _error = auth.error ?? 'Login gagal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 40),
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Superadmin Joara', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
            const Text('Platform Management', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purple.withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_user, size: 14, color: Colors.purple),
                SizedBox(width: 6),
                Text('Akses Level Tertinggi', style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 36),
            TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Username Superadmin', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(onPressed: _login, isLoading: auth.isLoading, label: 'Masuk sebagai Superadmin', color: const Color(0xFF6A1B9A)),
            const SizedBox(height: 14),
            TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Kembali')),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Default: username "joara", password "joara2024"\nGanti segera setelah login pertama!', style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.5))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }
}
