// lib/utils/utils.dart
import 'package:intl/intl.dart';

String toRupiah(double value) {
  return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
}

String formatDate(int timestamp) {
  return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
}

bool isValidEmail(String email) => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
bool isValidPassword(String p) => p.length >= 6;
bool isValidPhone(String p) => p.length >= 10 && RegExp(r'^[0-9]+$').hasMatch(p);

// Sekarang kategori menu bisa teks bebas (diisi admin), bukan cuma enum tetap.
// Fungsi ini tetap menerjemahkan nilai enum lama ('MenuCategory.original' atau
// 'original') ke teks rapi untuk data lama, tapi kalau nilainya sudah teks
// bebas (kategori baru), langsung dipakai apa adanya.
String categoryLabel(dynamic cat) {
  final raw = cat?.toString() ?? '';
  switch (raw) {
    case 'MenuCategory.semua': case 'semua': return 'Semua';
    case 'MenuCategory.original': case 'original': return 'Original';
    case 'MenuCategory.extraPedas': case 'extraPedas': return 'Extra Pedas';
    case 'MenuCategory.seafood': case 'seafood': return 'Seafood';
    case 'MenuCategory.spesial': case 'spesial': return 'Spesial';
    case 'MenuCategory.minuman': case 'minuman': return 'Minuman';
    default: return raw.isEmpty ? 'Semua' : raw;
  }
}

String orderStatusLabel(dynamic status) {
  switch (status.toString()) {
    case 'OrderStatus.pending': return 'Menunggu Konfirmasi';
    case 'OrderStatus.processing': return 'Sedang Diproses';
    case 'OrderStatus.ready': return 'Siap Diantar';
    case 'OrderStatus.delivering': return 'Sedang Diantar';
    case 'OrderStatus.delivered': return 'Terkirim';
    case 'OrderStatus.done': return 'Selesai';
    case 'OrderStatus.cancelled': return 'Dibatalkan';
    default: return 'Unknown';
  }
}

