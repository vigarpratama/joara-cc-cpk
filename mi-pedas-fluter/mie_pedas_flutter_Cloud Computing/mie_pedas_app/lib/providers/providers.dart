// lib/providers/providers.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/api_config.dart';
import '../utils/api_service.dart';
import '../utils/database_helper.dart';
import '../utils/notification_helper.dart';
import '../utils/utils.dart';

// image_picker menyimpan file hasil pilih galeri/kamera di folder CACHE/TEMP,
// yang bisa dibersihkan OS sewaktu-waktu (biasanya kelihatan setelah app
// ditutup beberapa waktu — makanya foto tiba-tiba "Gagal memuat foto").
// Fungsi ini menyalin file itu ke folder dokumen APLIKASI yang permanen,
// dan mengembalikan path barunya buat disimpan ke database.
Future<String> persistPickedImage(String tempPath) async {
  if (tempPath.isEmpty) return tempPath;
  try {
    final srcFile = File(tempPath);
    if (!await srcFile.exists()) return tempPath;
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/joara_photos');
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final ext = tempPath.contains('.') ? tempPath.split('.').last : 'jpg';
    final destPath = '${photosDir.path}/img_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final destFile = await srcFile.copy(destPath);
    return destFile.path;
  } catch (_) {
    // Kalau gagal nyalin (mis. permission), fallback ke path asli daripada error total.
    return tempPath;
  }
}

