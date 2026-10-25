// lib/screens/auth/store_register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/maps_service.dart';
import '../../widgets/widgets.dart';
import '../member/location_picker_screen.dart';

class StoreRegisterScreen extends StatefulWidget {
  const StoreRegisterScreen({super.key});
  @override
  State<StoreRegisterScreen> createState() => _StoreRegisterScreenState();
}

class _StoreRegisterScreenState extends State<StoreRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _bankNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _gopayCtrl = TextEditingController();
  final _ovoCtrl = TextEditingController();
  final _danaCtrl = TextEditingController();
  bool _obscure = true, _loading = false;
  String? _error;
  int _step = 0;
  String? _bankName;
  String? _ktpPath;
  String? _storefrontPath;
  LatLng? _pickedCoord; // koordinat resto untuk GPS 3 titik

  Future<void> _pilihLokasiPeta() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: _pickedCoord)),
    );
    if (result == null || !mounted) return;
    setState(() => _pickedCoord = result);
  }

  Future<void> _pickImage(bool isKtp) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isKtp) { _ktpPath = picked.path; } else { _storefrontPath = picked.path; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar UMKM')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Progress
          Row(children: List.generate(4, (i) => Expanded(child: Container(
            height: 4, margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: i <= _step ? AppColors.primary : AppColors.divider, borderRadius: BorderRadius.circular(2)),
          )))),
          const SizedBox(height: 20),

          if (_step == 0) ..._step0(),
          if (_step == 1) ..._step1(),
          if (_step == 2) ..._step2Documents(),
          if (_step == 3) ..._step3(),

          const SizedBox(height: 24),
          Row(children: [
            if (_step > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Kembali'))),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(child: _step < 3
              ? ElevatedButton(onPressed: _nextStep, child: const Text('Lanjut'))
              : LoadingButton(onPressed: _submit, isLoading: _loading, label: 'Daftar Sekarang')),
          ]),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
          ],
        ]),
      ),
    );
  }

  List<Widget> _step0() => [
    const IconText(Icons.assignment_outlined, 'Info Toko', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('Informasi dasar tentang UMKM kamu', style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nama Toko/UMKM *', prefixIcon: Icon(Icons.store))),
    const SizedBox(height: 12),
    TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi Toko', prefixIcon: Icon(Icons.description_outlined)), maxLines: 2),
    const SizedBox(height: 12),
    TextField(controller: _ownerCtrl, decoration: const InputDecoration(labelText: 'Nama Pemilik *', prefixIcon: Icon(Icons.person_outline))),
    const SizedBox(height: 12),
    TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Nomor Telepon *', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
    const SizedBox(height: 12),
    TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Alamat Toko *', prefixIcon: Icon(Icons.location_on_outlined)), maxLines: 2),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: _pilihLokasiPeta,
      icon: Icon(_pickedCoord == null ? Icons.map_outlined : Icons.check_circle, color: _pickedCoord == null ? AppColors.primary : Colors.green),
      label: Text(_pickedCoord == null ? 'Tandai Lokasi Resto di Peta' : 'Lokasi Resto Sudah Ditandai'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _pickedCoord == null ? AppColors.primary : Colors.green,
        side: BorderSide(color: _pickedCoord == null ? AppColors.primary : Colors.green),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
    const SizedBox(height: 4),
    const Text('Untuk fitur GPS 3 titik (rute kurir: kamu → resto → customer)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ];

  List<Widget> _step1() => [
    const IconText(Icons.email_outlined, 'Info Akun', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('Akun email dan login admin toko', style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Admin *', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 12),
    TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Username Login Admin *', prefixIcon: Icon(Icons.account_circle_outlined))),
    const SizedBox(height: 12),
    TextField(controller: _passCtrl, obscureText: _obscure, decoration: InputDecoration(
      labelText: 'Password Admin *', prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
    )),
    const SizedBox(height: 12),
    TextField(controller: _confirmCtrl, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Konfirmasi Password *', prefixIcon: Icon(Icons.lock_outline))),
  ];

  List<Widget> _step2Documents() => [
    const IconText(Icons.account_balance, 'Rekening & Dokumen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('Untuk pencairan dana dan verifikasi legalitas resto', style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    DropdownButtonFormField<String>(
      value: _bankName,
      decoration: const InputDecoration(labelText: 'Pilih Bank *', prefixIcon: Icon(Icons.account_balance_outlined)),
      items: indonesianBanks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
      onChanged: (v) => setState(() => _bankName = v),
    ),
    const SizedBox(height: 12),
    TextField(controller: _bankNumberCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No. Rekening *', prefixIcon: Icon(Icons.numbers_outlined))),
    const SizedBox(height: 12),
    TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening *', prefixIcon: Icon(Icons.badge_outlined))),
    const SizedBox(height: 20),
    const Text('Nomer E-Wallet (opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    const Text('Isi salah satu atau lebih kalau toko punya, biar customer bisa bayar lewat e-wallet ini', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    const SizedBox(height: 8),
    TextField(controller: _gopayCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. GoPay', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
    const SizedBox(height: 12),
    TextField(controller: _ovoCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. OVO', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
    const SizedBox(height: 12),
    TextField(controller: _danaCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. DANA', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
    const SizedBox(height: 20),
    const Text('Foto KTP Pemilik *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(height: 8),
    _photoPicker(path: _ktpPath, label: 'Upload foto KTP', onTap: () => _pickImage(true)),
    const SizedBox(height: 16),
    const Text('Foto Resto Tampak Depan *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(height: 8),
    _photoPicker(path: _storefrontPath, label: 'Upload foto tampak depan', onTap: () => _pickImage(false)),
  ];

  Widget _photoPicker({required String? path, required String label, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 140, width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: path == null
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              Image.file(File(path), fit: BoxFit.cover),
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),
    ),
  );

  List<Widget> _step3() => [
    const IconText(Icons.check_circle, 'Konfirmasi', iconColor: Colors.green, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('Periksa kembali data UMKM kamu', style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _reviewRow('Nama Toko', _nameCtrl.text),
      _reviewRow('Pemilik', _ownerCtrl.text),
      _reviewRow('Telepon', _phoneCtrl.text),
      _reviewRow('Alamat', _addressCtrl.text),
      _reviewRow('Email', _emailCtrl.text),
      _reviewRow('Username Admin', _userCtrl.text),
      _reviewRow('Bank', _bankName ?? '-'),
      _reviewRow('No. Rekening', _bankNumberCtrl.text),
      _reviewRow('Nama Pemilik Rekening', _bankNameCtrl.text),
      if (_gopayCtrl.text.isNotEmpty) _reviewRow('No. GoPay', _gopayCtrl.text),
      if (_ovoCtrl.text.isNotEmpty) _reviewRow('No. OVO', _ovoCtrl.text),
      if (_danaCtrl.text.isNotEmpty) _reviewRow('No. DANA', _danaCtrl.text),
      _reviewRow('Foto KTP', _ktpPath != null ? 'Terupload' : 'Belum upload', ok: _ktpPath != null),
      _reviewRow('Foto Resto', _storefrontPath != null ? 'Terupload' : 'Belum upload', ok: _storefrontPath != null),
      _reviewRow('Lokasi Peta', _pickedCoord != null ? 'Ditandai' : 'Belum ditandai', ok: _pickedCoord != null),
    ]))),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: const Row(children: [
        Icon(Icons.pending_actions, color: Colors.orange),
        SizedBox(width: 10),
        Expanded(child: Text('Pendaftaran akan diverifikasi oleh Joara Superadmin terlebih dahulu sebelum bisa login.', style: TextStyle(fontSize: 13, color: Colors.orange))),
      ])),
  ];

  Widget _reviewRow(String label, String value, {bool? ok}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text('$label:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Expanded(child: ok == null
        ? Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
        : IconText(ok ? Icons.check_circle : Icons.cancel, value, iconColor: ok ? Colors.green : Colors.red, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );

  void _nextStep() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_nameCtrl.text.isEmpty || _ownerCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _addressCtrl.text.isEmpty) { setState(() => _error = 'Semua field wajib diisi'); return; }
    } else if (_step == 1) {
      if (_emailCtrl.text.isEmpty || _userCtrl.text.isEmpty || _passCtrl.text.isEmpty) { setState(() => _error = 'Semua field wajib diisi'); return; }
      if (_passCtrl.text != _confirmCtrl.text) { setState(() => _error = 'Password tidak cocok'); return; }
      if (_passCtrl.text.length < 6) { setState(() => _error = 'Password minimal 6 karakter'); return; }
    } else if (_step == 2) {
      if (_bankName == null || _bankNumberCtrl.text.isEmpty || _bankNameCtrl.text.isEmpty) { setState(() => _error = 'Bank, no. rekening, dan nama pemilik wajib diisi'); return; }
      if (_ktpPath == null || _storefrontPath == null) { setState(() => _error = 'Foto KTP dan foto resto wajib diupload'); return; }
    }
    setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final store = Store(
      id: 'store_${const Uuid().v4().substring(0, 8)}',
      name: _nameCtrl.text, description: _descCtrl.text,
      ownerName: _ownerCtrl.text, phone: _phoneCtrl.text,
      address: _addressCtrl.text, adminEmail: _emailCtrl.text,
      adminUsername: _userCtrl.text, adminPassword: _passCtrl.text,
      isSelfRegistered: true, status: StoreStatus.pending,
      bankAccountNumber: _bankNumberCtrl.text, bankAccountName: _bankNameCtrl.text, bankName: _bankName ?? '',
      gopayNumber: _gopayCtrl.text, ovoNumber: _ovoCtrl.text, danaNumber: _danaCtrl.text,
      ktpUrl: _ktpPath ?? '', storefrontPhotoUrl: _storefrontPath ?? '',
      latitude: _pickedCoord?.lat ?? 0, longitude: _pickedCoord?.lng ?? 0,
    );
    final ok = await context.read<StoreProvider>().registerStore(store);
    setState(() => _loading = false);
    if (ok && mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 64),
          const SizedBox(height: 16),
          const Text('Pendaftaran Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Pendaftaran UMKM kamu sudah diterima. Tunggu verifikasi dari Joara Superadmin.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ]),
        actions: [ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); Navigator.pop(context); }, child: const Text('OK'))],
      ));
    } else { setState(() => _error = context.read<StoreProvider>().error ?? 'Gagal mendaftar'); }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _ownerCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose(); _descCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose(); _bankNumberCtrl.dispose(); _bankNameCtrl.dispose(); _gopayCtrl.dispose(); _ovoCtrl.dispose(); _danaCtrl.dispose(); super.dispose(); }
}
