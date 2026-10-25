// lib/screens/member/voucher_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class VoucherScreen extends StatefulWidget {
  final double orderTotal;
  final Function(Voucher) onVoucherApplied;

  const VoucherScreen({super.key, required this.orderTotal, required this.onVoucherApplied});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<VoucherProvider>().loadVouchers();
  }

  void _applyManualCode() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final vouchers = context.read<VoucherProvider>().vouchers;
    final voucher = vouchers.where((v) => v.code == code && v.isAvailable).firstOrNull;
    if (voucher == null) {
      setState(() => _error = 'Kode voucher tidak valid atau sudah kadaluarsa');
      return;
    }
    if (widget.orderTotal < voucher.minOrder) {
      setState(() => _error = 'Minimum pesanan ${toRupiah(voucher.minOrder)} untuk voucher ini');
      return;
    }
    Navigator.pop(context);
    widget.onVoucherApplied(voucher);
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VoucherProvider>();
    final available = vp.vouchers.where((v) => v.isAvailable && !v.isAutomatic).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Voucher')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Input manual
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconText(Icons.confirmation_number_outlined, 'Punya Kode Voucher?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Masukkan kode voucher...',
                      errorText: _error,
                      suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _codeCtrl.clear(); setState(() => _error = null); }),
                    ),
                  )),
                  const SizedBox(width: 10),
                  ElevatedButton(onPressed: _applyManualCode, child: const Text('Pakai')),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 16),
          const IconText(Icons.sell_outlined, 'Voucher Tersedia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          available.isEmpty
            ? const EmptyState(icon: Icons.discount_outlined, title: 'Belum ada voucher tersedia')
            : Column(children: available.map((v) {
                final disc = v.calculateDiscount(widget.orderTotal);
                final canUse = widget.orderTotal >= v.minOrder;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: canUse ? AppColors.primary.withOpacity(0.4) : AppColors.divider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      // Sisi kiri
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: canUse ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.discount, color: canUse ? AppColors.primary : AppColors.divider, size: 28),
                          Text(
                            v.type == DiscountType.percentage ? '${v.value.toInt()}%' : 'Rp${(v.value / 1000).toStringAsFixed(0)}K',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: canUse ? AppColors.primary : AppColors.divider),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      // Sisi kanan
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                            child: Text(v.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () { Clipboard.setData(ClipboardData(text: v.code)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode disalin!'))); },
                            child: const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(v.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          v.type == DiscountType.percentage
                            ? 'Diskon ${v.value.toInt()}%${v.maxDiscount > 0 ? " maks. ${toRupiah(v.maxDiscount)}" : ""}'
                            : 'Hemat ${toRupiah(v.value)}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 12),
                        ),
                        Text('Min. order: ${toRupiah(v.minOrder)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        Text('Sisa: ${v.quota - v.usedCount} kuota', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        if (!canUse) Text('Kurang ${toRupiah(v.minOrder - widget.orderTotal)} lagi', style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w500)),
                      ])),
                      // Tombol pakai
                      Column(children: [
                        if (disc > 0) Text('-${toRupiah(disc)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        ElevatedButton(
                          onPressed: canUse ? () { Navigator.pop(context); widget.onVoucherApplied(v); } : null,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          child: const Text('Pakai', style: TextStyle(fontSize: 12)),
                        ),
                      ]),
                    ]),
                  ),
                );
              }).toList()),
        ]),
      ),
    );
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }
}
