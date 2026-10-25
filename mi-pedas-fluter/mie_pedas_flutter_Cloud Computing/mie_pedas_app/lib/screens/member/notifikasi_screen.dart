// lib/screens/member/notifikasi_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/notification_helper.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});
  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  bool _loading = true;
  bool _pesanan = true;
  bool _promo = true;
  bool _suara = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pesanan = await NotificationHelper.isCategoryEnabled('pesanan');
    final promo = await NotificationHelper.isCategoryEnabled('promo');
    final suara = await NotificationHelper.isSoundEnabled();
    setState(() {
      _pesanan = pesanan;
      _promo = promo;
      _suara = suara;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    if (key == 'notif_pesanan' || key == 'notif_promo') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } else {
      await NotificationHelper.setSoundEnabled(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('PENGATURAN', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
          title: const Text('Update Status Pesanan'),
          subtitle: const Text('Diproses, sedang diantar, sampai tujuan', style: TextStyle(fontSize: 12)),
          value: _pesanan,
          onChanged: (v) { setState(() => _pesanan = v); _set('notif_pesanan', v); },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
          title: const Text('Promo & Voucher'),
          subtitle: const Text('Info diskon dan penawaran spesial', style: TextStyle(fontSize: 12)),
          value: _promo,
          onChanged: (v) { setState(() => _promo = v); _set('notif_promo', v); },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined, color: AppColors.primary),
          title: const Text('Suara Notifikasi'),
          value: _suara,
          onChanged: (v) { setState(() => _suara = v); _set('notif_suara', v); },
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Matiin toggle di atas kalau kamu gak mau dapet notifikasi kategori tersebut. Pengaturan ini tersimpan di HP kamu.',
            style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 12),
          ),
        ),
      ]),
    );
  }
}
