// lib/screens/member/tentang_aplikasi_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';

class TentangAplikasiScreen extends StatelessWidget {
  const TentangAplikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(child: Column(children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.ramen_dining, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Joara Delivery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Versi 1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])),
        const SizedBox(height: 24),
        const Text(
          'Joara Delivery adalah platform pemesanan makanan yang menghubungkan pelanggan langsung dengan UMKM kuliner lokal, lengkap dengan pelacakan pesanan real-time dan estimasi ongkos kirim otomatis berdasarkan jarak.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Divider(),
        _infoTile(Icons.code, 'Dikembangkan oleh', 'Tim Joara Delivery'),
        _infoTile(Icons.map_outlined, 'Peta & Rute', 'OpenStreetMap & OSRM'),
        _infoTile(Icons.privacy_tip_outlined, 'Kebijakan Privasi', 'Lihat selengkapnya', onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kebijakan privasi belum tersedia')));
        }),
        const SizedBox(height: 12),
        Center(child: Text('© 2026 Joara Delivery. All rights reserved.', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 11))),
      ]),
    );
  }

  Widget _infoTile(IconData icon, String title, String value, {VoidCallback? onTap}) => ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title, style: const TextStyle(fontSize: 13)),
    subtitle: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18, color: AppColors.divider) : null,
    onTap: onTap,
  );
}
