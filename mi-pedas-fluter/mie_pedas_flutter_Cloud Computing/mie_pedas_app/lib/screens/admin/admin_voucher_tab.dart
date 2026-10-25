// lib/screens/admin/admin_voucher_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class AdminVoucherTab extends StatefulWidget {
  const AdminVoucherTab({super.key});
  @override
  State<AdminVoucherTab> createState() => _AdminVoucherTabState();
}

class _AdminVoucherTabState extends State<AdminVoucherTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId = context.read<AuthProvider>().currentStoreId;
      context.read<VoucherProvider>().loadVouchers(storeId: storeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VoucherProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Voucher')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_voucher_fab',
        onPressed: () => _showVoucherForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Buat Voucher'),
      ),
      body: vp.isLoading
        ? const Center(child: CircularProgressIndicator())
        : vp.vouchers.isEmpty
          ? const EmptyState(icon: Icons.discount_outlined, title: 'Belum ada voucher', subtitle: 'Tap tombol + untuk membuat voucher baru')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: vp.vouchers.length,
              itemBuilder: (_, i) {
                final v = vp.vouchers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: v.isAvailable ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        // Kode voucher
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: v.isAvailable ? AppColors.primary : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(v.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                        ),
                        Row(children: [
                          if (v.isAutomatic) Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Auto', style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          if (v.isExpired) Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Kadaluarsa', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 8),
                      Text(v.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      // Nilai diskon
                      Text(
                        v.type == DiscountType.percentage
                          ? 'Diskon ${v.value.toInt()}%${v.maxDiscount > 0 ? " (maks. ${toRupiah(v.maxDiscount)})" : ""}'
                          : 'Potongan ${toRupiah(v.value)}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        _infoChip(Icons.shopping_bag_outlined, 'Min. ${toRupiah(v.minOrder)}'),
                        const SizedBox(width: 8),
                        _infoChip(Icons.people_outline, '${v.usedCount}/${v.quota == 0 ? "∞" : v.quota.toString()}'),
                      ]),
                      const SizedBox(height: 4),
                      Text('Berlaku s/d: ${formatDate(v.expiredAt)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const Divider(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton.icon(
                          onPressed: () => _showVoucherForm(context, v),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(context, v),
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                          label: const Text('Hapus', style: TextStyle(color: AppColors.error)),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );

  void _confirmDelete(BuildContext context, Voucher v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Voucher'),
        content: Text('Yakin hapus voucher "${v.code}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () { context.read<VoucherProvider>().deleteVoucher(v.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showVoucherForm(BuildContext context, Voucher? existing) {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(text: existing?.value.toString() ?? '');
    final minOrderCtrl = TextEditingController(text: existing?.minOrder.toString() ?? '0');
    final maxDiscCtrl = TextEditingController(text: existing?.maxDiscount.toString() ?? '0');
    final quotaCtrl = TextEditingController(text: existing?.quota.toString() ?? '100');
    var type = existing?.type ?? DiscountType.nominal;
    var isAuto = existing?.isAutomatic ?? false;
    var autoTrigger = existing?.autoTrigger ?? 'new_user';
    var expiredDate = existing != null
      ? DateTime.fromMillisecondsSinceEpoch(existing.expiredAt)
      : DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Buat Voucher Baru' : 'Edit Voucher', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Kode Voucher
              Row(children: [
                Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Kode Voucher'), textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setS(() => codeCtrl.text = 'MIEDJORA${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, "0")}'),
                  child: const Text('Generate'),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi Voucher')),
              const SizedBox(height: 10),

              // Tipe diskon
              const Text('Tipe Diskon', style: TextStyle(fontWeight: FontWeight.w500)),
              Row(children: [
                Expanded(child: RadioListTile<DiscountType>(
                  value: DiscountType.nominal, groupValue: type,
                  onChanged: (v) => setS(() => type = v!),
                  title: const Text('Nominal (Rp)', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                )),
                Expanded(child: RadioListTile<DiscountType>(
                  value: DiscountType.percentage, groupValue: type,
                  onChanged: (v) => setS(() => type = v!),
                  title: const Text('Persentase (%)', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                )),
              ]),

              Row(children: [
                Expanded(child: TextField(controller: valueCtrl, decoration: InputDecoration(labelText: type == DiscountType.nominal ? 'Nilai (Rp)' : 'Nilai (%)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: minOrderCtrl, decoration: const InputDecoration(labelText: 'Min. Pesanan (Rp)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              if (type == DiscountType.percentage)
                TextField(controller: maxDiscCtrl, decoration: const InputDecoration(labelText: 'Maks. Diskon (Rp, isi 0 jika tidak ada batas)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),

              Row(children: [
                Expanded(child: TextField(controller: quotaCtrl, decoration: const InputDecoration(labelText: 'Kuota (isi 0 = tak terbatas)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: expiredDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setS(() => expiredDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Kadaluarsa'),
                    child: Text('${expiredDate.day}/${expiredDate.month}/${expiredDate.year}', style: const TextStyle(fontSize: 13)),
                  ),
                )),
              ]),
              const SizedBox(height: 10),

              // Voucher otomatis
              SwitchListTile(
                value: isAuto,
                onChanged: (v) => setS(() => isAuto = v),
                title: const Text('Voucher Otomatis', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Diberikan otomatis ke pembeli'),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
              ),
              if (isAuto) DropdownButtonFormField<String>(
                value: autoTrigger,
                decoration: const InputDecoration(labelText: 'Trigger Otomatis'),
                items: const [
                  DropdownMenuItem(value: 'new_user', child: Text('Pengguna Baru')),
                  DropdownMenuItem(value: 'every_order', child: Text('Setiap Pesanan')),
                  DropdownMenuItem(value: 'every_5_orders', child: Text('Setiap 5 Pesanan')),
                ],
                onChanged: (v) => setS(() => autoTrigger = v!),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (codeCtrl.text.isEmpty || valueCtrl.text.isEmpty) return;
                    final storeId = ctx.read<AuthProvider>().currentStoreId;
                    final voucher = Voucher(
                      id: existing?.id ?? const Uuid().v4(),
                      storeId: existing?.storeId ?? storeId,
                      code: codeCtrl.text.toUpperCase().trim(),
                      description: descCtrl.text,
                      type: type,
                      value: double.tryParse(valueCtrl.text) ?? 0,
                      minOrder: double.tryParse(minOrderCtrl.text) ?? 0,
                      maxDiscount: double.tryParse(maxDiscCtrl.text) ?? 0,
                      quota: int.tryParse(quotaCtrl.text) ?? 100,
                      usedCount: existing?.usedCount ?? 0,
                      isAutomatic: isAuto,
                      autoTrigger: isAuto ? autoTrigger : '',
                      expiredAt: expiredDate.millisecondsSinceEpoch,
                    );
                    if (existing == null) {
                      await ctx.read<VoucherProvider>().addVoucher(voucher);
                    } else {
                      await ctx.read<VoucherProvider>().updateVoucher(voucher);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(existing == null ? 'Buat Voucher' : 'Simpan'),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}
