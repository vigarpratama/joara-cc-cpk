// lib/screens/admin/admin_settings_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/maps_service.dart';
import '../../widgets/widgets.dart';
import '../auth/login_screen.dart';
import '../member/location_picker_screen.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});
  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _usernameCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _bankNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _gopayCtrl = TextEditingController();
  final _ovoCtrl = TextEditingController();
  final _danaCtrl = TextEditingController();
  bool _obscureOld = true, _obscureNew = true;
  bool _loading = false;
  bool _savingLocation = false;
  bool _savingQris = false;
  bool _savingStorefront = false;
  bool _savingProfilePhoto = false;
  bool _savingBankEwallet = false;
  bool _bankFieldsLoaded = false;
  String? _bankName;
  String? _successMsg, _errorMsg;
  String? _bankSuccessMsg, _bankErrorMsg;

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _savingProfilePhoto = true);
    await context.read<AuthProvider>().updateProfilePhoto(picked.path);
    if (!mounted) return;
    setState(() => _savingProfilePhoto = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Foto profil admin berhasil disimpan'), backgroundColor: AppColors.success));
  }

  Future<void> _pickStorefrontImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _savingStorefront = true);
    final ok = await context.read<AuthProvider>().updateStoreStorefrontPhoto(picked.path);
    if (!mounted) return;
    setState(() => _savingStorefront = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Foto toko berhasil disimpan' : 'Gagal menyimpan foto toko'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _pickQrisImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _savingQris = true);
    final ok = await context.read<AuthProvider>().updateStoreQris(picked.path);
    if (!mounted) return;
    setState(() => _savingQris = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Foto QRIS berhasil disimpan' : 'Gagal menyimpan foto QRIS'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
  }

  Future<void> _pilihLokasiResto() async {
    final store = context.read<AuthProvider>().currentStore;
    final current = (store != null && store.hasLocation) ? LatLng(store.latitude, store.longitude) : null;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: current)),
    );
    if (result == null || !mounted) return;
    setState(() => _savingLocation = true);
    final ok = await context.read<AuthProvider>().updateStoreLocation(result.lat, result.lng);
    if (!mounted) return;
    setState(() => _savingLocation = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Lokasi resto berhasil disimpan' : 'Gagal menyimpan lokasi'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  void _loadCurrentUsername() async {
    final auth = context.read<AuthProvider>();
    final username = await auth.getAdminUsername();
    _usernameCtrl.text = username;
  }

  void _saveCredentials() async {
    setState(() { _successMsg = null; _errorMsg = null; });

    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Username tidak boleh kosong');
      return;
    }
    if (_oldPassCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Masukkan password lama untuk konfirmasi');
      return;
    }
    if (_newPassCtrl.text.isNotEmpty && _newPassCtrl.text.length < 6) {
      setState(() => _errorMsg = 'Password baru minimal 6 karakter');
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _errorMsg = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateAdminCredentials(
      oldPassword: _oldPassCtrl.text.trim(),
      newUsername: _usernameCtrl.text.trim(),
      newPassword: _newPassCtrl.text.isEmpty ? null : _newPassCtrl.text.trim(),
    );
    setState(() => _loading = false);

    if (ok) {
      _oldPassCtrl.clear(); _newPassCtrl.clear(); _confirmPassCtrl.clear();
      setState(() => _successMsg = 'Kredensial berhasil diperbarui!');
    } else {
      setState(() => _errorMsg = auth.error ?? 'Password lama salah');
    }
  }

  void _saveBankEwallet() async {
    setState(() { _bankSuccessMsg = null; _bankErrorMsg = null; _savingBankEwallet = true; });
    final ok = await context.read<AuthProvider>().updateStoreBankAndEwallet(
      bankAccountNumber: _bankNumberCtrl.text.trim(),
      bankAccountName: _bankNameCtrl.text.trim(),
      bankName: _bankName ?? '',
      gopayNumber: _gopayCtrl.text.trim(),
      ovoNumber: _ovoCtrl.text.trim(),
      danaNumber: _danaCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _savingBankEwallet = false;
      if (ok) { _bankSuccessMsg = 'Rekening & e-wallet berhasil disimpan'; } else { _bankErrorMsg = 'Gagal menyimpan, coba lagi'; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Isi form rekening/e-wallet sekali dari data toko yang sedang login —
    // biar toko lama yang belum pernah isi juga langsung kelihatan datanya kalau sudah ada.
    if (!_bankFieldsLoaded && auth.currentStore != null) {
      _bankFieldsLoaded = true;
      _bankNumberCtrl.text = auth.currentStore!.bankAccountNumber;
      _bankNameCtrl.text = auth.currentStore!.bankAccountName;
      _bankName = auth.currentStore!.bankName.isNotEmpty ? auth.currentStore!.bankName : null;
      _gopayCtrl.text = auth.currentStore!.gopayNumber;
      _ovoCtrl.text = auth.currentStore!.ovoNumber;
      _danaCtrl.text = auth.currentStore!.danaNumber;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto Profil Admin
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  GestureDetector(
                    onTap: _savingProfilePhoto ? null : _pickProfilePhoto,
                    child: _savingProfilePhoto
                      ? const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 2))
                      : CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: (auth.currentUser?.photoUrl ?? '').isNotEmpty && File(auth.currentUser!.photoUrl).existsSync()
                            ? FileImage(File(auth.currentUser!.photoUrl)) : null,
                          child: (auth.currentUser?.photoUrl ?? '').isEmpty
                            ? Text(auth.currentUser?.name.isNotEmpty == true ? auth.currentUser!.name[0].toUpperCase() : 'A',
                                style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.bold))
                            : null,
                        ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(auth.currentUser?.name ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Text('Foto ini akan terlihat oleh member, kurir & superadmin', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ])),
                  TextButton(
                    onPressed: _savingProfilePhoto ? null : _pickProfilePhoto,
                    child: const Text('Ganti'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Info card
            Card(
              color: AppColors.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Keamanan Akun Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Login sebagai: ${auth.currentUser?.name ?? "Admin"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Form ubah kredensial
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconText(Icons.lock_outline, 'Ubah Username & Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Ganti username dan password login Admin', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username Baru', prefixIcon: Icon(Icons.person_outline), helperText: 'Username untuk login Admin'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _oldPassCtrl,
                    obscureText: _obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Password Lama (wajib diisi)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: 'Masukkan password saat ini untuk konfirmasi',
                      suffixIcon: IconButton(icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureOld = !_obscureOld)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Password Baru (opsional)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: 'Kosongkan jika tidak ingin ganti password',
                      suffixIcon: IconButton(icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureNew = !_obscureNew)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureNew,
                    decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru', prefixIcon: Icon(Icons.lock_outline)),
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ]),
                    ),
                  ],

                  if (_successMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_successMsg!, style: const TextStyle(color: AppColors.success, fontSize: 13))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),
                  LoadingButton(onPressed: _saveCredentials, isLoading: _loading, label: 'Simpan Perubahan'),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Rekening BRI & E-Wallet (dipakai buat tampilan Transfer Bank & E-Wallet di checkout customer)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconText(Icons.account_balance, 'Rekening & E-Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Ini yang ditampilkan ke customer saat mereka checkout pilih Transfer Bank BRI atau E-Wallet. Isi salah satu atau lebih e-wallet kalau toko punya.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _bankName,
                    decoration: const InputDecoration(labelText: 'Pilih Bank', prefixIcon: Icon(Icons.account_balance_outlined)),
                    items: indonesianBanks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _bankName = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _bankNumberCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No. Rekening', prefixIcon: Icon(Icons.numbers_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening', prefixIcon: Icon(Icons.badge_outlined))),
                  const SizedBox(height: 16),
                  TextField(controller: _gopayCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. GoPay', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: _ovoCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. OVO', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: _danaCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. DANA', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),

                  if (_bankErrorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_bankErrorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ]),
                    ),
                  ],
                  if (_bankSuccessMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_bankSuccessMsg!, style: const TextStyle(color: AppColors.success, fontSize: 13))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),
                  LoadingButton(onPressed: _saveBankEwallet, isLoading: _savingBankEwallet, label: 'Simpan Rekening & E-Wallet'),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Lokasi resto (untuk GPS 3 titik)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconText(Icons.location_on, 'Lokasi Resto', iconColor: Colors.red, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Dipakai untuk fitur GPS 3 titik (rute kurir: kurir → resto → customer)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (auth.currentStore?.hasLocation ?? false) ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(
                        (auth.currentStore?.hasLocation ?? false) ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: (auth.currentStore?.hasLocation ?? false) ? Colors.green : Colors.orange, size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        (auth.currentStore?.hasLocation ?? false)
                          ? 'Lokasi resto sudah ditandai di peta'
                          : 'Lokasi resto belum ditandai — kurir belum bisa lihat rute 3 titik ke resto ini',
                        style: TextStyle(fontSize: 12, color: (auth.currentStore?.hasLocation ?? false) ? Colors.green.shade800 : Colors.orange.shade800),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _savingLocation ? null : _pilihLokasiResto,
                    icon: _savingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.map_outlined),
                    label: Text((auth.currentStore?.hasLocation ?? false) ? 'Ubah Lokasi di Peta' : 'Tandai Lokasi di Peta'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Foto tampak depan toko (ditampilkan ke member/kurir/superadmin)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconText(Icons.storefront, 'Foto Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Foto tampak depan toko kamu. Ini yang muncul di halaman pesanan buat member, kurir, dan superadmin.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 14),
                  if ((auth.currentStore?.storefrontPhotoUrl ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(auth.currentStore!.storefrontPhotoUrl),
                        height: 160, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160, alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Gagal memuat foto', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'Belum ada foto toko — member/kurir/superadmin belum bisa lihat foto tokomu',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        )),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _savingStorefront ? null : _pickStorefrontImage,
                    icon: _savingStorefront
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.storefront_outlined),
                    label: Text((auth.currentStore?.storefrontPhotoUrl ?? '').isEmpty ? 'Upload Foto Toko' : 'Ganti Foto Toko'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Foto QRIS asli UMKM (dipakai saat customer checkout)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconText(Icons.photo_camera, 'QRIS Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Foto QRIS asli toko kamu (dari GoPay Merchant/DANA/Bank). Ini yang akan ditampilkan ke customer saat mereka checkout — pastikan sesuai rekening/e-wallet kamu sendiri.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 14),
                  if ((auth.currentStore?.qrisImageUrl ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(auth.currentStore!.qrisImageUrl),
                        height: 200, width: double.infinity, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200, alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Gagal memuat foto', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'Belum ada foto QRIS — customer akan lihat QR contoh (tidak bisa dipakai bayar sungguhan)',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        )),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _savingQris ? null : _pickQrisImage,
                    icon: _savingQris
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_outlined),
                    label: Text((auth.currentStore?.qrisImageUrl ?? '').isEmpty ? 'Upload Foto QRIS' : 'Ganti Foto QRIS'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Info default
            Card(
              color: Colors.orange.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text('Penting!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('• Jangan bagikan username/password Admin ke orang lain\n• Ganti password secara berkala untuk keamanan\n• Password default: admin123', style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.textSecondary)),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Logout
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Keluar', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { _usernameCtrl.dispose(); _oldPassCtrl.dispose(); _newPassCtrl.dispose(); _confirmPassCtrl.dispose(); _bankNumberCtrl.dispose(); _bankNameCtrl.dispose(); _gopayCtrl.dispose(); _ovoCtrl.dispose(); _danaCtrl.dispose(); super.dispose(); }
}
