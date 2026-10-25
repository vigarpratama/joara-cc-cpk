// lib/screens/superadmin/superadmin_stores.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class SuperAdminStores extends StatefulWidget {
  const SuperAdminStores({super.key});
  @override
  State<SuperAdminStores> createState() => _SuperAdminStoresState();
}

class _SuperAdminStoresState extends State<SuperAdminStores> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StoreProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola UMKM'),
        backgroundColor: const Color(0xFF6A1B9A),
        bottom: TabBar(controller: _tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
          tabs: [Tab(text: 'Semua (${sp.stores.length})'), Tab(text: 'Aktif (${sp.activeStores.length})'), Tab(text: 'Pending (${sp.pendingStores.length})')]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'superadmin_stores_fab',
        onPressed: () => _showAddStoreDialog(context),
        backgroundColor: const Color(0xFF6A1B9A),
        icon: const Icon(Icons.add),
        label: const Text('Tambah UMKM'),
      ),
      body: TabBarView(controller: _tab, children: [
        _buildList(context, sp.stores),
        _buildList(context, sp.activeStores),
        _buildList(context, sp.pendingStores),
      ]),
    );
  }

  Widget _buildList(BuildContext context, List<Store> stores) {
    if (stores.isEmpty) return const EmptyState(icon: Icons.store_outlined, title: 'Belum ada UMKM');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stores.length,
      itemBuilder: (_, i) {
        final s = stores[i];
        final statusColor = switch (s.status) { StoreStatus.active => Colors.green, StoreStatus.suspended => AppColors.error, StoreStatus.pending => Colors.orange };
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              s.storefrontPhotoUrl.isNotEmpty
                ? CircleAvatar(
                    backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                    backgroundImage: FileImage(File(s.storefrontPhotoUrl)),
                    onBackgroundImageError: (_, __) {},
                  )
                : CircleAvatar(backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1), child: Text(s.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Pemilik: ${s.ownerName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(s.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            IconText(Icons.location_on, '${s.address}', iconColor: Colors.red, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            IconText(Icons.phone_android, '${s.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            IconText(Icons.person_outline, 'Admin: ${s.adminUsername}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            IconText(Icons.calendar_today, 'Bergabung: ${formatDate(s.createdAt).split(',').first}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Divider(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (s.status == StoreStatus.pending) ...[
                TextButton(onPressed: () => context.read<StoreProvider>().activateStore(s.id), child: const IconText(Icons.check_circle, 'Approve', iconColor: Colors.green, style: TextStyle(color: Colors.green))),
                TextButton(onPressed: () => context.read<StoreProvider>().suspendStore(s.id), child: const IconText(Icons.cancel, 'Tolak', iconColor: Colors.red, style: TextStyle(color: AppColors.error))),
              ],
              if (s.status == StoreStatus.active)
                TextButton(onPressed: () => context.read<StoreProvider>().suspendStore(s.id), child: const IconText(Icons.block, 'Suspend', iconColor: Colors.red, style: TextStyle(color: AppColors.error))),
              if (s.status == StoreStatus.suspended) ...[
                TextButton(onPressed: () => context.read<StoreProvider>().activateStore(s.id), child: const IconText(Icons.check_circle, 'Aktifkan', iconColor: Colors.green, style: TextStyle(color: Colors.green))),
                TextButton(onPressed: () => _confirmDelete(context, s), child: const IconText(Icons.delete_outline, 'Hapus Permanen', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
              ],
            ]),
          ])),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Store s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Hapus Permanen'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Yakin ingin menghapus "${s.name}" secara PERMANEN?'),
          const SizedBox(height: 10),
          const Text('Tindakan ini tidak bisa dibatalkan. Semua menu, voucher, dan akun admin milik resto ini akan ikut terhapus.\n\nRiwayat pesanan tetap disimpan untuk keperluan laporan.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await context.read<StoreProvider>().deleteStore(s.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${s.name}" berhasil dihapus'), backgroundColor: AppColors.success));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }

  void _showAddStoreDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconText(Icons.add_circle_outline, 'Tambah UMKM Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Toko/UMKM')),
          const SizedBox(height: 10),
          TextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Nama Pemilik')),
          const SizedBox(height: 10),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Admin'), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 10),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nomor Telepon'), keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat Toko'), maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username Admin'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password Admin'))),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty) return;
                final store = Store(
                  id: 'store_${const Uuid().v4().substring(0, 8)}',
                  name: nameCtrl.text, ownerName: ownerCtrl.text,
                  adminEmail: emailCtrl.text, phone: phoneCtrl.text,
                  address: addressCtrl.text, adminUsername: userCtrl.text,
                  adminPassword: passCtrl.text.isEmpty ? 'admin123' : passCtrl.text,
                  status: StoreStatus.active,
                );
                await ctx.read<StoreProvider>().addStore(store);
                if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('UMKM "${store.name}" berhasil ditambahkan!'), backgroundColor: AppColors.success)); }
              },
              child: const Text('Tambah UMKM'),
            ),
          ),
          const SizedBox(height: 24),
        ])),
      ),
    );
  }
}
