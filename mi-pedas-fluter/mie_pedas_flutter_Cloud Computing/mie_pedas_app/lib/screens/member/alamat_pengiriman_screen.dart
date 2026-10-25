// lib/screens/member/alamat_pengiriman_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class AlamatPengirimanScreen extends StatefulWidget {
  const AlamatPengirimanScreen({super.key});
  @override
  State<AlamatPengirimanScreen> createState() => _AlamatPengirimanScreenState();
}

class _AlamatPengirimanScreenState extends State<AlamatPengirimanScreen> {
  late final TextEditingController _addressCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _addressCtrl = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat gak boleh kosong'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    await auth.updateProfile(user.name, user.phone, _addressCtrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: IconText(Icons.check_circle, 'Alamat pengiriman disimpan'), backgroundColor: AppColors.success));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Pengiriman')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Alamat ini dipakai sebagai default saat kamu checkout, dan buat fitur "Navigasi ke Rumahku" di Beranda.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Alamat Lengkap',
              hintText: 'Nama jalan, nomor rumah, kecamatan, kota...',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan Alamat'),
            ),
          ),
        ]),
      ),
    );
  }
}
