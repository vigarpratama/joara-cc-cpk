// lib/screens/member/cart_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Kosongkan Keranjang'),
                  content: const Text('Yakin ingin menghapus semua item?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                    ElevatedButton(onPressed: () { context.read<CartProvider>().clear(); Navigator.pop(context); }, child: const Text('Hapus')),
                  ],
                ),
              ),
              child: const Text('Hapus Semua', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: cart.isEmpty
        ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Keranjang Kosong', subtitle: 'Belum ada item di keranjang')
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (_, i) {
                    final item = cart.items[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 60, height: 60,
                                child: item.menu.imageUrl.isNotEmpty
                                  ? (item.menu.imageUrl.startsWith('/')
                                      ? Image.file(File(item.menu.imageUrl), fit: BoxFit.cover)
                                      : Image.network(item.menu.imageUrl, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: AppColors.primaryLight.withOpacity(0.1), child: const Icon(Icons.ramen_dining, color: AppColors.primaryLight, size: 32))))
                                  : Container(color: AppColors.primaryLight.withOpacity(0.1), child: const Icon(Icons.ramen_dining, color: AppColors.primaryLight, size: 32)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.menu.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (item.note.isNotEmpty) Text(item.note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(toRupiah(item.subtotal), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline, size: 22), onPressed: () => context.read<CartProvider>().updateQuantity(item, item.quantity - 1), color: AppColors.primary),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(icon: const Icon(Icons.add_circle_outline, size: 22), onPressed: () => context.read<CartProvider>().updateQuantity(item, item.quantity + 1), color: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))]),
                child: Column(
                  children: [
                    _row('Subtotal', toRupiah(cart.subtotal)),
                    const SizedBox(height: 6),
                    _row('Ongkos Kirim', cart.deliveryFee == 0 ? 'GRATIS' : toRupiah(cart.deliveryFee), valueColor: cart.deliveryFee == 0 ? AppColors.success : null, valueIcon: cart.deliveryFee == 0 ? Icons.celebration_outlined : null),
                    const Divider(height: 16),
                    _row('Total', toRupiah(cart.grandTotal), bold: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                        child: Text('Checkout - ${toRupiah(cart.grandTotal)}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? valueColor, IconData? valueIcon}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
      valueIcon != null
        ? IconText(valueIcon, value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 16 : 14, color: valueColor ?? (bold ? AppColors.primary : AppColors.textPrimary)))
        : Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 16 : 14, color: valueColor ?? (bold ? AppColors.primary : AppColors.textPrimary))),
    ],
  );
}