// ==================== AUTH PROVIDER ====================
class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  Store? _currentStore; // store yang sedang login (untuk admin UMKM)
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  Store? get currentStore => _currentStore;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.role == UserRole.superadmin;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  String get currentStoreId => _currentStore?.id ?? _currentUser?.storeId ?? 'store_joara';

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final storeId = prefs.getString('currentStoreId');
    if (userId == null) return;
    try {
      final user = await DatabaseHelper().getUserById(userId);
      if (user == null) return;
      _currentUser = user;
      if (storeId != null) _currentStore = await DatabaseHelper().getStoreById(storeId);
      notifyListeners();
    } catch (_) {}
  }

  // Login biasa (member/kurir)
  Future<bool> login(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      if (ApiConfig.useBackend) {
        // Login lewat user-service (password benar-benar dicek di server)
        final remote = await ApiService.login(email, password);
        final backendUser = await _upsertLocalUser(remote);
        _currentUser = backendUser;
        _currentStore = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', backendUser.id);
        await prefs.remove('currentStoreId');
        _isLoading = false; notifyListeners(); return true;
      }
      final user = await DatabaseHelper().getUserByEmail(email);
      if (user == null) { _error = 'Email tidak ditemukan'; _isLoading = false; notifyListeners(); return false; }
      if (password.length < 6) { _error = 'Password minimal 6 karakter'; _isLoading = false; notifyListeners(); return false; }
      _currentUser = user;
      // Member/kurir TIDAK terikat ke 1 toko tertentu (marketplace multi-UMKM) —
      // _currentStore cuma dipakai untuk sesi admin UMKM (lihat loginAdmin()).
      // Storenya sebuah order ditentukan dari storeId menu di keranjang, bukan dari sini.
      _currentStore = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.id);
      await prefs.remove('currentStoreId'); // buang sisa sesi admin UMKM sebelumnya (kalau ada)
      _isLoading = false; notifyListeners(); return true;
    } on ApiException catch (e) {
      _error = e.message; _isLoading = false; notifyListeners(); return false;
    } catch (e) {
      // Jangan sampai spinner nyangkut selamanya kalau database/prefs error
      _error = 'Gagal masuk: $e'; _isLoading = false; notifyListeners(); return false;
    }
  }

  // Samakan data user dari backend ke SQLite lokal (id mengikuti backend). Data lokal
  // yang tidak ada di backend (foto, alamat, rekening kurir, koordinat rumah) dipertahankan.
  Future<User> _upsertLocalUser(Map<String, dynamic> r, {User? extras}) async {
    final id = r['id'] as String;
    final role = UserRole.values.firstWhere((x) => x.name == r['role'], orElse: () => UserRole.member);
    final db = DatabaseHelper();
    final email = (r['email'] as String);
    await db.deleteUserByEmailExceptId(email, id);
    final old = await db.getUserById(id);
    final base = old ?? extras;
    final user = User(
      id: id, name: r['name'] ?? '', email: email, phone: r['phone'] ?? '',
      address: base?.address ?? '', role: role, photoUrl: base?.photoUrl ?? '',
      storeId: (r['storeId'] as String?)?.isNotEmpty == true ? r['storeId'] : (base?.storeId ?? ''),
      withdrawMethod: base?.withdrawMethod ?? '', withdrawAccountNumber: base?.withdrawAccountNumber ?? '',
      plateNumber: base?.plateNumber ?? '', ktpUrl: base?.ktpUrl ?? '', stnkUrl: base?.stnkUrl ?? '',
      homeLat: base?.homeLat, homeLng: base?.homeLng,
    );
    await db.insertUser(user);
    return user;
  }

  // Login Superadmin Joara
  Future<bool> loginSuperAdmin(String username, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    final savedUser = await DatabaseHelper().getAdminSetting('superadmin_username') ?? 'joara';
    final savedPass = await DatabaseHelper().getAdminSetting('superadmin_password') ?? 'joara2024';
    if (username != savedUser || password != savedPass) {
      _error = 'Username atau password salah'; _isLoading = false; notifyListeners(); return false;
    }
    final users = await DatabaseHelper().getAllUsers();
    try { _currentUser = users.firstWhere((u) => u.role == UserRole.superadmin); } catch (_) {
      _currentUser = User(id: 'superadmin_1', name: 'Joara Superadmin', email: 'superadmin@joara.com', role: UserRole.superadmin);
    }
    if (ApiConfig.useBackend) {
      try { await ApiService.staffSync(role: 'superadmin', username: username, password: password, name: _currentUser!.name); }
      catch (e) {
        // Jangan masuk panel tanpa token backend: tampilkan penyebab aslinya (mis. "app key tidak valid")
        _currentUser = null;
        _error = 'Gagal tersambung ke server: $e';
        _isLoading = false; notifyListeners(); return false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', _currentUser!.id);
    _isLoading = false; notifyListeners(); return true;
  }

  // Login Admin UMKM (username + password per toko)
  Future<bool> loginAdmin(String username, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    final store = await DatabaseHelper().loginStore(username, password);
    if (store == null) { _error = 'Username/password salah atau toko tidak aktif'; _isLoading = false; notifyListeners(); return false; }
    _currentStore = store;
    final existingAdmin = await DatabaseHelper().getAdminByStoreId(store.id);
    if (existingAdmin != null) {
      _currentUser = existingAdmin;
    } else {
      // Toko ini belum punya row admin di database (biasanya toko baru dari
      // superadmin) — bikin sekali dan SIMPAN, biar foto profil/data lain
      // gak ilang tiap kali admin logout-login lagi.
      _currentUser = User(id: 'admin_${store.id}', name: 'Admin ${store.name}', email: store.adminEmail, role: UserRole.admin, storeId: store.id);
      await DatabaseHelper().insertUser(_currentUser!);
    }
    if (ApiConfig.useBackend) {
      // Daftarkan/sinkronkan akun admin toko ke user-service supaya dapat token untuk order-service
      try { await ApiService.staffSync(role: 'admin', username: username, password: password, name: _currentUser!.name, storeId: store.id); }
      catch (e) {
        // Jangan masuk panel tanpa token backend: tampilkan penyebab aslinya (mis. "app key tidak valid")
        _currentStore = null;
        _currentUser = null;
        _error = 'Gagal tersambung ke server: $e';
        _isLoading = false; notifyListeners(); return false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', _currentUser!.id);
    await prefs.setString('currentStoreId', store.id);
    _isLoading = false; notifyListeners(); return true;
  }

  Future<bool> register(String name, String email, String phone, String password, {
    UserRole role = UserRole.member,
    String withdrawMethod = '',
    String withdrawAccountNumber = '',
    String plateNumber = '',
    String ktpUrl = '',
    String stnkUrl = '',
  }) async {
    _isLoading = true; _error = null; notifyListeners();
    if (ApiConfig.useBackend) {
      try {
        final remote = await ApiService.register(
          name: name, email: email, phone: phone, password: password,
          role: role == UserRole.kurir ? 'kurir' : 'member');
        // Data tambahan kurir (rekening, plat, KTP/STNK) tetap disimpan lokal
        final extras = User(
          id: remote['id'], name: name, email: email, phone: phone, role: role,
          withdrawMethod: withdrawMethod, withdrawAccountNumber: withdrawAccountNumber,
          plateNumber: plateNumber, ktpUrl: ktpUrl, stnkUrl: stnkUrl,
        );
        _currentUser = await _upsertLocalUser(remote, extras: extras);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _currentUser!.id);
        _isLoading = false; notifyListeners(); return true;
      } on ApiException catch (e) {
        _error = e.message; _isLoading = false; notifyListeners(); return false;
      } catch (e) {
        _error = 'Gagal mendaftar: $e'; _isLoading = false; notifyListeners(); return false;
      }
    }
    final existing = await DatabaseHelper().getUserByEmail(email);
    if (existing != null) { _error = 'Email sudah terdaftar'; _isLoading = false; notifyListeners(); return false; }
    final user = User(
      id: const Uuid().v4(), name: name, email: email, phone: phone, role: role,
      withdrawMethod: withdrawMethod, withdrawAccountNumber: withdrawAccountNumber,
      plateNumber: plateNumber, ktpUrl: ktpUrl, stnkUrl: stnkUrl,
    );
    await DatabaseHelper().insertUser(user);
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id);
    _isLoading = false; notifyListeners(); return true;
  }

  Future<void> logout() async {
    _currentUser = null; _currentStore = null;
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('currentStoreId');
    notifyListeners();
  }

  Future<void> updateProfile(String name, String phone, String address) async {
    if (_currentUser == null) return;
    final updated = User(id: _currentUser!.id, name: name, email: _currentUser!.email, phone: phone, address: address, role: _currentUser!.role, photoUrl: _currentUser!.photoUrl, storeId: _currentUser!.storeId, createdAt: _currentUser!.createdAt);
    await DatabaseHelper().updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String photoPath) async {
    if (_currentUser == null) return;
    final persistedPath = await persistPickedImage(photoPath);
    final updated = User(id: _currentUser!.id, name: _currentUser!.name, email: _currentUser!.email, phone: _currentUser!.phone, address: _currentUser!.address, role: _currentUser!.role, photoUrl: persistedPath, storeId: _currentUser!.storeId, createdAt: _currentUser!.createdAt);
    await DatabaseHelper().updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<bool> updateAdminCredentials({required String oldPassword, required String newUsername, String? newPassword}) async {
    _error = null;
    if (_currentStore == null) return false;
    if (oldPassword != _currentStore!.adminPassword) { _error = 'Password lama salah'; notifyListeners(); return false; }
    _currentStore!.adminUsername = newUsername;
    if (newPassword != null && newPassword.isNotEmpty) _currentStore!.adminPassword = newPassword;
    await DatabaseHelper().updateStore(_currentStore!);
    notifyListeners(); return true;
  }

  // Update rekening BRI & nomer e-wallet toko — dipakai baik oleh toko yang baru
  // daftar maupun toko lama yang belum sempat isi data ini (satu fungsi, sama
  // konsepnya buat semua toko, gak dibedakan baru/lama).
  Future<bool> updateStoreBankAndEwallet({
    required String bankAccountNumber,
    required String bankAccountName,
    required String bankName,
    required String gopayNumber,
    required String ovoNumber,
    required String danaNumber,
  }) async {
    if (_currentStore == null) return false;
    final updated = Store(
      id: _currentStore!.id, name: _currentStore!.name, description: _currentStore!.description,
      address: _currentStore!.address, phone: _currentStore!.phone, ownerName: _currentStore!.ownerName,
      adminEmail: _currentStore!.adminEmail, adminUsername: _currentStore!.adminUsername,
      adminPassword: _currentStore!.adminPassword, logoUrl: _currentStore!.logoUrl,
      status: _currentStore!.status, isSelfRegistered: _currentStore!.isSelfRegistered,
      bankAccountNumber: bankAccountNumber, bankAccountName: bankAccountName, bankName: bankName,
      ktpUrl: _currentStore!.ktpUrl, storefrontPhotoUrl: _currentStore!.storefrontPhotoUrl,
      qrisImageUrl: _currentStore!.qrisImageUrl,
      gopayNumber: gopayNumber, ovoNumber: ovoNumber, danaNumber: danaNumber,
      commissionRate: _currentStore!.commissionRate,
      latitude: _currentStore!.latitude, longitude: _currentStore!.longitude, createdAt: _currentStore!.createdAt,
    );
    await DatabaseHelper().updateStore(updated);
    _currentStore = updated;
    notifyListeners();
    return true;
  }

  Future<String> getAdminUsername() async => _currentStore?.adminUsername ?? 'admin';

  // Update lokasi resto (untuk fitur GPS 3 titik) — dipanggil dari panel admin resto
  Future<bool> updateStoreLocation(double lat, double lng) async {
    if (_currentStore == null) return false;
    final updated = Store(
      id: _currentStore!.id, name: _currentStore!.name, description: _currentStore!.description,
      address: _currentStore!.address, phone: _currentStore!.phone, ownerName: _currentStore!.ownerName,
      adminEmail: _currentStore!.adminEmail, adminUsername: _currentStore!.adminUsername,
      adminPassword: _currentStore!.adminPassword, logoUrl: _currentStore!.logoUrl,
      status: _currentStore!.status, isSelfRegistered: _currentStore!.isSelfRegistered,
      bankAccountNumber: _currentStore!.bankAccountNumber, bankAccountName: _currentStore!.bankAccountName, bankName: _currentStore!.bankName,
      ktpUrl: _currentStore!.ktpUrl, storefrontPhotoUrl: _currentStore!.storefrontPhotoUrl,
      qrisImageUrl: _currentStore!.qrisImageUrl,
      gopayNumber: _currentStore!.gopayNumber, ovoNumber: _currentStore!.ovoNumber, danaNumber: _currentStore!.danaNumber,
      commissionRate: _currentStore!.commissionRate,
      latitude: lat, longitude: lng, createdAt: _currentStore!.createdAt,
    );
    await DatabaseHelper().updateStore(updated);
    _currentStore = updated;
    notifyListeners();
    return true;
  }

  // Update foto QRIS asli UMKM (dipakai saat customer checkout pakai QRIS)
  Future<bool> updateStoreQris(String imagePath) async {
    if (_currentStore == null) return false;
    final persistedPath = await persistPickedImage(imagePath);
    final updated = Store(
      id: _currentStore!.id, name: _currentStore!.name, description: _currentStore!.description,
      address: _currentStore!.address, phone: _currentStore!.phone, ownerName: _currentStore!.ownerName,
      adminEmail: _currentStore!.adminEmail, adminUsername: _currentStore!.adminUsername,
      adminPassword: _currentStore!.adminPassword, logoUrl: _currentStore!.logoUrl,
      status: _currentStore!.status, isSelfRegistered: _currentStore!.isSelfRegistered,
      bankAccountNumber: _currentStore!.bankAccountNumber, bankAccountName: _currentStore!.bankAccountName, bankName: _currentStore!.bankName,
      ktpUrl: _currentStore!.ktpUrl, storefrontPhotoUrl: _currentStore!.storefrontPhotoUrl,
      qrisImageUrl: persistedPath,
      gopayNumber: _currentStore!.gopayNumber, ovoNumber: _currentStore!.ovoNumber, danaNumber: _currentStore!.danaNumber,
      commissionRate: _currentStore!.commissionRate,
      latitude: _currentStore!.latitude, longitude: _currentStore!.longitude, createdAt: _currentStore!.createdAt,
    );
    await DatabaseHelper().updateStore(updated);
    _currentStore = updated;
    notifyListeners();
    return true;
  }

  // Update foto tampak depan toko (ditampilkan ke member/kurir/superadmin)
  Future<bool> updateStoreStorefrontPhoto(String imagePath) async {
    if (_currentStore == null) return false;
    final persistedPath = await persistPickedImage(imagePath);
    final updated = Store(
      id: _currentStore!.id, name: _currentStore!.name, description: _currentStore!.description,
      address: _currentStore!.address, phone: _currentStore!.phone, ownerName: _currentStore!.ownerName,
      adminEmail: _currentStore!.adminEmail, adminUsername: _currentStore!.adminUsername,
      adminPassword: _currentStore!.adminPassword, logoUrl: _currentStore!.logoUrl,
      status: _currentStore!.status, isSelfRegistered: _currentStore!.isSelfRegistered,
      bankAccountNumber: _currentStore!.bankAccountNumber, bankAccountName: _currentStore!.bankAccountName, bankName: _currentStore!.bankName,
      ktpUrl: _currentStore!.ktpUrl, storefrontPhotoUrl: persistedPath,
      qrisImageUrl: _currentStore!.qrisImageUrl,
      gopayNumber: _currentStore!.gopayNumber, ovoNumber: _currentStore!.ovoNumber, danaNumber: _currentStore!.danaNumber,
      commissionRate: _currentStore!.commissionRate,
      latitude: _currentStore!.latitude, longitude: _currentStore!.longitude, createdAt: _currentStore!.createdAt,
    );
    await DatabaseHelper().updateStore(updated);
    _currentStore = updated;
    notifyListeners();
    return true;
  }

  // Update koordinat rumah member (untuk "Navigasi ke Rumahku" yang presisi)
  Future<bool> updateHomeLocation(double lat, double lng) async {
    if (_currentUser == null) return false;
    final updated = User(
      id: _currentUser!.id, name: _currentUser!.name, email: _currentUser!.email,
      phone: _currentUser!.phone, address: _currentUser!.address, role: _currentUser!.role,
      photoUrl: _currentUser!.photoUrl, isActive: _currentUser!.isActive, storeId: _currentUser!.storeId,
      withdrawMethod: _currentUser!.withdrawMethod, withdrawAccountNumber: _currentUser!.withdrawAccountNumber,
      plateNumber: _currentUser!.plateNumber, ktpUrl: _currentUser!.ktpUrl, stnkUrl: _currentUser!.stnkUrl,
      homeLat: lat, homeLng: lng, createdAt: _currentUser!.createdAt,
    );
    await DatabaseHelper().updateUser(updated);
    _currentUser = updated;
    notifyListeners();
    return true;
  }

  Future<bool> updateSuperAdminCredentials({required String oldPassword, required String newUsername, String? newPassword}) async {
    _error = null;
    final savedPass = await DatabaseHelper().getAdminSetting('superadmin_password') ?? 'joara2024';
    if (oldPassword != savedPass) { _error = 'Password lama salah'; notifyListeners(); return false; }
    await DatabaseHelper().setAdminSetting('superadmin_username', newUsername);
    if (newPassword != null && newPassword.isNotEmpty) await DatabaseHelper().setAdminSetting('superadmin_password', newPassword);
    notifyListeners(); return true;
  }
}

// ==================== STORE PROVIDER ====================
class StoreProvider extends ChangeNotifier {
  List<Store> _stores = [];
  bool _isLoading = false;
  String? _error;

  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Store> get activeStores => _stores.where((s) => s.status == StoreStatus.active).toList();
  List<Store> get pendingStores => _stores.where((s) => s.status == StoreStatus.pending).toList();

  Future<void> loadStores() async {
    _isLoading = true; notifyListeners();
    _stores = await DatabaseHelper().getAllStores();
    _isLoading = false; notifyListeners();
  }

  Future<bool> addStore(Store store) async {
    _error = null;
    try {
      await DatabaseHelper().insertStore(store);
      // Buat menu dummy untuk store baru
      for (final m in getDummyMenus(storeId: store.id)) {
        await DatabaseHelper().insertMenu(Menu(id: "${store.id}_${m.id}", storeId: store.id, name: m.name, description: m.description, price: m.price, category: m.category, spicyLevel: m.spicyLevel, rating: m.rating, totalReviews: m.totalReviews, stock: m.stock, isAvailable: m.isAvailable, isBestSeller: m.isBestSeller, isNew: m.isNew));
      }
      await loadStores();
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<void> updateStore(Store store) async {
    await DatabaseHelper().updateStore(store);
    await loadStores();
  }

  Future<void> suspendStore(String storeId) async {
    await DatabaseHelper().updateStoreStatus(storeId, StoreStatus.suspended);
    await loadStores();
  }

  Future<void> activateStore(String storeId) async {
    await DatabaseHelper().updateStoreStatus(storeId, StoreStatus.active);
    await loadStores();
  }

  // Hapus UMKM permanen. Hanya boleh untuk UMKM yang statusnya SUSPENDED —
  // jaga-jaga di level provider juga (bukan cuma dicek di UI), supaya UMKM
  // aktif/pending gak bisa kehapus gara-gara ada tombol nyasar atau bug UI.
  Future<bool> deleteStore(String storeId) async {
    final store = _stores.where((s) => s.id == storeId).firstOrNull;
    if (store == null || store.status != StoreStatus.suspended) return false;
    await DatabaseHelper().deleteStore(storeId);
    await loadStores();
    return true;
  }

  Future<bool> registerStore(Store store) async {
    _error = null;
    try {
      final persistedKtp = await persistPickedImage(store.ktpUrl);
      final persistedStorefront = await persistPickedImage(store.storefrontPhotoUrl);
      final pending = Store(
        id: store.id, name: store.name, description: store.description,
        address: store.address, phone: store.phone, ownerName: store.ownerName,
        adminEmail: store.adminEmail, adminUsername: store.adminUsername,
        adminPassword: store.adminPassword, status: StoreStatus.pending,
        isSelfRegistered: true,
        bankAccountNumber: store.bankAccountNumber, bankAccountName: store.bankAccountName, bankName: store.bankName,
        ktpUrl: persistedKtp, storefrontPhotoUrl: persistedStorefront,
        qrisImageUrl: store.qrisImageUrl,
        gopayNumber: store.gopayNumber, ovoNumber: store.ovoNumber, danaNumber: store.danaNumber,
        commissionRate: store.commissionRate,
        latitude: store.latitude, longitude: store.longitude,
      );
      await DatabaseHelper().insertStore(pending);
      await loadStores();
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  // Laporan potongan admin untuk satu resto (periode: semua pesanan selesai)
  Future<StoreCommissionReport> getCommissionReport(Store store) async {
    final completed = await DatabaseHelper().getCompletedOrdersByStore(store.id);
    final totalOrders = completed.length;
    final totalSubtotal = completed.fold(0.0, (s, o) => s + o.subtotal);
    final totalDeliveryFee = completed.fold(0.0, (s, o) => s + o.deliveryFee);
    final totalRevenue = completed.fold(0.0, (s, o) => s + o.totalAmount);
    final adminFee = totalSubtotal * (store.commissionRate / 100);
    final netForStore = totalSubtotal - adminFee;
    return StoreCommissionReport(
      store: store, totalOrders: totalOrders, totalSubtotal: totalSubtotal,
      totalDeliveryFee: totalDeliveryFee, totalRevenue: totalRevenue,
      adminFee: adminFee, netForStore: netForStore, orders: completed,
    );
  }
}

// ==================== MENU PROVIDER ====================
class MenuProvider extends ChangeNotifier {
  List<Menu> _menus = [];
  bool _isLoading = false;
  String _currentStoreId = 'store_joara';

  List<Menu> get menus => _menus;
  bool get isLoading => _isLoading;
  List<Menu> get bestSellers => _menus.where((m) => m.isBestSeller).toList();
  List<Menu> get newMenus => _menus.where((m) => m.isNew).toList();

  Future<void> loadMenus({String? storeId}) async {
    _isLoading = true; notifyListeners();
    if (storeId != null) {
      // Admin: load menu toko sendiri
      _currentStoreId = storeId;
      _menus = await DatabaseHelper().getMenusByStore(storeId);
    } else {
      // Pembeli: load semua menu dari semua toko
      _menus = await DatabaseHelper().getAllMenus();
    }
    _isLoading = false; notifyListeners();
  }

  List<Menu> filterMenus({MenuCategory? category, String? query}) {
    return _menus.where((m) {
      final catMatch = category == null || category == MenuCategory.semua || m.category == category;
      final q = query?.toLowerCase() ?? '';
      final nameMatch = q.isEmpty || m.name.toLowerCase().contains(q) || m.description.toLowerCase().contains(q);
      return catMatch && nameMatch;
    }).toList();
  }

  Future<void> addMenu(Menu menu) async { await DatabaseHelper().insertMenu(menu); await loadMenus(storeId: _currentStoreId); }
  Future<void> updateMenu(Menu menu) async { await DatabaseHelper().updateMenu(menu); await loadMenus(storeId: _currentStoreId); }
  Future<void> deleteMenu(String id) async { await DatabaseHelper().deleteMenu(id); await loadMenus(storeId: _currentStoreId); }
}

// ==================== CART PROVIDER ====================
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  List<CartItem> get items => _items;
  int get count => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get deliveryFee { if (subtotal >= 100000) return 0; if (subtotal >= 50000) return 5000; return 10000; }
  double get grandTotal => subtotal + deliveryFee;
  bool get isEmpty => _items.isEmpty;
  // UMKM asal item di keranjang saat ini (null kalau kosong). Dipakai UI buat
  // cegah campur pesanan dari 2 UMKM berbeda dalam satu keranjang/order.
  String? get storeId => _items.isEmpty ? null : _items.first.menu.storeId;

  // Return true kalau berhasil ditambahkan. Return false kalau menu ini dari UMKM
  // LAIN sementara keranjang masih ada isi dari UMKM sebelumnya — UI pemanggil
  // wajib tanya user dulu (mis. dialog "Ganti keranjang? Isi sebelumnya akan hilang")
  // sebelum retry dengan forceClear: true.
  bool addItem(Menu menu, {int quantity = 1, int? spicyLevel, String note = '', bool forceClear = false}) {
    if (_items.isNotEmpty && _items.first.menu.storeId != menu.storeId) {
      if (!forceClear) return false;
      _items.clear();
    }
    final sl = spicyLevel ?? menu.spicyLevel;
    final existing = _items.where((i) => i.menu.id == menu.id && i.spicyLevel == sl).firstOrNull;
    if (existing != null) { existing.quantity += quantity; } else { _items.add(CartItem(menu: menu, quantity: quantity, spicyLevel: sl, note: note)); }
    notifyListeners();
    return true;
  }
  void removeItem(CartItem item) { _items.remove(item); notifyListeners(); }
  void updateQuantity(CartItem item, int qty) { if (qty <= 0) { _items.remove(item); } else { item.quantity = qty; } notifyListeners(); }
  void clear() { _items.clear(); notifyListeners(); }
}

// ==================== ORDER PROVIDER ====================
class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> loadAllOrders() async { _isLoading = true; notifyListeners(); await _pullRemote(); _orders = await DatabaseHelper().getAllOrders(); _isLoading = false; notifyListeners(); }
  Future<void> loadStoreOrders(String storeId) async { _isLoading = true; notifyListeners(); await _pullRemote(storeId: storeId); _orders = await DatabaseHelper().getOrdersByStore(storeId); _isLoading = false; notifyListeners(); }
  Future<void> loadMemberOrders(String memberId) async { _isLoading = true; notifyListeners(); await _pullRemote(); _orders = await DatabaseHelper().getOrdersByMember(memberId); _isLoading = false; notifyListeners(); }
  Future<void> loadKurirOrders(String kurirId) async { _isLoading = true; notifyListeners(); await _pullRemote(kurir: true); _orders = await DatabaseHelper().getOrdersByKurir(kurirId); _isLoading = false; notifyListeners(); }

  // ---------- sinkron dengan order-service ----------
  // Ambil pesanan dari backend lalu gabungkan ke SQLite lokal. Kalau backend tidak bisa
  // dihubungi, pesan error sudah ditampilkan ApiService dan tampilan memakai data lokal terakhir.
  Future<void> _pullRemote({String? storeId, bool kurir = false}) async {
    if (!ApiConfig.useBackend) return;
    try {
      final remote = <Map<String, dynamic>>[];
      if (kurir) {
        remote.addAll(await ApiService.listOrders(status: 'ready')); // pesanan siap diambil
        remote.addAll(await ApiService.listOrders());                // pesanan milik kurir ini
      } else {
        remote.addAll(await ApiService.listOrders(storeId: storeId));
      }
      for (final r in remote) { await _mergeRemoteOrder(r); }
    } catch (_) {}
  }

  OrderStatus _parseOrderStatus(dynamic v) => OrderStatus.values.firstWhere((s) => s.name == v, orElse: () => OrderStatus.pending);
  PaymentStatus _parsePaymentStatus(dynamic v) => PaymentStatus.values.firstWhere((s) => s.name == v, orElse: () => PaymentStatus.pending);
  PaymentMethod _parsePaymentMethod(dynamic v) => PaymentMethod.values.firstWhere((s) => s.name == v, orElse: () => PaymentMethod.cash);

  Future<void> _mergeRemoteOrder(Map<String, dynamic> r) async {
    final db = DatabaseHelper();
    final id = r['orderId'] as String;
    final status = _parseOrderStatus(r['orderStatus']);
    final pay = _parsePaymentStatus(r['paymentStatus']);
    final local = await db.getOrderById(id);
    if (local != null) {
      await db.applyRemoteOrderState(id, orderStatus: status, paymentStatus: pay,
        kurirId: r['kurirId'] as String?, kurirName: r['kurirName'] as String?, kurirPhone: r['kurirPhone'] as String?);
      return;
    }
    // Pesanan dari perangkat lain / belum ada di SQLite lokal
    final items = ((r['items'] as List?) ?? []).map((i) => OrderItem(
      menuId: (i['menuId'] ?? '') as String, menuName: (i['menuName'] ?? '') as String,
      price: (i['price'] as num? ?? 0).toDouble(), quantity: (i['quantity'] as num? ?? 1).toInt(),
      spicyLevel: (i['spicyLevel'] as num? ?? 1).toInt(), note: (i['note'] ?? '') as String)).toList();
    await db.insertOrder(Order(
      id: id, storeId: r['storeId'] ?? 'default',
      memberId: r['memberId'] ?? '', memberName: r['memberName'] ?? '', memberPhone: r['memberPhone'] ?? '',
      kurirId: r['kurirId'] ?? '', kurirName: r['kurirName'] ?? '', kurirPhone: r['kurirPhone'] ?? '',
      deliveryAddress: r['deliveryAddress'] ?? '', items: items,
      subtotal: (r['subtotal'] as num? ?? 0).toDouble(), deliveryFee: (r['deliveryFee'] as num? ?? 0).toDouble(),
      discount: (r['discount'] as num? ?? 0).toDouble(), totalAmount: (r['totalAmount'] as num? ?? 0).toDouble(),
      paymentMethod: _parsePaymentMethod(r['paymentMethod']), paymentStatus: pay, orderStatus: status,
      orderNote: r['note'] ?? '', promoCode: r['promoCode'] ?? '', storeName: r['storeName'] ?? '',
      createdAt: DateTime.tryParse(r['createdAt'] ?? '')?.millisecondsSinceEpoch,
    ));
  }

  Future<Order> placeOrder({required User member, required List<CartItem> items, required String address, required PaymentMethod paymentMethod, String note = '', String promoCode = '', double discount = 0, String storeId = 'store_joara', double? deliveryFee, double? customerLat, double? customerLng, String? paymentProofPath}) async {
    final subtotal = items.fold(0.0, (s, i) => s + i.subtotal);
    final fee = deliveryFee ?? (subtotal >= 100000 ? 0.0 : subtotal >= 50000 ? 5000.0 : 10000.0);
    // Ambil info resto agar foto & nama resto langsung tersedia untuk kurir
    final store = await DatabaseHelper().getStoreById(storeId);
    // Foto bukti pembayaran dari image_picker juga di folder cache/temp — simpan
    // permanen dulu (sama kayak foto KTP/toko/QRIS) biar gak "Gagal memuat foto".
    final persistedProof = paymentProofPath != null ? await persistPickedImage(paymentProofPath) : '';

    // Buat pesanan di order-service. Order id, waktu, dan nominal total dipakai dari balasan server.
    Map<String, dynamic>? remote;
    if (ApiConfig.useBackend) {
      remote = await ApiService.createOrder({
        'storeId': storeId, 'storeName': store?.name ?? '',
        'memberPhone': member.phone, 'deliveryAddress': address,
        'paymentMethod': paymentMethod.name, 'deliveryFee': fee, 'discount': discount,
        'note': note, 'promoCode': promoCode,
        'items': items.map((i) => {
          'menuId': i.menu.id, 'menuName': i.menu.name, 'price': i.menu.price,
          'quantity': i.quantity, 'spicyLevel': i.spicyLevel, 'note': i.note,
        }).toList(),
      });
    }
    final order = Order(
      id: remote != null ? remote['orderId'] as String : 'ORD${DateTime.now().millisecondsSinceEpoch}', storeId: storeId,
      createdAt: remote != null ? DateTime.tryParse(remote['createdAt'] ?? '')?.millisecondsSinceEpoch : null,
      memberId: member.id, memberName: member.name, memberPhone: member.phone,
      deliveryAddress: address,
      items: items.map((i) => OrderItem(menuId: i.menu.id, menuName: i.menu.name, price: i.menu.price, quantity: i.quantity, spicyLevel: i.spicyLevel, note: i.note)).toList(),
      subtotal: subtotal, deliveryFee: fee, discount: discount,
      totalAmount: remote != null ? (remote['totalAmount'] as num).toDouble() : subtotal + fee - discount, paymentMethod: paymentMethod, orderNote: note, promoCode: promoCode,
      storeName: store?.name ?? '', storePhotoUrl: store?.storefrontPhotoUrl ?? '',
      memberPhotoUrl: member.photoUrl,
      customerLat: customerLat ?? 0, customerLng: customerLng ?? 0,
      paymentProofUrl: persistedProof,
    );
    await DatabaseHelper().insertOrder(order);
    _orders.insert(0, order);
    notifyListeners();

    // Kurangi stok tiap menu yang dipesan
    for (final item in items) {
      await DatabaseHelper().decrementMenuStock(item.menu.id, item.quantity);
    }

    // Notifikasi ke toko: ada pesanan baru masuk
    NotificationHelper.showOrderNotification(
      title: 'Pesanan Baru! 🍜',
      body: '${member.name} pesan ${items.length} item • ${toRupiah(order.totalAmount)}',
      id: order.id.hashCode & 0x7fffffff,
      category: 'pesanan',
      payload: 'new_order:${order.id}',
    );

    return order;
  }

  Future<void> updateStatus(String orderId, OrderStatus status, {bool remote = true}) async {
    if (ApiConfig.useBackend && remote) {
      try { await ApiService.updateOrderStatus(orderId, status.name); } on ApiException { return; }
    }
    final idx = _orders.indexWhere((o) => o.id == orderId);
    final oldStatus = idx != -1 ? _orders[idx].orderStatus : null;

    await DatabaseHelper().updateOrderStatus(orderId, status);

    if (idx != -1) {
      _orders[idx].orderStatus = status;

      // Order dibatalkan → kembalikan stok yang sempat dikurangi pas order dibuat
      if (status == OrderStatus.cancelled && oldStatus != OrderStatus.cancelled) {
        for (final item in _orders[idx].items) {
          await DatabaseHelper().restoreMenuStock(item.menuId, item.quantity);
        }
      }
      // Order yang tadinya dibatalkan diaktifkan lagi → kurangi stoknya lagi
      else if (oldStatus == OrderStatus.cancelled && status != OrderStatus.cancelled) {
        for (final item in _orders[idx].items) {
          await DatabaseHelper().decrementMenuStock(item.menuId, item.quantity);
        }
      }

      notifyListeners();

      // Notifikasi ke pembeli: status pesanan berubah
      NotificationHelper.showOrderNotification(
        title: 'Update Pesanan 📦',
        body: 'Pesanan ${orderId} sekarang: ${orderStatusLabel(status)}',
        id: orderId.hashCode & 0x7fffffff,
        category: 'pesanan',
        payload: 'order_update:$orderId',
      );
    }
  }

  // Kurir mengambil pesanan siap antar. Lewat backend, pengambilan bersifat atomik:
  // kalau kurir lain sudah mengambilnya duluan, order-service menolak.
  Future<bool> takeOrder(Order o, User kurir) async {
    if (ApiConfig.useBackend) {
      try { await ApiService.assignOrder(o.id, kurirPhone: kurir.phone); } on ApiException { await loadKurirOrders(kurir.id); return false; }
      await updateStatus(o.id, OrderStatus.delivering, remote: false);
    } else {
      await updateStatus(o.id, OrderStatus.delivering);
    }
    await DatabaseHelper().assignKurir(o.id, kurir.id, kurir.name, kurirPhotoUrl: kurir.photoUrl, kurirPhone: kurir.phone);
    final idx = _orders.indexWhere((x) => x.id == o.id);
    if (idx != -1) { _orders[idx].kurirId = kurir.id; _orders[idx].kurirName = kurir.name; _orders[idx].kurirPhotoUrl = kurir.photoUrl; _orders[idx].kurirPhone = kurir.phone; notifyListeners(); }
    return true;
  }

  // Tandai status pembayaran order (mis. dari "pending" jadi "paid"/lunas) —
  // panggil ini dari layar detail order (tombol "Tandai Lunas") setelah
  // admin/superadmin verifikasi transfer/e-wallet/QRIS sudah masuk.
  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) async {
    if (ApiConfig.useBackend && status == PaymentStatus.paid) {
      try { await ApiService.markPaid(orderId); } on ApiException { return; }
    }
    await DatabaseHelper().updatePaymentStatus(orderId, status);
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx].paymentStatus = status;
      notifyListeners();
    }
  }

  // Update/ganti foto bukti pembayaran order yang sudah ada
  Future<void> updatePaymentProof(String orderId, String proofPath) async {
    final persisted = await persistPickedImage(proofPath);
    await DatabaseHelper().updatePaymentProof(orderId, persisted);
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx].paymentProofUrl = persisted;
      notifyListeners();
    }
  }

  // Customer konfirmasi pesanan lewat chat — kurir baru bisa lanjut transaksi setelah ini
  Future<void> confirmOrderByCustomer(String orderId) async {
    await DatabaseHelper().confirmOrderByCustomer(orderId);
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) { _orders[idx].customerConfirmed = true; notifyListeners(); }
  }

  List<Order> get pendingOrders => _orders.where((o) => o.orderStatus == OrderStatus.pending).toList();
  double get todayRevenue {
    final today = DateTime.now();
    return _orders.where((o) { final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt); return d.day == today.day && d.month == today.month && d.year == today.year; }).fold(0.0, (s, o) => s + o.totalAmount);
  }
}

