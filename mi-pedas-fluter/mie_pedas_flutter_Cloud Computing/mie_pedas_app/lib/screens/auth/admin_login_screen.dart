// lib/screens/auth/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../admin/admin_main.dart';
import 'store_register_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _login() async {
    setState(() => _error = null);
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) { setState(() => _error = 'Username dan password wajib diisi'); return; }
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginAdmin(_userCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (ok) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminMainScreen())); }
    else { setState(() => _error = auth.error ?? 'Login gagal'); }
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
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: const Icon(Icons.store, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Login Admin UMKM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Text('Masuk ke panel manajemen toko kamu', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 32),
            TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Username Admin', prefixIcon: Icon(Icons.store))),
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
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            LoadingButton(onPressed: _login, isLoading: auth.isLoading, label: 'Masuk ke Panel Admin'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Daftar UMKM baru
            Container(
              decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_business, color: Colors.green)),
                title: const Text('Daftarkan UMKM Baru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Gabung ke platform Joara Delivery', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreRegisterScreen())),
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Kembali ke Login Utama')),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16), SizedBox(width: 8),
                Expanded(child: Text('Username & password diberikan oleh Joara Superadmin atau sesuai yang kamu daftarkan.', style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.5))),
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
