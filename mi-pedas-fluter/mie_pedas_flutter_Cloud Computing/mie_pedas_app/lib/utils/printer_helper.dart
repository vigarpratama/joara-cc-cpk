// lib/utils/printer_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class PrinterHelper {
  static const _channel = MethodChannel('mie_pedas_app/printer');

  // Format teks struk untuk thermal printer (58mm / 80mm)
  static String formatStruk(Order order, {String storeName = 'Mie Pedas Djora', String storeAddress = 'Jl. Mie Pedas No. 1', String storePhone = '08xxxxxxxxxx'}) {
    final line = '================================';
    final shortLine = '--------------------------------';
    final buf = StringBuffer();

    buf.writeln(line);
    buf.writeln(_center(storeName, 32));
    buf.writeln(_center(storeAddress, 32));
    buf.writeln(_center('Telp: $storePhone', 32));
    buf.writeln(line);
    buf.writeln('No: ${order.id}');
    buf.writeln('Tgl: ${formatDate(order.createdAt)}');
    buf.writeln('Pelanggan: ${order.memberName}');
    buf.writeln('Telp: ${order.memberPhone}');
    buf.writeln('Alamat: ${order.deliveryAddress}');
    buf.writeln(shortLine);
    buf.writeln(_center('DETAIL PESANAN', 32));
    buf.writeln(shortLine);

    for (final item in order.items) {
      buf.writeln(item.menuName);
      final qtyPrice = '${item.quantity} x ${toRupiah(item.price)}';
      final subtotal = toRupiah(item.subtotal);
      buf.writeln(_leftRight(qtyPrice, subtotal, 32));
      if (item.spicyLevel > 0) buf.writeln('  Level pedas: ${item.spicyLevel}');
      if (item.note.isNotEmpty) buf.writeln('  Catatan: ${item.note}');
    }

    buf.writeln(shortLine);
    buf.writeln(_leftRight('Subtotal', toRupiah(order.subtotal), 32));
    buf.writeln(_leftRight('Ongkir', order.deliveryFee == 0 ? 'GRATIS' : toRupiah(order.deliveryFee), 32));
    if (order.discount > 0) buf.writeln(_leftRight('Diskon', '-${toRupiah(order.discount)}', 32));
    buf.writeln(line);
    buf.writeln(_leftRight('TOTAL', toRupiah(order.totalAmount), 32));
    buf.writeln(line);
    buf.writeln(_leftRight('Pembayaran', _paymentLabel(order.paymentMethod), 32));
    buf.writeln(shortLine);
    buf.writeln(_center('Terima kasih!', 32));
    buf.writeln(_center('Selamat menikmati 🌶️', 32));
    buf.writeln(line);
    buf.writeln('');
    buf.writeln('');

    return buf.toString();
  }

  static String _center(String text, int width) {
    if (text.length >= width) return text;
    final pad = (width - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  static String _leftRight(String left, String right, int width) {
    final space = width - left.length - right.length;
    if (space <= 0) return '$left $right';
    return left + ' ' * space + right;
  }

  static String _paymentLabel(PaymentMethod p) => switch (p) {
    PaymentMethod.cash => 'Tunai (COD)',
    PaymentMethod.transfer => 'Transfer Bank',
    PaymentMethod.ewallet => 'E-Wallet',
    PaymentMethod.qris => 'QRIS',
  };

  // Kirim ke printer via Bluetooth (method channel ke native Android)
  static Future<bool> printViBluetooth(String text) async {
    try {
      final result = await _channel.invokeMethod('printStruk', {'text': text});
      return result == true;
    } catch (e) {
      debugPrint('Print error: $e');
      return false;
    }
  }
}
