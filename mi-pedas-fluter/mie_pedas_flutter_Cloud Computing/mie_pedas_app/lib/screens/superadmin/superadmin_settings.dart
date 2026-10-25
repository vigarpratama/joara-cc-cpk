// lib/screens/superadmin/superadmin_settings.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../auth/login_screen.dart';

class SuperAdminSettings extends StatefulWidget {
  const SuperAdminSettings({super.key});
  @override
  State<SuperAdminSettings> createState() => _SuperAdminSettingsState();
}

class _SuperAdminSettingsState extends State<SuperAdminSettings> {
  final _userCtrl = TextEditingController(text: 'joara');
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true, _loading = false;
  String? _success, _error;

  Future<void> _save() async {
    setState(() { _success = null; _error = null; });
    if (_userCtrl.text.isEmpty || _oldPassCtrl.text.isEmpty) { setState(() => _error = 'Username dan password lama wajib diisi'); return; }
    if (_newPassCtrl.text.isNotEmpty && _newPassCtrl.text != _confirmCtrl.text) { setState(() => _error = 'Konfirmasi password tidak cocok'); return; }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateSuperAdminCredentials(oldPassword: _oldPassCtrl.text, newUsername: _userCtrl.text, newPassword: _newPassCtrl.text.isEmpty ? null : _newPassCtrl.text);
    setState(() { _loading = false; ok ? _success = 'Berhasil diperbarui!' : _error = auth.error; });
    if (ok) { _oldPassCtrl.clear(); _newPassCtrl.clear(); _confirmCtrl.clear(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Superadmin'), backgroundColor: const Color(0xFF6A1B9A)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconText(Icons.lock_outline, 'Ubah Kredensial Superadmin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 14),
              TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Username Superadmin')),
              const SizedBox(height: 10),
              TextField(controller: _oldPassCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: 'Password Lama', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)))),
              const SizedBox(height: 10),
              TextField(controller: _newPassCtrl, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Password Baru (opsional)')),
              const SizedBox(height: 10),
              TextField(controller: _confirmCtrl, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru')),
              if (_error != null) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: AppColors.error)))],
              if (_success != null) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(_success!, style: const TextStyle(color: AppColors.success)))],
              const SizedBox(height: 14),
              LoadingButton(onPressed: _save, isLoading: _loading, label: 'Simpan', color: const Color(0xFF6A1B9A)),
            ])),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Keluar', style: TextStyle(color: AppColors.error)),
              onTap: () async { await context.read<AuthProvider>().logout(); if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); },
            ),
          ),
        ]),
      ),
    );
  }
}
