// lib/screens/admin/admin_menu_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class AdminMenuTab extends StatelessWidget {
  const AdminMenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = context.watch<MenuProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Menu')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_menu_fab',
        onPressed: () => _showMenuForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Menu'),
      ),
      body: menus.isLoading
        ? const Center(child: CircularProgressIndicator())
        : menus.menus.isEmpty
          ? const EmptyState(icon: Icons.restaurant_menu_outlined, title: 'Belum ada menu')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: menus.menus.length,
              itemBuilder: (_, i) {
                final m = menus.menus[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: m.imageUrl.isNotEmpty
                        ? (m.imageUrl.startsWith('/')
                            ? Image.file(File(m.imageUrl), width: 48, height: 48, fit: BoxFit.cover)
                            : Image.network(m.imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: AppColors.primaryLight.withOpacity(0.1), child: const Icon(Icons.ramen_dining, color: AppColors.primaryLight))))
                        : Container(width: 48, height: 48, color: AppColors.primaryLight.withOpacity(0.1), child: const Icon(Icons.ramen_dining, color: AppColors.primaryLight)),
                    ),
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${toRupiah(m.price)} • Stok: ${m.stock}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showMenuForm(context, m)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => _confirmDelete(context, m)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, Menu m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Menu'),
        content: Text('Yakin hapus "${m.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () { context.read<MenuProvider>().deleteMenu(m.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showMenuForm(BuildContext context, Menu? existing) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final descCtrl = TextEditingController(text: existing?.description);
    final priceCtrl = TextEditingController(text: existing?.price.toInt().toString());
    final stockCtrl = TextEditingController(text: existing?.stock.toString());
    var category = existing?.category ?? 'Original';
    var spicyLevel = existing?.spicyLevel ?? 1;
    var isBestSeller = existing?.isBestSeller ?? false;
    var isNew = existing?.isNew ?? false;
    String imageUrl = existing?.imageUrl ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Tambah Menu' : 'Edit Menu', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Foto Menu
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (picked != null) setS(() => imageUrl = picked.path);
                  },
                  child: Container(
                    width: double.infinity, height: 160,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageUrl.startsWith('/')
                            ? Image.file(File(imageUrl), fit: BoxFit.cover, width: double.infinity)
                            : Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                        )
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap untuk pilih foto', style: TextStyle(color: Colors.grey)),
                        ]),
                  ),
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => setS(() => imageUrl = ''),
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    label: const Text('Hapus foto', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 10),

                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Menu')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 2),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Harga (Rp)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stok'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  // Saran kategori dari menu yang sudah ada, biar admin nggak perlu ketik
                  // ulang dari nol tiap kali (tapi tetap bebas ketik nama baru).
                  final existingCategories = context.read<MenuProvider>().menus
                      .map((m) => m.category)
                      .where((c) => c.trim().isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
                  return Autocomplete<String>(
                    initialValue: TextEditingValue(text: category),
                    optionsBuilder: (v) {
                      if (v.text.isEmpty) return existingCategories;
                      return existingCategories.where((c) => c.toLowerCase().contains(v.text.toLowerCase()));
                    },
                    onSelected: (v) => setS(() => category = v),
                    fieldViewBuilder: (fCtx, ctrl, focusNode, onSubmit) {
                      // Sinkronkan input bebas ke state 'category', tidak hanya saat pilih dari saran
                      ctrl.addListener(() => category = ctrl.text);
                      return TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Kategori', hintText: 'Ketik kategori bebas, misal: Cemilan', prefixIcon: Icon(Icons.label_outline)),
                      );
                    },
                  );
                }),
                const SizedBox(height: 10),
                const Text('Tingkat Pedas', style: TextStyle(fontWeight: FontWeight.w500)),
                Slider(value: spicyLevel.toDouble(), min: 0, max: 5, divisions: 5, label: spicyLevel == 0 ? 'Tidak Pedas' : 'Level $spicyLevel', onChanged: (v) => setS(() => spicyLevel = v.toInt()), activeColor: AppColors.spicy),
                Row(children: [
                  Checkbox(value: isBestSeller, onChanged: (v) => setS(() => isBestSeller = v!)),
                  const Text('Best Seller'),
                  const SizedBox(width: 16),
                  Checkbox(value: isNew, onChanged: (v) => setS(() => isNew = v!)),
                  const Text('Menu Baru'),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      final storeId = ctx.read<AuthProvider>().currentStoreId;
                      final menu = Menu(
                        id: existing?.id ?? const Uuid().v4(),
                        storeId: existing?.storeId ?? storeId,
                        name: nameCtrl.text, description: descCtrl.text,
                        price: double.tryParse(priceCtrl.text) ?? 0,
                        stock: int.tryParse(stockCtrl.text) ?? 0,
                        category: category.trim().isEmpty ? 'Original' : category.trim(), spicyLevel: spicyLevel,
                        isBestSeller: isBestSeller, isNew: isNew,
                        imageUrl: imageUrl,
                        rating: existing?.rating ?? 0, totalReviews: existing?.totalReviews ?? 0,
                      );
                      if (existing == null) {
                        await ctx.read<MenuProvider>().addMenu(menu);
                      } else {
                        await ctx.read<MenuProvider>().updateMenu(menu);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Tambah' : 'Simpan'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
