// lib/utils/database_helper.dart
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  static Database? _database;

  static void initDesktop() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'joara_delivery.db');
    return openDatabase(path, version: 14, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Kolom baru untuk resto: rekening BRI, KTP, foto tampak depan, komisi admin
      await db.execute("ALTER TABLE stores ADD COLUMN bankAccountNumber TEXT DEFAULT ''");
      await db.execute("ALTER TABLE stores ADD COLUMN bankAccountName TEXT DEFAULT ''");
      await db.execute("ALTER TABLE stores ADD COLUMN ktpUrl TEXT DEFAULT ''");
      await db.execute("ALTER TABLE stores ADD COLUMN storefrontPhotoUrl TEXT DEFAULT ''");
      await db.execute("ALTER TABLE stores ADD COLUMN commissionRate REAL DEFAULT 10.0");
      // Kolom baru untuk kurir: rekening/e-wallet penyetoran & dokumen kendaraan
      await db.execute("ALTER TABLE users ADD COLUMN withdrawMethod TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN withdrawAccountNumber TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN plateNumber TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN ktpUrl TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN stnkUrl TEXT DEFAULT ''");
    }
    if (oldVersion < 3) {
      // Koordinat resto (titik tengah GPS 3 titik)
      await db.execute("ALTER TABLE stores ADD COLUMN latitude REAL DEFAULT 0");
      await db.execute("ALTER TABLE stores ADD COLUMN longitude REAL DEFAULT 0");
      // Foto resto & koordinat customer di pesanan
      await db.execute("ALTER TABLE orders ADD COLUMN storeName TEXT DEFAULT ''");
      await db.execute("ALTER TABLE orders ADD COLUMN storePhotoUrl TEXT DEFAULT ''");
      await db.execute("ALTER TABLE orders ADD COLUMN customerLat REAL DEFAULT 0");
      await db.execute("ALTER TABLE orders ADD COLUMN customerLng REAL DEFAULT 0");
    }
    if (oldVersion < 4) {
      // Konfirmasi customer via chat sebelum kurir lanjut transaksi
      await db.execute("ALTER TABLE orders ADD COLUMN customerConfirmed INTEGER DEFAULT 0");
    }
    if (oldVersion < 5) {
      // Koordinat rumah member, dipakai fitur "Navigasi ke Rumahku"
      await db.execute("ALTER TABLE users ADD COLUMN homeLat REAL");
      await db.execute("ALTER TABLE users ADD COLUMN homeLng REAL");
    }
    if (oldVersion < 6) {
      // Foto QRIS asli milik UMKM, ditampilkan saat customer checkout pakai QRIS
      await db.execute("ALTER TABLE stores ADD COLUMN qrisImageUrl TEXT DEFAULT ''");
    }
    if (oldVersion < 7) {
      // Foto profil customer, biar admin/kurir/superadmin bisa lihat foto member yang pesan
      await db.execute("ALTER TABLE orders ADD COLUMN memberPhotoUrl TEXT DEFAULT ''");
    }
    if (oldVersion < 8) {
      // Foto profil kurir, biar member/admin/superadmin bisa lihat foto kurir yang antar
      await db.execute("ALTER TABLE orders ADD COLUMN kurirPhotoUrl TEXT DEFAULT ''");
    }
    if (oldVersion < 9) {
      // Nomor telepon kurir (fitur tombol telepon di chat)
      await db.execute("ALTER TABLE orders ADD COLUMN kurirPhone TEXT DEFAULT ''");
      // Status baca pesan chat (centang abu-abu vs biru)
      await db.execute("ALTER TABLE chat_messages ADD COLUMN isRead INTEGER DEFAULT 0");
    }
    if (oldVersion < 10) {
      // Voice note di chat
      await db.execute("ALTER TABLE chat_messages ADD COLUMN audioUrl TEXT DEFAULT ''");
      await db.execute("ALTER TABLE chat_messages ADD COLUMN audioDurationMs INTEGER DEFAULT 0");
    }
    if (oldVersion < 11) {
      // Foto profil pembeli yang kasih ulasan (biar avatar muncul di daftar ulasan)
      try {
        await db.execute("ALTER TABLE reviews ADD COLUMN memberPhotoUrl TEXT DEFAULT ''");
      } catch (_) {
        // Tabel reviews belum pernah dibuat (belum ada yang kasih ulasan) — aman diabaikan,
        // createReviewTable() sudah include kolom ini buat instalasi baru.
      }
    }
    if (oldVersion < 12) {
      // Nomer e-wallet toko (opsional), dipakai saat customer checkout pilih E-Wallet
      await db.execute("ALTER TABLE stores ADD COLUMN gopayNumber TEXT DEFAULT ''");
      await db.execute("ALTER TABLE stores ADD COLUMN ovoNumber TEXT DEFAULT ''");
      await db.execute("ALTER TABLE stores ADD COLUMN danaNumber TEXT DEFAULT ''");
    }
    if (oldVersion < 13) {
      // Foto bukti pembayaran (transfer/e-wallet/QRIS) yang di-upload customer saat checkout
      await db.execute("ALTER TABLE orders ADD COLUMN paymentProofUrl TEXT DEFAULT ''");
    }
    if (oldVersion < 14) {
      // Nama bank (BCA/BRI/Mandiri/dst) — sebelumnya di-hardcode BRI, sekarang admin toko pilih sendiri
      await db.execute("ALTER TABLE stores ADD COLUMN bankName TEXT DEFAULT ''");
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // STORES
    await db.execute('''CREATE TABLE stores (
      id TEXT PRIMARY KEY, name TEXT, description TEXT, address TEXT,
      phone TEXT, ownerName TEXT, adminEmail TEXT, adminUsername TEXT,
      adminPassword TEXT, logoUrl TEXT, status TEXT,
      isSelfRegistered INTEGER, createdAt INTEGER,
      bankAccountNumber TEXT DEFAULT '', bankAccountName TEXT DEFAULT '',
      bankName TEXT DEFAULT '',
      ktpUrl TEXT DEFAULT '', storefrontPhotoUrl TEXT DEFAULT '',
      qrisImageUrl TEXT DEFAULT '',
      gopayNumber TEXT DEFAULT '', ovoNumber TEXT DEFAULT '', danaNumber TEXT DEFAULT '',
      commissionRate REAL DEFAULT 10.0,
      latitude REAL DEFAULT 0, longitude REAL DEFAULT 0
    )''');

    // USERS
    await db.execute('''CREATE TABLE users (
      id TEXT PRIMARY KEY, name TEXT, email TEXT UNIQUE, phone TEXT,
      address TEXT, role TEXT, photoUrl TEXT, isActive INTEGER,
      storeId TEXT, createdAt INTEGER,
      withdrawMethod TEXT DEFAULT '', withdrawAccountNumber TEXT DEFAULT '',
      plateNumber TEXT DEFAULT '', ktpUrl TEXT DEFAULT '', stnkUrl TEXT DEFAULT '',
      homeLat REAL, homeLng REAL
    )''');

    // MENUS
    await db.execute('''CREATE TABLE menus (
      id TEXT PRIMARY KEY, storeId TEXT, name TEXT, description TEXT, price REAL,
      imageUrl TEXT, category TEXT, spicyLevel INTEGER, rating REAL,
      totalReviews INTEGER, stock INTEGER, isAvailable INTEGER,
      isBestSeller INTEGER, isNew INTEGER, createdAt INTEGER
    )''');

    // ORDERS
    await db.execute('''CREATE TABLE orders (
      id TEXT PRIMARY KEY, storeId TEXT, memberId TEXT, memberName TEXT,
      memberPhone TEXT, kurirId TEXT, kurirName TEXT, deliveryAddress TEXT,
      itemsJson TEXT, subtotal REAL, deliveryFee REAL, discount REAL,
      totalAmount REAL, paymentMethod TEXT, paymentStatus TEXT, orderStatus TEXT,
      orderNote TEXT, estimatedTime INTEGER, promoCode TEXT,
      createdAt INTEGER, updatedAt INTEGER,
      storeName TEXT DEFAULT '', storePhotoUrl TEXT DEFAULT '', memberPhotoUrl TEXT DEFAULT '',
      kurirPhotoUrl TEXT DEFAULT '', kurirPhone TEXT DEFAULT '',
      customerLat REAL DEFAULT 0, customerLng REAL DEFAULT 0,
      customerConfirmed INTEGER DEFAULT 0,
      paymentProofUrl TEXT DEFAULT ''
    )''');

    // VOUCHERS
    await db.execute('''CREATE TABLE vouchers (
      id TEXT PRIMARY KEY, storeId TEXT, code TEXT, description TEXT,
      type TEXT, value REAL, minOrder REAL, maxDiscount REAL,
      quota INTEGER, usedCount INTEGER, isActive INTEGER,
      isAutomatic INTEGER, autoTrigger TEXT, expiredAt INTEGER, createdAt INTEGER
    )''');

    // ADMIN SETTINGS (per store)
    await db.execute('''CREATE TABLE admin_settings (
      key TEXT PRIMARY KEY, value TEXT
    )''');

    // Seed Superadmin settings
    await db.insert('admin_settings', {'key': 'superadmin_username', 'value': 'joara'});
    await db.insert('admin_settings', {'key': 'superadmin_password', 'value': 'joara2024'});

    // Seed store Joara (default)
    final joaraStore = Store(
      id: 'store_joara', name: 'Mie Pedas Djora', description: 'Mie pedas terenak di kota!',
      address: 'Jl. Mie Pedas No. 1, Surabaya', phone: '081234567890',
      ownerName: 'Joara', adminEmail: 'admin@joara.com',
      adminUsername: 'admin', adminPassword: 'admin123',
      status: StoreStatus.active,
    );
    await db.insert('stores', joaraStore.toMap());

    // Seed demo users
    final users = [
      User(id: 'superadmin_1', name: 'Joara Superadmin', email: 'superadmin@joara.com', role: UserRole.superadmin),
      User(id: 'admin_joara', name: 'Admin Mie Pedas Djora', email: 'admin@joara.com', role: UserRole.admin, storeId: 'store_joara'),
      User(id: 'kurir_1', name: 'Budi Kurir', email: 'kurir@demo.com', phone: '082222222222', role: UserRole.kurir, storeId: 'store_joara'),
      User(id: 'member_1', name: 'Sari Member', email: 'member@demo.com', phone: '083333333333', role: UserRole.member),
    ];
    for (final u in users) await db.insert('users', u.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed menus for Joara
    for (final m in getDummyMenus(storeId: 'store_joara')) {
      await db.insert('menus', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ==================== STORES ====================
  Future<List<Store>> getAllStores() async {
    final db = await database;
    final res = await db.query('stores', orderBy: 'createdAt DESC');
    return res.map(Store.fromMap).toList();
  }

  Future<Store?> getStoreById(String id) async {
    final db = await database;
    final res = await db.query('stores', where: 'id = ?', whereArgs: [id]);
    return res.isEmpty ? null : Store.fromMap(res.first);
  }

  Future<void> insertStore(Store store) async {
    final db = await database;
    await db.insert('stores', store.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStore(Store store) async {
    final db = await database;
    await db.update('stores', store.toMap(), where: 'id = ?', whereArgs: [store.id]);
  }

  Future<void> updateStoreStatus(String storeId, StoreStatus status) async {
    final db = await database;
    await db.update('stores', {'status': status.name}, where: 'id = ?', whereArgs: [storeId]);
  }

  // Hapus UMKM beserta data turunannya (menu & voucher milik toko itu).
  // Order historis SENGAJA TIDAK dihapus — biar laporan komisi/riwayat transaksi
  // tetap valid & bisa ditelusuri walau UMKM-nya sudah tidak ada lagi.
  Future<void> deleteStore(String storeId) async {
    final db = await database;
    await db.delete('menus', where: 'storeId = ?', whereArgs: [storeId]);
    await db.delete('vouchers', where: 'storeId = ?', whereArgs: [storeId]);
    await db.delete('stores', where: 'id = ?', whereArgs: [storeId]);
  }

  Future<Store?> loginStore(String username, String password) async {
    final db = await database;
    final res = await db.query('stores', where: 'adminUsername = ? AND adminPassword = ? AND status = ?', whereArgs: [username, password, 'active']);
    return res.isEmpty ? null : Store.fromMap(res.first);
  }

  // Query langsung by role+storeId, jauh lebih cepat daripada getAllUsers()
  // lalu firstWhere di Dart (yang narik SEMUA baris tabel users ke memory).
  Future<User?> getAdminByStoreId(String storeId) async {
    final db = await database;
    final res = await db.query('users', where: 'role = ? AND storeId = ?', whereArgs: ['admin', storeId]);
    return res.isEmpty ? null : User.fromMap(res.first);
  }

  // Laporan pesanan selesai per resto (untuk hitung potongan admin)
  Future<List<Order>> getCompletedOrdersByStore(String storeId) async {
    final db = await database;
    final res = await db.query(
      'orders',
      where: "storeId = ? AND orderStatus IN ('delivered','done')",
      whereArgs: [storeId],
      orderBy: 'createdAt DESC',
    );
    return res.map(Order.fromMap).toList();
  }

  // ==================== USERS ====================
  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return res.isEmpty ? null : User.fromMap(res.first);
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return res.isEmpty ? null : User.fromMap(res.first);
  }

  // Dipakai saat login via backend: id user ditentukan backend, jadi buang baris lokal lama
  // yang emailnya sama tapi id-nya beda (kolom email UNIQUE).
  Future<void> deleteUserByEmailExceptId(String email, String keepId) async {
    final db = await database;
    await db.delete('users', where: 'email = ? AND id != ?', whereArgs: [email, keepId]);
  }

  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final res = await db.query('users');
    return res.map(User.fromMap).toList();
  }

  Future<List<User>> getUsersByStore(String storeId) async {
    final db = await database;
    final res = await db.query('users', where: 'storeId = ?', whereArgs: [storeId]);
    return res.map(User.fromMap).toList();
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // ==================== MENUS ====================
  Future<List<Menu>> getMenusByStore(String storeId) async {
    final db = await database;
    final res = await db.query('menus', where: 'storeId = ? AND isAvailable = 1', whereArgs: [storeId]);
    return res.map(Menu.fromMap).toList();
  }

  Future<List<Menu>> getAllMenus() async {
    final db = await database;
    final res = await db.query('menus', where: 'isAvailable = 1');
    return res.map(Menu.fromMap).toList();
  }

  Future<void> insertMenu(Menu menu) async {
    final db = await database;
    await db.insert('menus', menu.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMenu(Menu menu) async {
    final db = await database;
    await db.update('menus', menu.toMap(), where: 'id = ?', whereArgs: [menu.id]);
  }

  Future<void> deleteMenu(String id) async {
    final db = await database;
    await db.delete('menus', where: 'id = ?', whereArgs: [id]);
  }

  // Kembalikan stok menu (dipanggil kalau order dibatalkan) — kebalikan dari
  // decrementMenuStock(). Otomatis nyalain lagi menu (isAvailable = true) kalau
  // sebelumnya mati gara-gara stok habis.
  Future<void> restoreMenuStock(String menuId, int qty) async {
    final db = await database;
    final res = await db.query('menus', where: 'id = ?', whereArgs: [menuId]);
    if (res.isEmpty) return;
    final currentStock = (res.first['stock'] as int?) ?? 0;
    final wasUnavailable = (res.first['isAvailable'] as int?) == 0;
    final newStock = currentStock + qty;
    await db.update('menus', {
      'stock': newStock,
      if (wasUnavailable && newStock > 0) 'isAvailable': 1,
    }, where: 'id = ?', whereArgs: [menuId]);
  }

  // ==================== ORDERS ====================
  Future<void> insertOrder(Order order) async {
    final db = await database;
    await db.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Order>> getAllOrders() async {
    final db = await database;
    final res = await db.query('orders', orderBy: 'createdAt DESC');
    return res.map(Order.fromMap).toList();
  }

  Future<Order?> getOrderById(String id) async {
    final db = await database;
    final res = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return res.isEmpty ? null : Order.fromMap(res.first);
  }

  // Customer konfirmasi pesanan via chat sebelum kurir melanjutkan transaksi
  Future<void> confirmOrderByCustomer(String orderId) async {
    final db = await database;
    await db.update('orders', {'customerConfirmed': 1}, where: 'id = ?', whereArgs: [orderId]);
  }

  Future<List<Order>> getOrdersByStore(String storeId) async {
    final db = await database;
    final res = await db.query('orders', where: 'storeId = ?', whereArgs: [storeId], orderBy: 'createdAt DESC');
    return res.map(Order.fromMap).toList();
  }

  Future<List<Order>> getOrdersByMember(String memberId) async {
    final db = await database;
    final res = await db.query('orders', where: 'memberId = ?', whereArgs: [memberId], orderBy: 'createdAt DESC');
    return res.map(Order.fromMap).toList();
  }

  Future<List<Order>> getOrdersByKurir(String kurirId) async {
    final db = await database;
    final res = await db.query('orders', where: "kurirId = ? OR orderStatus IN ('ready','delivering')", whereArgs: [kurirId], orderBy: 'createdAt DESC');
    return res.map(Order.fromMap).toList();
  }

  // Riwayat aktivitas murni milik satu kurir (tanpa ikut pesanan 'ready' milik kurir lain)
  // — dipakai untuk log di Kelola Pengguna.
  Future<List<Order>> getOrderHistoryByKurir(String kurirId) async {
    final db = await database;
    final res = await db.query('orders', where: 'kurirId = ?', whereArgs: [kurirId], orderBy: 'createdAt DESC');
    return res.map(Order.fromMap).toList();
  }

  // Kurangi stok menu pas ada order baru masuk. Stok gak boleh minus (floor di 0),
  // dan kalau habis (0), otomatis nonaktifin menu (isAvailable = false).
  Future<void> decrementMenuStock(String menuId, int qty) async {
    final db = await database;
    final res = await db.query('menus', where: 'id = ?', whereArgs: [menuId]);
    if (res.isEmpty) return;
    final currentStock = (res.first['stock'] as int?) ?? 0;
    final newStock = (currentStock - qty).clamp(0, 1 << 30);
    await db.update('menus', {
      'stock': newStock,
      if (newStock == 0) 'isAvailable': 0,
    }, where: 'id = ?', whereArgs: [menuId]);
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final db = await database;
    await db.update('orders', {'orderStatus': status.name, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [orderId]);
  }

  // Tandai status pembayaran order (mis. dari "pending" jadi "paid"/lunas) —
  // dipanggil admin/superadmin setelah verifikasi transfer/e-wallet/QRIS masuk.
  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) async {
    final db = await database;
    await db.update('orders', {'paymentStatus': status.name, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [orderId]);
  }

  // Simpan path foto bukti pembayaran (transfer/e-wallet/QRIS) yang di-upload customer
  Future<void> updatePaymentProof(String orderId, String proofUrl) async {
    final db = await database;
    await db.update('orders', {'paymentProofUrl': proofUrl, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [orderId]);
  }

  // Terapkan status terbaru dari order-service ke salinan lokal (tanpa menyentuh data lokal
  // seperti foto, koordinat, bukti bayar, konfirmasi chat).
  Future<void> applyRemoteOrderState(String orderId, {
    required OrderStatus orderStatus, required PaymentStatus paymentStatus,
    String? kurirId, String? kurirName, String? kurirPhone,
  }) async {
    final db = await database;
    await db.update('orders', {
      'orderStatus': orderStatus.name, 'paymentStatus': paymentStatus.name,
      if (kurirId != null && kurirId.isNotEmpty) 'kurirId': kurirId,
      if (kurirName != null && kurirName.isNotEmpty) 'kurirName': kurirName,
      if (kurirPhone != null && kurirPhone.isNotEmpty) 'kurirPhone': kurirPhone,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [orderId]);
  }

  Future<void> assignKurir(String orderId, String kurirId, String kurirName, {String kurirPhotoUrl = '', String kurirPhone = ''}) async {
    final db = await database;
    await db.update('orders', {
      'kurirId': kurirId, 'kurirName': kurirName, 'kurirPhotoUrl': kurirPhotoUrl, 'kurirPhone': kurirPhone,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [orderId]);
  }

  // ==================== VOUCHERS ====================
  Future<List<Voucher>> getVouchersByStore(String storeId) async {
    final db = await database;
    final res = await db.query('vouchers', where: 'storeId = ?', whereArgs: [storeId], orderBy: 'createdAt DESC');
    return res.map(Voucher.fromMap).toList();
  }

  Future<List<Voucher>> getAllVouchers() async {
    final db = await database;
    final res = await db.query('vouchers', orderBy: 'createdAt DESC');
    return res.map(Voucher.fromMap).toList();
  }

  Future<void> insertVoucher(Voucher v) async {
    final db = await database;
    await db.insert('vouchers', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateVoucher(Voucher v) async {
    final db = await database;
    await db.update('vouchers', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  Future<void> deleteVoucher(String id) async {
    final db = await database;
    await db.delete('vouchers', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== ADMIN SETTINGS ====================
  Future<String?> getAdminSetting(String key) async {
    final db = await database;
    try {
      final res = await db.query('admin_settings', where: 'key = ?', whereArgs: [key]);
      return res.isEmpty ? null : res.first['value'] as String?;
    } catch (_) { return null; }
  }

  Future<void> setAdminSetting(String key, String value) async {
    final db = await database;
    await db.insert('admin_settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==================== REVIEWS ====================
  Future<void> createReviewTable() async {
    final db = await database;
    await db.execute('''CREATE TABLE IF NOT EXISTS reviews (
      id TEXT PRIMARY KEY, orderId TEXT, memberId TEXT, memberName TEXT,
      targetId TEXT, targetName TEXT, target TEXT, rating INTEGER,
      comment TEXT, photoUrls TEXT, memberPhotoUrl TEXT DEFAULT '', createdAt INTEGER
    )''');
  }

  Future<void> insertReview(Review review) async {
    await createReviewTable();
    final db = await database;
    await db.insert('reviews', review.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Review>> getReviewsByTarget(String targetId) async {
    await createReviewTable();
    final db = await database;
    final res = await db.query('reviews', where: 'targetId = ?', whereArgs: [targetId], orderBy: 'createdAt DESC');
    return res.map(Review.fromMap).toList();
  }

  Future<List<Review>> getReviewsByOrder(String orderId) async {
    await createReviewTable();
    final db = await database;
    final res = await db.query('reviews', where: 'orderId = ?', whereArgs: [orderId]);
    return res.map(Review.fromMap).toList();
  }

  Future<List<Review>> getReviewsByMember(String memberId) async {
    await createReviewTable();
    final db = await database;
    final res = await db.query('reviews', where: 'memberId = ?', whereArgs: [memberId], orderBy: 'createdAt DESC');
    return res.map(Review.fromMap).toList();
  }

  Future<double> getAverageRating(String targetId) async {
    await createReviewTable();
    final db = await database;
    final res = await db.rawQuery('SELECT AVG(rating) as avg FROM reviews WHERE targetId = ?', [targetId]);
    return (res.first['avg'] as double?) ?? 0.0;
  }

  // ==================== CHAT ====================
  Future<void> _ensureChatTable() async {
    final db = await database;
    await db.execute('''CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY, orderId TEXT, senderName TEXT,
      isKurir INTEGER, message TEXT, imageUrl TEXT, createdAt INTEGER,
      isRead INTEGER DEFAULT 0, audioUrl TEXT DEFAULT '', audioDurationMs INTEGER DEFAULT 0
    )''');
  }

  Future<void> insertChatMessage(ChatMessage msg) async {
    await _ensureChatTable();
    final db = await database;
    await db.insert('chat_messages', msg.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChatMessage>> getChatMessages(String orderId) async {
    await _ensureChatTable();
    final db = await database;
    final res = await db.query('chat_messages', where: 'orderId = ?', whereArgs: [orderId], orderBy: 'createdAt ASC');
    return res.map(ChatMessage.fromMap).toList();
  }

  Future<int> getUnreadCount(String orderId, bool isKurir) async {
    await _ensureChatTable();
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM chat_messages WHERE orderId = ? AND isKurir != ?', [orderId, isKurir ? 1 : 0]);
    return (res.first['cnt'] as int?) ?? 0;
  }

  // Tandai pesan dari LAWAN bicara sebagai sudah dibaca, dipanggil pas
  // pengguna membuka/melihat chat. readerIsKurir = true kalau yang buka chat kurir
  // (maka pesan dari member/pembeli yang ditandai terbaca), dan sebaliknya.
  Future<void> markMessagesAsRead(String orderId, {required bool readerIsKurir}) async {
    await _ensureChatTable();
    final db = await database;
    await db.update(
      'chat_messages',
      {'isRead': 1},
      where: 'orderId = ? AND isKurir = ? AND isRead = 0',
      whereArgs: [orderId, readerIsKurir ? 0 : 1],
    );
  }
}
