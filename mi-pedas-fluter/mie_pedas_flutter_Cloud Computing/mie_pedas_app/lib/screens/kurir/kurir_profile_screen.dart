// lib/screens/kurir/kurir_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../auth/login_screen.dart';
import '../../widgets/widgets.dart';

class KurirProfileScreen extends StatefulWidget {
  final bool isOnline;
  final bool soundEnabled;
  final Function(bool) onToggleOnline;
  final Function(bool) onToggleSound;

  const KurirProfileScreen({
    super.key,
    required this.isOnline,
    required this.soundEnabled,
    required this.onToggleOnline,
    required this.onToggleSound,
  });

  @override
  State<KurirProfileScreen> createState() => _KurirProfileScreenState();
}

class _KurirProfileScreenState extends State<KurirProfileScreen> {
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
              title: const Text('Ambil Foto'), subtitle: const Text('Gunakan kamera'),
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
    final user = context.watch<AuthProvider>().currentUser;
    final hasPhoto = (user?.photoUrl ?? '').isNotEmpty && File(user!.photoUrl).existsSync();
    return SingleChildScrollView(
      child: Column(children: [
        // Header dengan foto profil
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(children: [
            // Foto profil
            Stack(alignment: Alignment.center, children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: _isUploading
                  ? Container(width: 100, height: 100,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      backgroundImage: hasPhoto ? FileImage(File(user!.photoUrl)) : null,
                      child: !hasPhoto
                        ? Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                    ),
              ),
              Positioned(bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]),
                    child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 18),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(user?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            // Status online
            GestureDetector(
              onTap: () => widget.onToggleOnline(!widget.isOnline),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isOnline ? AppColors.success : Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: widget.isOnline ? Colors.white : Colors.white54,
                      shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(widget.isOnline ? 'Online — Siap Bertugas' : 'Offline',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Ganti foto
            Card(
              child: ListTile(
                leading: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: hasPhoto
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(user!.photoUrl), fit: BoxFit.cover))
                    : const Icon(Icons.photo_camera, color: AppColors.primary)),
                title: const Text('Foto Profil', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(hasPhoto ? 'Tap untuk mengganti foto' : 'Belum ada foto — tap untuk menambah'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                onTap: _pickPhoto,
              ),
            ),
            const SizedBox(height: 8),

            // Toggle Online
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Status Ketersediaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(widget.isOnline ? 'Siap menerima pesanan' : 'Tidak menerima pesanan',
                        style: TextStyle(fontSize: 12, color: widget.isOnline ? AppColors.success : AppColors.textSecondary)),
                    ]),
                    Switch(value: widget.isOnline, onChanged: widget.onToggleOnline,
                      activeColor: Colors.white, activeTrackColor: AppColors.success),
                  ]),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isOnline ? AppColors.success : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12)),
                    child: IconText(widget.isOnline ? Icons.check_circle : Icons.pause_circle_outline, widget.isOnline ? 'ONLINE — Siap Bertugas!' : 'OFFLINE — Istirahat',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),

            // Toggle Suara
            Card(
              child: ListTile(
                leading: Icon(widget.soundEnabled ? Icons.volume_up : Icons.volume_off, color: AppColors.primary),
                title: const Text('Notifikasi Suara'),
                subtitle: Text(widget.soundEnabled ? 'Aktif' : 'Dimatikan'),
                trailing: Switch(value: widget.soundEnabled, activeColor: AppColors.primary,
                  onChanged: widget.onToggleSound),
              ),
            ),
            const SizedBox(height: 8),

            // Info akun
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconText(Icons.assignment_outlined, 'Informasi Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  _infoRow(Icons.person_outline, 'Nama', user?.name ?? '-'),
                  _infoRow(Icons.email_outlined, 'Email', user?.email ?? '-'),
                  _infoRow(Icons.phone_outlined, 'Telepon', user?.phone.isEmpty == true ? '-' : (user?.phone ?? '-')),
                  _infoRow(Icons.work_outline, 'Role', 'Kurir'),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.onToggleOnline(false);
                  if (context.mounted) {
                    await context.read<AuthProvider>().logout();
                    Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                  }
                },
                icon: const Icon(Icons.logout), label: const Text('Keluar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
