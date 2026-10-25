// lib/screens/member/menu_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';
import 'detail_menu_screen.dart';

class MenuTab extends StatefulWidget {
  final String? initialQuery;
  const MenuTab({super.key, this.initialQuery});
  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  MenuCategory _selected = MenuCategory.semua;
  final _searchCtrl = TextEditingController();
  String _query = '';

  final _categories = [MenuCategory.semua, MenuCategory.original, MenuCategory.extraPedas, MenuCategory.seafood, MenuCategory.spesial, MenuCategory.minuman];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _query = widget.initialQuery!;
      _searchCtrl.text = _query;
    }
  }

  @override
  void didUpdateWidget(covariant MenuTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // MenuTab hidup terus di IndexedStack, jadi initState gak kepanggil ulang.
    // Sinkronin manual kalau initialQuery baru dikirim dari luar (misal dari banner).
    if (widget.initialQuery != null &&
        widget.initialQuery!.isNotEmpty &&
        widget.initialQuery != oldWidget.initialQuery) {
      setState(() {
        _query = widget.initialQuery!;
        _searchCtrl.text = _query;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menus = context.watch<MenuProvider>();
    final filtered = menus.filterMenus(category: _selected, query: _query);
    final cart = context.read<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari menu...', prefixIcon: const Icon(Icons.search), contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }) : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // Categories
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selected;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(categoryLabel(cat)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selected = cat),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('${filtered.length} menu', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ),
          // Grid
          Expanded(
            child: menus.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                ? const EmptyState(icon: Icons.search_off, title: 'Menu tidak ditemukan', subtitle: 'Coba kata kunci lain')
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      return MenuCard(
                        menu: m,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailMenuScreen(menu: m))),
                        onAddToCart: () {
                          cart.addItem(m);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.name} ditambahkan!'), duration: const Duration(seconds: 1), backgroundColor: AppColors.success));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }
}
