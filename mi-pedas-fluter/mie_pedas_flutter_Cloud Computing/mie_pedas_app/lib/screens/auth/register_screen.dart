// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/providers.dart';
import '../../utils/utils.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../member/member_main.dart';
import '../kurir/kurir_main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _withdrawAccountCtrl = TextEditingController();
  bool _obscure = true;
  UserRole _selectedRole = UserRole.member;
  String _withdrawMethod = 'dana'; // 'dana' atau 'bri'
  String? _ktpPath;
  String? _stnkPath;
  final Map<String, String?> _errors = {};

  Future<void> _pickImage(bool isKtp) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isKtp) { _ktpPath = picked.path; } else { _stnkPath = picked.path; }
      });
    }
  }

  void _register() async {
    setState(() => _errors.clear());
    bool valid = true;
    if (_nameCtrl.text.isEmpty) { _errors['name'] = 'Nama tidak boleh kosong'; valid = false; }
    if (!isValidEmail(_emailCtrl.text)) { _errors['email'] = 'Format email tidak valid'; valid = false; }
    if (!isValidPhone(_phoneCtrl.text)) { _errors['phone'] = 'Nomor telepon tidak valid'; valid = false; }
    if (!isValidPassword(_passCtrl.text)) { _errors['pass'] = 'Password minimal 6 karakter'; valid = false; }
    if (_passCtrl.text != _confirmCtrl.text) { _errors['confirm'] = 'Password tidak cocok'; valid = false; }
    if (_selectedRole == UserRole.kurir) {
      if (_plateCtrl.text.isEmpty) { _errors['plate'] = 'Nomor plat wajib diisi'; valid = false; }
      if (_withdrawAccountCtrl.text.isEmpty) { _errors['withdraw'] = 'No. rekening/e-wallet wajib diisi'; valid = false; }
      if (_ktpPath == null) { _errors['ktp'] = 'Foto KTP wajib diupload'; valid = false; }
      if (_stnkPath == null) { _errors['stnk'] = 'Foto STNK wajib diupload'; valid = false; }
    }
    if (!valid) { setState(() {}); return; }

    final ok = await context.read<AuthProvider>().register(
      _nameCtrl.text.trim(), _emailCtrl.text.trim(),
      _phoneCtrl.text.trim(), _passCtrl.text.trim(),
      role: _selectedRole,
      withdrawMethod: _selectedRole == UserRole.kurir ? _withdrawMethod : '',
      withdrawAccountNumber: _selectedRole == UserRole.kurir ? _withdrawAccountCtrl.text.trim() : '',
      plateNumber: _selectedRole == UserRole.kurir ? _plateCtrl.text.trim() : '',
      ktpUrl: _selectedRole == UserRole.kurir ? (_ktpPath ?? '') : '',
      stnkUrl: _selectedRole == UserRole.kurir ? (_stnkPath ?? '') : '',
    );
    if (!mounted) return;
    if (ok) {
      final role = context.read<AuthProvider>().currentUser!.role;
      final screen = role == UserRole.kurir ? const KurirMainScreen() : const MemberMainScreen();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    } else {
      final err = context.read<AuthProvider>().error ?? 'Registrasi gagal';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Akun Baru'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Pilihan Role
            const Align(alignment: Alignment.centerLeft, child: Text('Daftar sebagai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            const SizedBox(height: 12),
            Row(
              children: [
                _roleCard(
                  UserRole.member,
                  Icons.shopping_cart_outlined,
                  'Pembeli',
                  'Pesan mie favoritmu',
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _roleCard(
                  UserRole.kurir,
                  Icons.two_wheeler,
                  'Kurir',
                  'Antar pesanan pelanggan',
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 20),
            _field(_nameCtrl, 'Nama Lengkap', Icons.person_outline, error: _errors['name']),
            const SizedBox(height: 14),
            _field(_emailCtrl, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress, error: _errors['email']),
            const SizedBox(height: 14),
            _field(_phoneCtrl, 'Nomor Telepon', Icons.phone_outlined, keyboard: TextInputType.phone, error: _errors['phone']),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password', prefixIcon: const Icon(Icons.lock_outlined), errorText: _errors['pass'],
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl, obscureText: _obscure,
              decoration: InputDecoration(labelText: 'Konfirmasi Password', prefixIcon: const Icon(Icons.lock_outlined), errorText: _errors['confirm']),
            ),

            if (_selectedRole == UserRole.kurir) ...[
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: IconText(Icons.two_wheeler, 'Data Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              const SizedBox(height: 4),
              const Align(alignment: Alignment.centerLeft, child: Text('Untuk penyetoran dana dan verifikasi kendaraan', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerLeft, child: Text('Metode Penyetoran Dana', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _withdrawMethodChip('dana', Icons.credit_card, 'DANA')),
                const SizedBox(width: 10),
                Expanded(child: _withdrawMethodChip('bri', Icons.account_balance, 'BRI')),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _withdrawAccountCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _withdrawMethod == 'dana' ? 'Nomor DANA' : 'Nomor Rekening BRI',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  errorText: _errors['withdraw'],
                ),
              ),
              const SizedBox(height: 14),
              _field(_plateCtrl, 'Nomor Plat Kendaraan', Icons.two_wheeler_outlined, error: _errors['plate']),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Foto KTP *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              const SizedBox(height: 8),
              _photoPicker(path: _ktpPath, label: 'Upload foto KTP', onTap: () => _pickImage(true)),
              if (_errors['ktp'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errors['ktp']!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Foto STNK *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              const SizedBox(height: 8),
              _photoPicker(path: _stnkPath, label: 'Upload foto STNK', onTap: () => _pickImage(false)),
              if (_errors['stnk'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errors['stnk']!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
            ],

            const SizedBox(height: 24),
            LoadingButton(onPressed: _register, isLoading: auth.isLoading, label: 'Daftar sebagai ${_selectedRole == UserRole.member ? "Pembeli" : "Kurir"}'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text.rich(TextSpan(children: [
                TextSpan(text: 'Sudah punya akun? ', style: TextStyle(color: AppColors.textSecondary)),
                TextSpan(text: 'Masuk', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(UserRole role, IconData icon, String label, String desc, Color color) {
    final selected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 2 : 1),
            boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: selected ? color : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? color : AppColors.textPrimary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (selected)
                Icon(Icons.check_circle, color: color, size: 20)
              else
                Icon(Icons.circle_outlined, color: AppColors.divider, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard, String? error}) =>
    TextField(controller: ctrl, keyboardType: keyboard, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), errorText: error));

  Widget _withdrawMethodChip(String value, IconData icon, String label) {
    final selected = _withdrawMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _withdrawMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
        ),
        child: IconText(icon, label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? AppColors.primary : AppColors.textPrimary, fontSize: 13)),
      ),
    );
  }

  Widget _photoPicker({required String? path, required String label, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 130, width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: path == null
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              Image.file(File(path), fit: BoxFit.cover),
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),
    ),
  );

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose(); _plateCtrl.dispose(); _withdrawAccountCtrl.dispose(); super.dispose(); }
}
