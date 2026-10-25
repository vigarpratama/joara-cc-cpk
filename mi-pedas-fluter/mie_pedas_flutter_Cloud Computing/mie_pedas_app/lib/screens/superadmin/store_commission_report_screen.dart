// lib/screens/superadmin/store_commission_report_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';

class StoreCommissionReportScreen extends StatefulWidget {
  final Store store;
  const StoreCommissionReportScreen({super.key, required this.store});

  @override
  State<StoreCommissionReportScreen> createState() => _StoreCommissionReportScreenState();
}

class _StoreCommissionReportScreenState extends State<StoreCommissionReportScreen> {
  StoreCommissionReport? _report;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh berkala biar kalau ada pesanan yang baru selesai
    // (diproses dari sisi kurir/admin), laporan ini ikut update tanpa
    // superadmin harus keluar-masuk atau pull-to-refresh manual.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final report = await context.read<StoreProvider>().getCommissionReport(widget.store);
    if (mounted) setState(() { _report = report; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: Text('Laporan • ${store.name}')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Header resto
                Card(
                  color: const Color(0xFF6A1B9A),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      store.storefrontPhotoUrl.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Colors.white, radius: 26,
                            backgroundImage: FileImage(File(store.storefrontPhotoUrl)),
                            onBackgroundImageError: (_, __) {},
                          )
                        : CircleAvatar(backgroundColor: Colors.white, radius: 26, child: Text(store.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold, fontSize: 20))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(store.ownerName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Ringkasan potongan admin
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const IconText(Icons.payments_outlined, 'Ringkasan Potongan Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${store.commissionRate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Berdasarkan pesanan yang sudah selesai', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const Divider(height: 24),
                      _rowLabel('Total Pesanan Selesai', '${_report?.totalOrders ?? 0} pesanan'),
                      _rowLabel('Total Penjualan Produk', toRupiah(_report?.totalSubtotal ?? 0)),
                      _rowLabel('Total Ongkir (bukan hak resto)', toRupiah(_report?.totalDeliveryFee ?? 0)),
                      const Divider(height: 24),
                      _rowLabel('Potongan Admin', '- ${toRupiah(_report?.adminFee ?? 0)}', valueColor: AppColors.error),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Diterima Resto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(toRupiah(_report?.netForStore ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Rekening pencairan
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const IconText(Icons.account_balance, 'Rekening Pencairan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      _rowLabel('Bank', 'BRI'),
                      _rowLabel('No. Rekening', store.bankAccountNumber.isEmpty ? '-' : store.bankAccountNumber),
                      _rowLabel('Nama Pemilik', store.bankAccountName.isEmpty ? '-' : store.bankAccountName),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Daftar pesanan
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const IconText(Icons.assignment_outlined, 'Rincian Pesanan Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      if ((_report?.orders ?? []).isEmpty)
                        const Text('Belum ada pesanan selesai', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...(_report!.orders.map((o) {
                          final fee = o.subtotal * (store.commissionRate / 100);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(o.memberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(formatDate(o.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(toRupiah(o.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text('- ${toRupiah(fee)}', style: const TextStyle(color: AppColors.error, fontSize: 11)),
                              ]),
                            ]),
                          );
                        })),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
    );
  }

  Widget _rowLabel(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor)),
    ]),
  );
}
