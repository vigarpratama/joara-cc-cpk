// lib/screens/member/profile_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../auth/login_screen.dart';
import 'alamat_pengiriman_screen.dart';
import 'notifikasi_screen.dart';
import 'bantuan_faq_screen.dart';
import 'tentang_aplikasi_screen.dart';
import '../../widgets/widgets.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickPhoto() async {
    final hasPhoto = (context.read<AuthProvider>().currentUser?.photoUrl ?? '').isNotEmpty;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
            const Text('Ganti Foto Profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt, color: AppColors.primary)),
              title: const Text('Ambil Foto'),
              onTap: () async { Navigator.pop(context); await _getImage(ImageSource.camera); },
            ),
            ListTile(
              leading: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library, color: Colors.blue)),
              title: const Text('Pilih dari Galeri'),
              onTap: () async { Navigator.pop(context); await _getImage(ImageSource.gallery); },
            ),
            if (hasPhoto) ListTile(
              leading: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete_outline, color: AppColors.error)),
              title: const Text('Hapus Foto', style: TextStyle(color: AppColors.error)),
              onTap: () async { Navigator.pop(context); await _removePhoto(); },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    setState(() => _isUploading = true);
    try {
      final img = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (img != null && mounted) {
        await context.read<AuthProvider>().updateProfilePhoto(img.path);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: IconText(Icons.check_circle, 'Foto profil berhasil diperbarui!'), backgroundColor: AppColors.success));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _removePhoto() async {
    await context.read<AuthProvider>().updateProfilePhoto('');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil dihapus')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: SingleChildScrollView(
        child: Column(children: [
          // Header dengan foto profil
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            color: AppColors.primary,
            child: Column(children: [
              Stack(alignment: Alignment.center, children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: _isUploading
                    ? Container(width: 90, height: 90,
                        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white24,
                        backgroundImage: (user?.photoUrl ?? '').isNotEmpty && File(user!.photoUrl).existsSync()
                          ? FileImage(File(user.photoUrl)) : null,
                        child: (user?.photoUrl ?? '').isEmpty
                          ? Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))
                          : null,
                      ),
                ),
                Positioned(bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                      child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 16),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(user?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          _tile(Icons.photo_camera, 'Ganti Foto Profil', () => _pickPhoto()),
          _tile(Icons.person_outline, 'Edit Profil', () => _editProfile(context)),
          _tile(Icons.location_on_outlined, 'Alamat Pengiriman', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlamatPengirimanScreen()))),
          _tile(Icons.notifications_outlined, 'Notifikasi', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotifikasiScreen()))),
          _tile(Icons.help_outline, 'Bantuan & FAQ', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BantuanFaqScreen()))),
          _tile(Icons.info_outline, 'Tentang Aplikasi', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TentangAplikasiScreen()))),
          const Divider(),
          _tile(Icons.logout, 'Keluar', () => _logout(context), color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Joara Delivery v1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color}) =>
    ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.divider),
      onTap: onTap,
    );

  void _editProfile(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final addressCtrl = TextEditingController(text: user.address);

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Edit Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telepon'),
            keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat'), maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              await auth.updateProfile(nameCtrl.text, phoneCtrl.text, addressCtrl.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          )),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Keluar'),
      content: const Text('Yakin ingin keluar dari akun?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await context.read<AuthProvider>().logout();
            if (context.mounted) Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Keluar'),
        ),
      ],
    ));
  }
}
