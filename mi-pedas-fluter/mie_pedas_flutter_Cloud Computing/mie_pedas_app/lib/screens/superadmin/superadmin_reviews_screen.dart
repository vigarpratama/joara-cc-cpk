// lib/screens/superadmin/superadmin_reviews_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/database_helper.dart';
import '../../widgets/widgets.dart';

class SuperAdminReviewsScreen extends StatefulWidget {
  const SuperAdminReviewsScreen({super.key});
  @override
  State<SuperAdminReviewsScreen> createState() => _SuperAdminReviewsScreenState();
}

class _SuperAdminReviewsScreenState extends State<SuperAdminReviewsScreen> {
  bool _showStores = true; // true = tab Resto, false = tab Kurir
  List<User> _kurirList = [];
  Map<String, double> _avgRatings = {};
  Map<String, int> _reviewCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final allUsers = await DatabaseHelper().getAllUsers();
    _kurirList = allUsers.where((u) => u.role == UserRole.kurir).toList();

    final stores = context.read<StoreProvider>().stores;
    final targetIds = _showStores ? stores.map((s) => s.id) : _kurirList.map((k) => k.id);

    final avg = <String, double>{};
    final count = <String, int>{};
    for (final id in targetIds) {
      final reviews = await DatabaseHelper().getReviewsByTarget(id);
      count[id] = reviews.length;
      avg[id] = reviews.isEmpty ? 0.0 : reviews.fold(0.0, (s, r) => s + r.rating) / reviews.length;
    }
    setState(() { _avgRatings = avg; _reviewCounts = count; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<StoreProvider>().stores;
    final list = _showStores ? stores.map((s) => (id: s.id, name: s.name, subtitle: s.ownerName, photoUrl: s.storefrontPhotoUrl)).toList()
                              : _kurirList.map((k) => (id: k.id, name: k.name, subtitle: k.phone, photoUrl: k.photoUrl)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ulasan Resto & Driver')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _tabChip('Resto', Icons.storefront, true)),
            const SizedBox(width: 10),
            Expanded(child: _tabChip('Kurir', Icons.two_wheeler, false)),
          ]),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
              ? Center(child: Text(_showStores ? 'Belum ada resto terdaftar' : 'Belum ada kurir terdaftar', style: const TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final item = list[i];
                      final avg = _avgRatings[item.id] ?? 0.0;
                      final count = _reviewCounts[item.id] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: item.photoUrl.isNotEmpty
                            ? CircleAvatar(
                                backgroundColor: (_showStores ? const Color(0xFF6A1B9A) : AppColors.primary).withOpacity(0.1),
                                backgroundImage: FileImage(File(item.photoUrl)),
                                onBackgroundImageError: (_, __) {},
                              )
                            : CircleAvatar(
                                backgroundColor: (_showStores ? const Color(0xFF6A1B9A) : AppColors.primary).withOpacity(0.1),
                                child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?', style: TextStyle(color: _showStores ? const Color(0xFF6A1B9A) : AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item.subtitle.isEmpty ? '-' : item.subtitle, style: const TextStyle(fontSize: 12)),
                          trailing: count == 0
                            ? const Text('Belum ada ulasan', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 2),
                                  Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ]),
                                Text('$count ulasan', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                              ]),
                          onTap: () => _showReviewsSheet(context, item.id, item.name),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _tabChip(String label, IconData icon, bool isStoreTab) {
    final selected = _showStores == isStoreTab;
    return GestureDetector(
      onTap: () { setState(() => _showStores = isStoreTab); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6A1B9A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF6A1B9A) : AppColors.divider),
        ),
        child: IconText(icon, label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textPrimary, fontSize: 13)),
      ),
    );
  }

  void _showReviewsSheet(BuildContext context, String targetId, String targetName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => FutureBuilder(
          future: DatabaseHelper().getReviewsByTarget(targetId),
          builder: (context, snapshot) {
            final reviews = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                IconText(Icons.star, 'Ulasan $targetName', iconColor: Colors.amber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Divider(),
                if (!snapshot.hasData)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (reviews.isEmpty)
                  const Expanded(child: Center(child: Text('Belum ada ulasan', style: TextStyle(color: AppColors.textSecondary))))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: reviews.length,
                      itemBuilder: (_, i) {
                        final r = reviews[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(r.memberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Text(formatDate(r.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 16))),
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r.comment, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                            const Divider(height: 20),
                          ]),
                        );
                      },
                    ),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
