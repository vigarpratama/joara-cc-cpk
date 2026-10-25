// lib/screens/member/detail_menu_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import '../../widgets/widgets.dart';

class DetailMenuScreen extends StatefulWidget {
  final Menu menu;
  const DetailMenuScreen({super.key, required this.menu});
  @override
  State<DetailMenuScreen> createState() => _DetailMenuScreenState();
}

class _DetailMenuScreenState extends State<DetailMenuScreen> {
  int _qty = 1;
  int _spicyLevel = 1;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _spicyLevel = widget.menu.spicyLevel > 0 ? widget.menu.spicyLevel : 1;
  }

  void _addToCart() {
    final cart = context.read<CartProvider>();
    final currentStoreId = widget.menu.storeId;
    if (cart.items.isNotEmpty && cart.items.first.menu.storeId != currentStoreId) {
      _confirmSwitchStore();
      return;
    }
    cart.addItem(widget.menu, quantity: _qty, spicyLevel: _spicyLevel, note: _noteCtrl.text);
    _showAddedSheet();
  }

  // Dipanggil kalau keranjang masih berisi menu dari UMKM LAIN — satu pesanan
  // gak boleh campur menu dari 2 UMKM berbeda, jadi user harus konfirmasi dulu
  // sebelum keranjang lama dikosongkan.
  void _confirmSwitchStore() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Keranjang?'),
        content: const Text(
          'Keranjang kamu masih berisi menu dari UMKM lain. Satu pesanan tidak bisa berisi menu dari 2 UMKM berbeda.\n\n'
          'Kosongkan keranjang dan tambahkan menu ini?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CartProvider>().clear();
              context.read<CartProvider>().addItem(
                widget.menu, quantity: _qty, spicyLevel: _spicyLevel, note: _noteCtrl.text,
              );
              _showAddedSheet();
            },
            child: const Text('Ganti Keranjang'),
          ),
        ],
      ),
    );
  }

  void _showAddedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          const SizedBox(height: 12),
          Text('${widget.menu.name} ditambahkan ke keranjang!',
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lanjut Belanja'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
              },
              child: const Text('Lihat Keranjang'),
            )),
          ]),
        ]),
      ),
    );
  }

  void _buyNow() {
    // Langsung checkout dengan 1 item ini saja
    final cart = context.read<CartProvider>();
    // Simpan isi cart lama
    final oldItems = List.of(cart.items);
    cart.clear();
    cart.addItem(widget.menu, quantity: _qty, spicyLevel: _spicyLevel, note: _noteCtrl.text);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(onCheckoutDone: () {
        // Kalau checkout selesai, restore cart lama
        for (final item in oldItems) {
          cart.addItem(item.menu, quantity: item.quantity, spicyLevel: item.spicyLevel, note: item.note);
        }
      })),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.menu;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: m.imageUrl.isNotEmpty
                ? Image.file(
                    File(m.imageUrl), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      child: const Icon(Icons.ramen_dining, size: 100, color: AppColors.primaryLight),
                    ),
                  )
                : Container(
                    color: AppColors.primaryLight.withOpacity(0.15),
                    child: const Icon(Icons.ramen_dining, size: 100, color: AppColors.primaryLight),
                  ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Nama & Harga
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  Text(toRupiah(m.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('${m.rating} (${m.totalReviews} ulasan)', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  if (m.isBestSeller) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Best Seller', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (m.stock <= 0 ? AppColors.error : (m.stock <= 5 ? Colors.orange : AppColors.success)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    m.stock <= 0 ? 'Stok Habis' : 'Sisa ${m.stock}',
                    style: TextStyle(
                      color: m.stock <= 0 ? AppColors.error : (m.stock <= 5 ? Colors.orange : AppColors.success),
                      fontSize: 12, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(m.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),

                // ===== LEVEL KEPEDASAN (DROPDOWN) =====
                if (m.spicyLevel > 0) ...[
                  const SizedBox(height: 20),
                  const Text('Tingkat Kepedasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _spicyLevel,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        borderRadius: BorderRadius.circular(12),
                        items: List.generate(5, (i) {
                          final level = i + 1;
                          final labels = ['Tidak Pedas', 'Sedikit Pedas', 'Pedas Sedang', 'Pedas', 'Sangat Pedas'];
                          return DropdownMenuItem(
                            value: level,
                            child: Row(children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Level $level', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(labels[i], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ]),
                            ]),
                          );
                        }),
                        onChanged: (v) => setState(() => _spicyLevel = v!),
                      ),
                    ),
                  ),
                ],

                // ===== JUMLAH =====
                const SizedBox(height: 20),
                const Text('Jumlah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(children: [
                  // Tombol kurang
                  GestureDetector(
                    onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _qty > 1 ? AppColors.primary.withOpacity(0.1) : AppColors.divider,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _qty > 1 ? AppColors.primary : AppColors.divider),
                      ),
                      child: Icon(Icons.remove, color: _qty > 1 ? AppColors.primary : AppColors.textSecondary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('$_qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  // Tombol tambah
                  GestureDetector(
                    onTap: (m.stock > 0 && _qty < m.stock) ? () => setState(() => _qty++) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: (m.stock > 0 && _qty < m.stock) ? AppColors.primary : AppColors.divider,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add, color: (m.stock > 0 && _qty < m.stock) ? Colors.white : AppColors.textSecondary, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(toRupiah(m.price * _qty),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                  ]),
                ]),

                // ===== CATATAN =====
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'Contoh: tidak pakai MSG, tambah kerupuk...',
                    prefixIcon: const Icon(Icons.note_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),

                // ===== TOMBOL AKSI =====
                const SizedBox(height: 24),

                // Beli Langsung (kalau qty = 1, tampil lebih menonjol)
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: m.stock > 0 ? _buyNow : null,
                    icon: Icon(m.stock > 0 ? Icons.flash_on_rounded : Icons.block),
                    label: Text(m.stock > 0 ? 'Beli Langsung — ${toRupiah(m.price * _qty)}' : 'Stok Habis',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.divider,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tambah ke Keranjang
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton.icon(
                    onPressed: m.stock > 0 ? _addToCart : null,
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: Text(m.stock > 0 ? 'Tambah ke Keranjang' : 'Stok Habis',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: m.stock > 0 ? AppColors.primary : AppColors.divider, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                // Info tip
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Mau beli banyak menu? Tambahkan ke keranjang dulu, lalu checkout sekaligus.',
                      style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.4),
                    )),
                  ]),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }
}
