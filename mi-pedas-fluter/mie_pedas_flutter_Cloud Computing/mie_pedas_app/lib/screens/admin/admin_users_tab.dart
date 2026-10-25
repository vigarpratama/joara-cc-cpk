// lib/screens/admin/admin_users_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/database_helper.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});
  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> with SingleTickerProviderStateMixin {
  List<User> _users = [];
  bool _loading = true;
  late TabController _tabCtrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _users = await DatabaseHelper().getAllUsers();
    setState(() => _loading = false);
  }

  List<User> _filtered(UserRole role) {
    var list = _users.where((u) => u.role == role).toList();
    // Khusus tab Admin: cuma nampilin admin TOKO INI, bukan admin toko lain
    // (member & kurir memang lintas-toko jadi gak difilter storeId).
    if (role == UserRole.admin) {
      final myStoreId = context.read<AuthProvider>().currentStoreId;
      list = list.where((u) => u.storeId == myStoreId).toList();
    }
    return list.where((u) =>
      u.name.toLowerCase().contains(_search.toLowerCase()) ||
      u.email.toLowerCase().contains(_search.toLowerCase()) ||
      u.phone.contains(_search)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final members = _filtered(UserRole.member);
    final kurirs = _filtered(UserRole.kurir);
    final admins = _filtered(UserRole.admin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Pembeli (${members.length})'),
            Tab(text: 'Kurir (${kurirs.length})'),
            Tab(text: 'Admin (${admins.length})'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari nama, email, atau telepon...',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildUserList(members, UserRole.member, Colors.blue),
                  _buildUserList(kurirs, UserRole.kurir, Colors.green),
                  _buildUserList(admins, UserRole.admin, Colors.orange),
                ],
              ),
            ),
          ]),
    );
  }

  Widget _buildUserList(List<User> users, UserRole role, Color color) {
    if (users.isEmpty) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 64, color: color.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text('Tidak ada ${_roleLabel(role)}', style: const TextStyle(color: AppColors.textSecondary)),
      ]),
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: u.photoUrl.isNotEmpty
              ? CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withOpacity(0.15),
                  backgroundImage: FileImage(File(u.photoUrl)),
                  onBackgroundImageError: (_, __) {},
                )
              : CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  radius: 26,
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.email_outlined, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(u.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
              if (u.phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(u.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ],
              const SizedBox(height: 2),
              Text('Bergabung: ${formatDate(u.createdAt)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
              child: Text(_roleLabel(role), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: IconText(Icons.assignment_outlined, 'Riwayat Aktivitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ),
              const SizedBox(height: 8),
              _ActivityLog(user: u, role: role),
            ],
          ),
        );
      },
    );
  }

  String _roleLabel(UserRole r) => switch (r) {
    UserRole.member => 'Pembeli',
    UserRole.kurir => 'Kurir',
    UserRole.admin => 'Admin',
    UserRole.superadmin => 'Superadmin',
  };
}

// Riwayat aktivitas read-only — tidak ada tombol edit/hapus/tambah,
// murni menampilkan log pesanan/pengantaran milik pengguna terkait.
class _ActivityLog extends StatelessWidget {
  final User user;
  final UserRole role;
  const _ActivityLog({required this.user, required this.role});

  Future<List<Order>> _fetch() {
    if (role == UserRole.member) return DatabaseHelper().getOrdersByMember(user.id);
    if (role == UserRole.kurir) return DatabaseHelper().getOrderHistoryByKurir(user.id);
    return Future.value(const []); // Admin/superadmin tidak punya riwayat pesanan
  }

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.admin || role == UserRole.superadmin) {
      return const Text('Tidak ada riwayat aktivitas untuk akun admin.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
    }
    return FutureBuilder<List<Order>>(
      future: _fetch(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Text('Belum ada riwayat aktivitas.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
        }
        return Column(
          children: list.take(10).map((o) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o.id} • ${toRupiah(o.totalAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(formatDate(o.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              OrderStatusChip(status: o.orderStatus),
            ]),
          )).toList(),
        );
      },
    );
  }
}