// ==================== VOUCHER PROVIDER ====================
class VoucherProvider extends ChangeNotifier {
  List<Voucher> _vouchers = [];
  bool _isLoading = false;
  List<Voucher> get vouchers => _vouchers;
  bool get isLoading => _isLoading;

  Future<void> loadVouchers({String? storeId}) async {
    _isLoading = true; notifyListeners();
    _vouchers = storeId != null ? await DatabaseHelper().getVouchersByStore(storeId) : await DatabaseHelper().getAllVouchers();
    _isLoading = false; notifyListeners();
  }

  Future<void> addVoucher(Voucher v) async {
    await DatabaseHelper().insertVoucher(v);
    await loadVouchers(storeId: v.storeId);

    // Notifikasi promo ke pembeli: ada voucher baru tersedia
    final discountText = v.type == DiscountType.percentage
        ? 'Diskon ${v.value.toInt()}%'
        : 'Potongan ${toRupiah(v.value)}';
    NotificationHelper.showOrderNotification(
      title: '🎟️ Voucher Baru: ${v.code}',
      body: '${v.description} • $discountText',
      id: v.id.hashCode & 0x7fffffff,
      category: 'promo',
    );
  }
  Future<void> updateVoucher(Voucher v) async { await DatabaseHelper().updateVoucher(v); await loadVouchers(storeId: v.storeId); }
  Future<void> deleteVoucher(String id) async { await DatabaseHelper().deleteVoucher(id); await loadVouchers(); }

