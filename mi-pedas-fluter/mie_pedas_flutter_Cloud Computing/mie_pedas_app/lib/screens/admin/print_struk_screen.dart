// lib/screens/admin/print_struk_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../../utils/printer_helper.dart';
import '../../widgets/widgets.dart';

class PrintStrukScreen extends StatefulWidget {
  final Order order;
  const PrintStrukScreen({super.key, required this.order});
  @override
  State<PrintStrukScreen> createState() => _PrintStrukScreenState();
}

class _PrintStrukScreenState extends State<PrintStrukScreen> {
  static const _printerChannel = MethodChannel('mie_pedas_app/printer');

  String _storeName = 'Mie Pedas Djora';
  String _storeAddress = 'Jl. Mie Pedas No. 1';
  String _storePhone = '08xxxxxxxxxx';
  bool _isPrinting = false;
  bool _isConnecting = false;
  String? _connectedDevice;
  List<Map<String, String>> _devices = [];
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() { _isConnecting = true; _statusMsg = 'Mencari perangkat Bluetooth...'; });
    try {
      final result = await _printerChannel.invokeMethod('getPairedDevices');
      final List<dynamic> raw = result ?? [];
      setState(() {
        _devices = raw.map((d) => {'name': d['name'].toString(), 'address': d['address'].toString()}).toList();
        _statusMsg = _devices.isEmpty ? 'Tidak ada printer Bluetooth yang dipasangkan' : '${_devices.length} perangkat ditemukan';
        _isConnecting = false;
      });
    } catch (e) {
      setState(() { _statusMsg = 'Gagal scan Bluetooth: $e'; _isConnecting = false; });
    }
  }

  Future<void> _connectAndPrint(String address, String name) async {
    setState(() { _isPrinting = true; _statusMsg = 'Menghubungkan ke $name...'; });
    try {
      final struk = PrinterHelper.formatStruk(widget.order, storeName: _storeName, storeAddress: _storeAddress, storePhone: _storePhone);
      final result = await _printerChannel.invokeMethod('connectAndPrint', {'address': address, 'text': struk});
      if (result == true) {
        setState(() { _connectedDevice = name; _statusMsg = 'Struk berhasil dicetak ke $name!'; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: IconText(Icons.check_circle, 'Struk berhasil dicetak!'), backgroundColor: AppColors.success));
      } else {
        setState(() => _statusMsg = 'Gagal mencetak. Coba lagi.');
      }
    } catch (e) {
      setState(() => _statusMsg = 'Error: $e');
    }
    setState(() => _isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final strukText = PrinterHelper.formatStruk(o, storeName: _storeName, storeAddress: _storeAddress, storePhone: _storePhone);

    return Scaffold(
      appBar: AppBar(title: const Text('Cetak Struk'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _scanDevices, tooltip: 'Scan ulang'),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Info Pesanan
          Card(
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconText(Icons.assignment_outlined, 'Info Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Text('ID: ${o.id}', style: const TextStyle(fontSize: 13)),
              Text('Pelanggan: ${o.memberName}', style: const TextStyle(fontSize: 13)),
              Text('Total: ${toRupiah(o.totalAmount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ])),
          ),

          const SizedBox(height: 12),

          // Pengaturan Toko
          Card(
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconText(Icons.storefront, 'Informasi Toko di Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Nama Toko', prefixIcon: Icon(Icons.store)),
                controller: TextEditingController(text: _storeName),
                onChanged: (v) => setState(() => _storeName = v),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'Alamat Toko', prefixIcon: Icon(Icons.location_on_outlined)),
                controller: TextEditingController(text: _storeAddress),
                onChanged: (v) => setState(() => _storeAddress = v),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'No. Telepon Toko', prefixIcon: Icon(Icons.phone_outlined)),
                controller: TextEditingController(text: _storePhone),
                keyboardType: TextInputType.phone,
                onChanged: (v) => setState(() => _storePhone = v),
              ),
            ])),
          ),

          const SizedBox(height: 12),

          // Preview Struk
          Card(
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const IconText(Icons.receipt_long, 'Preview Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: strukText)).then((_) =>
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Struk disalin!')))),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Salin'),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text(strukText, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4)),
              ),
            ])),
          ),

          const SizedBox(height: 12),

          // Bluetooth Devices
          Card(
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const IconText(Icons.print_outlined, 'Pilih Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_isConnecting) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 4),
              Text(_statusMsg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),

              if (_devices.isEmpty && !_isConnecting)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Cara menghubungkan printer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 6),
                    Text('1. Nyalakan printer thermal Bluetooth\n2. Buka Pengaturan HP → Bluetooth\n3. Pasangkan (pair) printer dulu\n4. Kembali ke sini dan tekan tombol Scan', style: TextStyle(fontSize: 12, height: 1.6)),
                  ]),
                ),

              ..._devices.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: _connectedDevice == d['name'] ? AppColors.success.withOpacity(0.1) : null,
                child: ListTile(
                  leading: Icon(Icons.print, color: _connectedDevice == d['name'] ? AppColors.success : AppColors.primary),
                  title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(d['address'] ?? ''),
                  trailing: _isPrinting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : ElevatedButton(
                        onPressed: () => _connectAndPrint(d['address']!, d['name']!),
                        child: const Text('Cetak'),
                      ),
                ),
              )),
            ])),
          ),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
