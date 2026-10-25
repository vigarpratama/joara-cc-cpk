// lib/screens/member/bantuan_faq_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';

class BantuanFaqScreen extends StatelessWidget {
  const BantuanFaqScreen({super.key});

  static const _faqs = [
    ('Bagaimana cara memesan?', 'Pilih menu di tab Menu, tambahkan ke keranjang, lalu lanjut ke checkout dan pilih metode pembayaran.'),
    ('Berapa lama pesanan sampai?', 'Estimasi waktu antar tergantung jarak dan kondisi lalu lintas, biasanya 20-45 menit setelah pesanan diproses.'),
    ('Bagaimana cara menghitung ongkos kirim?', 'Ongkir dihitung otomatis berdasarkan jarak antara toko dan alamat pengiriman kamu (Rp 2.300/km, minimum Rp 2.300).'),
    ('Bisakah membatalkan pesanan?', 'Pesanan bisa dibatalkan selama masih berstatus "Menunggu Konfirmasi". Setelah diproses toko, pembatalan perlu hubungi toko langsung.'),
    ('Metode pembayaran apa saja yang tersedia?', 'Tersedia Bayar Tunai (COD), Transfer Bank, E-Wallet, dan QRIS.'),
    ('Bagaimana cara melacak pesanan?', 'Buka tab Pesanan, pilih pesanan aktif, kamu bisa lihat status secara real-time di halaman Lacak Pesanan.'),
  ];

  Future<void> _openWhatsapp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/6281234567890?text=${Uri.encodeComponent("Halo, saya butuh bantuan seputar Joara Delivery")}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka WhatsApp: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan & FAQ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.support_agent, color: AppColors.primary, size: 32),
            const SizedBox(width: 12),
            const Expanded(child: Text('Butuh bantuan langsung? Hubungi tim support kami via WhatsApp.', style: TextStyle(fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openWhatsapp(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            icon: const Icon(Icons.chat),
            label: const Text('Chat via WhatsApp'),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Pertanyaan Umum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ..._faqs.map((f) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(f.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))],
          ),
        )),
      ]),
    );
  }
}