  Future<void> incrementUsage(String voucherId) async {
    final idx = _vouchers.indexWhere((v) => v.id == voucherId);
    if (idx != -1) {
      final v = _vouchers[idx];
      v.usedCount = (v.usedCount ?? 0) + 1;
      await DatabaseHelper().updateVoucher(v);
      notifyListeners();
    }
  }
}

// ==================== REVIEW PROVIDER ====================
class ReviewProvider extends ChangeNotifier {
  List<Review> _reviews = [];
  bool _isLoading = false;
  double _avgRating = 0;

  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;
  double get avgRating => _avgRating;

  Future<void> loadReviewsByTarget(String targetId) async {
    _isLoading = true; notifyListeners();
    _reviews = await DatabaseHelper().getReviewsByTarget(targetId);
    _avgRating = await DatabaseHelper().getAverageRating(targetId);
    _isLoading = false; notifyListeners();
  }

  Future<void> loadMyReviews(String memberId) async {
    _isLoading = true; notifyListeners();
    _reviews = await DatabaseHelper().getReviewsByMember(memberId);
    _isLoading = false; notifyListeners();
  }

  Future<bool> hasReviewedOrder(String orderId, ReviewTarget target) async {
    final reviews = await DatabaseHelper().getReviewsByOrder(orderId);
    return reviews.any((r) => r.target == target);
  }

  Future<void> submitReview(Review review) async {
    await DatabaseHelper().insertReview(review);
    _reviews.insert(0, review);
    notifyListeners();
  }
}
