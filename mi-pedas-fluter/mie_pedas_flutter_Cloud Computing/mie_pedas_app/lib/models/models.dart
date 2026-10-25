// lib/models/models.dart

enum UserRole { member, kurir, admin, superadmin }
enum MenuCategory { semua, original, extraPedas, seafood, spesial, minuman }
enum OrderStatus { pending, processing, ready, delivering, delivered, done, cancelled }
enum PaymentMethod { cash, transfer, ewallet, qris }
enum PaymentStatus { pending, paid, failed, refunded }
enum DiscountType { percentage, nominal }
enum StoreStatus { active, suspended, pending }

// ==================== STORE (UMKM) ====================
// Daftar bank buat dropdown pilihan admin toko saat daftar/isi rekening —
// biar gak dihardcode ke satu bank aja.
const List<String> indonesianBanks = [
  'BCA', 'BRI', 'BNI', 'Mandiri', 'CIMB Niaga', 'Danamon', 'Permata',
  'BTN', 'BSI', 'BJB', 'OCBC NISP', 'Maybank Indonesia', 'Panin Bank',
  'UOB Indonesia', 'Bank Lainnya',
];

class Store {
  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String ownerName;
  final String adminEmail;
  String adminUsername;
  String adminPassword;
  final String logoUrl;
  StoreStatus status;
  final bool isSelfRegistered;
  final int createdAt;
  // Rekening & dokumen legalitas
  final String bankAccountNumber; // no. rekening
  final String bankAccountName;   // nama pemilik rekening
  final String bankName;          // nama bank (BCA/BRI/Mandiri/dst — dipilih admin toko)
  final String ktpUrl;            // path foto KTP pemilik
  final String storefrontPhotoUrl; // path foto resto tampak depan
  final String qrisImageUrl;      // path foto QRIS asli UMKM (buat pembayaran)
  // Nomer e-wallet toko (opsional, isi kalau toko punya) — dipakai saat
  // customer pilih metode pembayaran E-Wallet di checkout.
  final String gopayNumber;
  final String ovoNumber;
  final String danaNumber;
  final double commissionRate;    // persen potongan admin (mis. 10 = 10%)
  final double latitude;          // koordinat resto (untuk GPS 3 titik)
  final double longitude;

  bool get hasLocation => latitude != 0 && longitude != 0;
  bool get hasAnyEwallet => gopayNumber.isNotEmpty || ovoNumber.isNotEmpty || danaNumber.isNotEmpty;

  Store({
    required this.id,
    required this.name,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.ownerName = '',
    required this.adminEmail,
    this.adminUsername = 'admin',
    this.adminPassword = 'admin123',
    this.logoUrl = '',
    this.status = StoreStatus.active,
    this.isSelfRegistered = false,
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.bankName = '',
    this.ktpUrl = '',
    this.storefrontPhotoUrl = '',
    this.qrisImageUrl = '',
    this.gopayNumber = '',
    this.ovoNumber = '',
    this.danaNumber = '',
    this.commissionRate = 10.0,
    this.latitude = 0,
    this.longitude = 0,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get isActive => status == StoreStatus.active;

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'description': description, 'address': address,
    'phone': phone, 'ownerName': ownerName, 'adminEmail': adminEmail,
    'adminUsername': adminUsername, 'adminPassword': adminPassword,
    'logoUrl': logoUrl, 'status': status.name,
    'isSelfRegistered': isSelfRegistered ? 1 : 0, 'createdAt': createdAt,
    'bankAccountNumber': bankAccountNumber, 'bankAccountName': bankAccountName,
    'bankName': bankName,
    'ktpUrl': ktpUrl, 'storefrontPhotoUrl': storefrontPhotoUrl,
    'qrisImageUrl': qrisImageUrl,
    'gopayNumber': gopayNumber, 'ovoNumber': ovoNumber, 'danaNumber': danaNumber,
    'commissionRate': commissionRate,
    'latitude': latitude, 'longitude': longitude,
  };

  factory Store.fromMap(Map<String, dynamic> m) => Store(
    id: m['id'], name: m['name'], description: m['description'] ?? '',
    address: m['address'] ?? '', phone: m['phone'] ?? '',
    ownerName: m['ownerName'] ?? '', adminEmail: m['adminEmail'] ?? '',
    adminUsername: m['adminUsername'] ?? 'admin',
    adminPassword: m['adminPassword'] ?? 'admin123',
    logoUrl: m['logoUrl'] ?? '',
    status: StoreStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => StoreStatus.active),
    isSelfRegistered: (m['isSelfRegistered'] ?? 0) == 1,
    createdAt: m['createdAt'],
    bankAccountNumber: m['bankAccountNumber'] ?? '',
    bankAccountName: m['bankAccountName'] ?? '',
    bankName: m['bankName'] ?? '',
    ktpUrl: m['ktpUrl'] ?? '',
    storefrontPhotoUrl: m['storefrontPhotoUrl'] ?? '',
    qrisImageUrl: m['qrisImageUrl'] ?? '',
    gopayNumber: m['gopayNumber'] ?? '',
    ovoNumber: m['ovoNumber'] ?? '',
    danaNumber: m['danaNumber'] ?? '',
    commissionRate: (m['commissionRate'] as num? ?? 10.0).toDouble(),
    latitude: (m['latitude'] as num? ?? 0).toDouble(),
    longitude: (m['longitude'] as num? ?? 0).toDouble(),
  );
}

// ==================== USER ====================
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final UserRole role;
  final String photoUrl;
  final bool isActive;
  final String storeId; // untuk admin UMKM
  final int createdAt;
  // Data khusus kurir (rekening penyetoran & dokumen kendaraan)
  final String withdrawMethod;        // 'dana' atau 'bri'
  final String withdrawAccountNumber; // no. e-wallet DANA atau rekening BRI
  final String plateNumber;           // nomor plat kendaraan
  final String ktpUrl;                // path foto KTP
  final String stnkUrl;               // path foto STNK
  final double? homeLat;              // koordinat rumah member (untuk navigasi presisi)
  final double? homeLng;

  User({
    required this.id, required this.name, required this.email,
    this.phone = '', this.address = '', this.role = UserRole.member,
    this.photoUrl = '', this.isActive = true, this.storeId = '',
    this.withdrawMethod = '', this.withdrawAccountNumber = '',
    this.plateNumber = '', this.ktpUrl = '', this.stnkUrl = '',
    this.homeLat, this.homeLng,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get hasHomeLocation => homeLat != null && homeLng != null;

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'phone': phone,
    'address': address, 'role': role.name, 'photoUrl': photoUrl,
    'isActive': isActive ? 1 : 0, 'storeId': storeId, 'createdAt': createdAt,
    'withdrawMethod': withdrawMethod, 'withdrawAccountNumber': withdrawAccountNumber,
    'plateNumber': plateNumber, 'ktpUrl': ktpUrl, 'stnkUrl': stnkUrl,
    'homeLat': homeLat, 'homeLng': homeLng,
  };

  factory User.fromMap(Map<String, dynamic> m) => User(
    id: m['id'], name: m['name'], email: m['email'],
    phone: m['phone'] ?? '', address: m['address'] ?? '',
    role: UserRole.values.firstWhere((r) => r.name == m['role'], orElse: () => UserRole.member),
    photoUrl: m['photoUrl'] ?? '', isActive: (m['isActive'] ?? 1) == 1,
    storeId: m['storeId'] ?? '', createdAt: m['createdAt'],
    withdrawMethod: m['withdrawMethod'] ?? '', withdrawAccountNumber: m['withdrawAccountNumber'] ?? '',
    plateNumber: m['plateNumber'] ?? '', ktpUrl: m['ktpUrl'] ?? '', stnkUrl: m['stnkUrl'] ?? '',
    homeLat: (m['homeLat'] as num?)?.toDouble(), homeLng: (m['homeLng'] as num?)?.toDouble(),
  );
}

// Kategori dulu tersimpan sebagai nama enum ('original', 'extraPedas', dst).
// Sekarang kategori bebas diisi teks apa saja oleh admin, tapi data lama di
// database masih dalam format nama enum tsb — helper ini menerjemahkannya
// jadi teks yang enak dibaca, dan membiarkan kategori baru (teks bebas) apa adanya.
String _prettyLegacyCategory(String? raw) {
  switch (raw) {
    case 'semua': return 'Semua';
    case 'original': return 'Original';
    case 'extraPedas': return 'Extra Pedas';
    case 'seafood': return 'Seafood';
    case 'spesial': return 'Spesial';
    case 'minuman': return 'Minuman';
    default: return (raw == null || raw.isEmpty) ? 'Original' : raw;
  }
}

// ==================== MENU ====================
class Menu {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final int spicyLevel;
  final double rating;
  final int totalReviews;
  final int stock;
  final bool isAvailable;
  final bool isBestSeller;
  final bool isNew;
  final int createdAt;

  Menu({
    required this.id, this.storeId = 'default',
    required this.name, required this.description, required this.price,
    this.imageUrl = '', this.category = 'Original',
    this.spicyLevel = 1, this.rating = 0, this.totalReviews = 0,
    this.stock = 0, this.isAvailable = true, this.isBestSeller = false,
    this.isNew = false, int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Menu copyWithStock(int newStock) => Menu(
    id: id, storeId: storeId, name: name, description: description, price: price,
    imageUrl: imageUrl, category: category, spicyLevel: spicyLevel, rating: rating,
    totalReviews: totalReviews, stock: newStock, isAvailable: isAvailable,
    isBestSeller: isBestSeller, isNew: isNew, createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'storeId': storeId, 'name': name, 'description': description,
    'price': price, 'imageUrl': imageUrl, 'category': category,
    'spicyLevel': spicyLevel, 'rating': rating, 'totalReviews': totalReviews,
    'stock': stock, 'isAvailable': isAvailable ? 1 : 0,
    'isBestSeller': isBestSeller ? 1 : 0, 'isNew': isNew ? 1 : 0, 'createdAt': createdAt,
  };

  factory Menu.fromMap(Map<String, dynamic> m) => Menu(
    id: m['id'], storeId: m['storeId'] ?? 'default', name: m['name'],
    description: m['description'], price: (m['price'] as num).toDouble(),
    imageUrl: m['imageUrl'] ?? '',
    category: _prettyLegacyCategory(m['category']),
    spicyLevel: m['spicyLevel'] ?? 1, rating: (m['rating'] ?? 0).toDouble(),
    totalReviews: m['totalReviews'] ?? 0, stock: m['stock'] ?? 0,
    isAvailable: (m['isAvailable'] ?? 1) == 1, isBestSeller: (m['isBestSeller'] ?? 0) == 1,
    isNew: (m['isNew'] ?? 0) == 1, createdAt: m['createdAt'],
  );
}

// ==================== CART ITEM ====================
class CartItem {
  final Menu menu;
  int quantity;
  int spicyLevel;
  String note;
  final int addedAt;

  CartItem({required this.menu, this.quantity = 1, int? spicyLevel, this.note = '', int? addedAt})
      : spicyLevel = spicyLevel ?? menu.spicyLevel,
        addedAt = addedAt ?? DateTime.now().millisecondsSinceEpoch;

  double get subtotal => menu.price * quantity;
}

// ==================== ORDER ====================
class Order {
  final String id;
  final String storeId;
  final String memberId;
  final String memberName;
  final String memberPhone;
  String kurirId;
  String kurirName;
  final String deliveryAddress;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  PaymentStatus paymentStatus;
  OrderStatus orderStatus;
  final String orderNote;
  final int estimatedTime;
  final int createdAt;
  int updatedAt;
  final String promoCode;
  // Untuk tampilan foto resto di kurir & GPS 3 titik
  final String storeName;
  final String storePhotoUrl;
  final String memberPhotoUrl; // foto profil customer, biar admin/kurir/superadmin bisa lihat
  String kurirPhotoUrl; // foto profil kurir, biar member/admin/superadmin bisa lihat
  String kurirPhone; // nomor telepon kurir, buat fitur telepon di chat
  final double customerLat;
  final double customerLng;
  bool customerConfirmed; // customer sudah konfirmasi via chat sebelum kurir lanjut
  String paymentProofUrl; // foto bukti transfer/e-wallet/QRIS dari customer saat checkout

  bool get hasCustomerLocation => customerLat != 0 && customerLng != 0;

  Order({
    required this.id, this.storeId = 'default',
    required this.memberId, required this.memberName, this.memberPhone = '',
    this.kurirId = '', this.kurirName = '', required this.deliveryAddress,
    required this.items, required this.subtotal, required this.deliveryFee,
    this.discount = 0, required this.totalAmount,
    this.paymentMethod = PaymentMethod.cash, this.paymentStatus = PaymentStatus.pending,
    this.orderStatus = OrderStatus.pending, this.orderNote = '',
    this.estimatedTime = 30, this.promoCode = '',
    this.storeName = '', this.storePhotoUrl = '', this.memberPhotoUrl = '',
    this.kurirPhotoUrl = '', this.kurirPhone = '',
    this.customerLat = 0, this.customerLng = 0,
    this.customerConfirmed = false,
    this.paymentProofUrl = '',
    int? createdAt, int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'id': id, 'storeId': storeId, 'memberId': memberId, 'memberName': memberName,
    'memberPhone': memberPhone, 'kurirId': kurirId, 'kurirName': kurirName,
    'deliveryAddress': deliveryAddress,
    'itemsJson': items.map((i) => '${i.menuName}|${i.quantity}|${i.price}|${i.spicyLevel}|${i.note}').join(';;'),
    'subtotal': subtotal, 'deliveryFee': deliveryFee, 'discount': discount,
    'totalAmount': totalAmount, 'paymentMethod': paymentMethod.name,
    'paymentStatus': paymentStatus.name, 'orderStatus': orderStatus.name,
    'orderNote': orderNote, 'estimatedTime': estimatedTime, 'promoCode': promoCode,
    'createdAt': createdAt, 'updatedAt': updatedAt,
    'storeName': storeName, 'storePhotoUrl': storePhotoUrl, 'memberPhotoUrl': memberPhotoUrl,
    'kurirPhotoUrl': kurirPhotoUrl, 'kurirPhone': kurirPhone,
    'customerLat': customerLat, 'customerLng': customerLng,
    'customerConfirmed': customerConfirmed ? 1 : 0,
    'paymentProofUrl': paymentProofUrl,
  };

  factory Order.fromMap(Map<String, dynamic> m) {
    final itemsRaw = (m['itemsJson'] as String?) ?? '';
    final items = itemsRaw.isEmpty ? <OrderItem>[] : itemsRaw.split(';;').map((s) {
      final parts = s.split('|');
      return OrderItem(menuId: '', menuName: parts[0], price: double.tryParse(parts[2]) ?? 0,
        quantity: int.tryParse(parts[1]) ?? 1, spicyLevel: int.tryParse(parts[3]) ?? 1,
        note: parts.length > 4 ? parts[4] : '');
    }).toList();
    return Order(
      id: m['id'], storeId: m['storeId'] ?? 'default', memberId: m['memberId'],
      memberName: m['memberName'], memberPhone: m['memberPhone'] ?? '',
      kurirId: m['kurirId'] ?? '', kurirName: m['kurirName'] ?? '',
      deliveryAddress: m['deliveryAddress'], items: items,
      subtotal: (m['subtotal'] as num).toDouble(), deliveryFee: (m['deliveryFee'] as num).toDouble(),
      discount: (m['discount'] as num? ?? 0).toDouble(), totalAmount: (m['totalAmount'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere((p) => p.name == m['paymentMethod'], orElse: () => PaymentMethod.cash),
      paymentStatus: PaymentStatus.values.firstWhere((p) => p.name == m['paymentStatus'], orElse: () => PaymentStatus.pending),
      orderStatus: OrderStatus.values.firstWhere((o) => o.name == m['orderStatus'], orElse: () => OrderStatus.pending),
      orderNote: m['orderNote'] ?? '', estimatedTime: m['estimatedTime'] ?? 30,
      promoCode: m['promoCode'] ?? '', createdAt: m['createdAt'], updatedAt: m['updatedAt'],
      storeName: m['storeName'] ?? '', storePhotoUrl: m['storePhotoUrl'] ?? '',
      memberPhotoUrl: m['memberPhotoUrl'] ?? '',
      kurirPhotoUrl: m['kurirPhotoUrl'] ?? '', kurirPhone: m['kurirPhone'] ?? '',
      customerLat: (m['customerLat'] as num? ?? 0).toDouble(),
      customerLng: (m['customerLng'] as num? ?? 0).toDouble(),
      customerConfirmed: (m['customerConfirmed'] ?? 0) == 1,
      paymentProofUrl: m['paymentProofUrl'] ?? '',
    );
  }
}

class OrderItem {
  final String menuId;
  final String menuName;
  final double price;
  final int quantity;
  final int spicyLevel;
  final String note;
  const OrderItem({required this.menuId, required this.menuName, required this.price, required this.quantity, this.spicyLevel = 1, this.note = ''});
  double get subtotal => price * quantity;
}

// ==================== VOUCHER ====================
class Voucher {
  final String id;
  final String storeId;
  final String code;
  final String description;
  final DiscountType type;
  final double value;
  final double minOrder;
  final double maxDiscount;
  final int quota;
  int usedCount;
  final bool isActive;
  final bool isAutomatic;
  final String autoTrigger;
  final int expiredAt;
  final int createdAt;

  Voucher({
    required this.id, this.storeId = 'default', required this.code,
    required this.description, required this.type, required this.value,
    this.minOrder = 0, this.maxDiscount = 0, this.quota = 100, this.usedCount = 0,
    this.isActive = true, this.isAutomatic = false, this.autoTrigger = '',
    int? expiredAt, int? createdAt,
  })  : expiredAt = expiredAt ?? DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiredAt;
  bool get isAvailable => isActive && !isExpired && (quota == 0 || usedCount < quota);

  double calculateDiscount(double orderTotal) {
    if (!isAvailable || orderTotal < minOrder) return 0;
    if (type == DiscountType.percentage) {
      final disc = orderTotal * (value / 100);
      return maxDiscount > 0 ? (disc > maxDiscount ? maxDiscount : disc) : disc;
    }
    return value;
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'storeId': storeId, 'code': code, 'description': description,
    'type': type.name, 'value': value, 'minOrder': minOrder, 'maxDiscount': maxDiscount,
    'quota': quota, 'usedCount': usedCount, 'isActive': isActive ? 1 : 0,
    'isAutomatic': isAutomatic ? 1 : 0, 'autoTrigger': autoTrigger,
    'expiredAt': expiredAt, 'createdAt': createdAt,
  };

  factory Voucher.fromMap(Map<String, dynamic> m) => Voucher(
    id: m['id'], storeId: m['storeId'] ?? 'default', code: m['code'],
    description: m['description'],
    type: DiscountType.values.firstWhere((t) => t.name == m['type'], orElse: () => DiscountType.nominal),
    value: (m['value'] as num).toDouble(), minOrder: (m['minOrder'] as num? ?? 0).toDouble(),
    maxDiscount: (m['maxDiscount'] as num? ?? 0).toDouble(), quota: m['quota'] ?? 100,
    usedCount: m['usedCount'] ?? 0, isActive: (m['isActive'] ?? 1) == 1,
    isAutomatic: (m['isAutomatic'] ?? 0) == 1, autoTrigger: m['autoTrigger'] ?? '',
    expiredAt: m['expiredAt'], createdAt: m['createdAt'],
  );
}

// ==================== DUMMY DATA ====================
List<Menu> getDummyMenus({String storeId = 'store_joara'}) => [
  Menu(id: '1', storeId: storeId, name: 'Mie Pedas Level 1', description: 'Mie lembut dengan bumbu pedas ringan', price: 15000, category: 'Original', spicyLevel: 1, rating: 4.5, totalReviews: 120, stock: 50),
  Menu(id: '2', storeId: storeId, name: 'Mie Pedas Level 2', description: 'Sedikit lebih pedas, cocok sehari-hari', price: 16000, category: 'Original', spicyLevel: 2, rating: 4.6, totalReviews: 200, stock: 45),
  Menu(id: '3', storeId: storeId, name: 'Mie Pedas Level 3', description: 'Pedas pas untuk pecinta mie', price: 18000, category: 'Original', spicyLevel: 3, rating: 4.8, totalReviews: 350, stock: 40, isBestSeller: true),
  Menu(id: '4', storeId: storeId, name: 'Mie Extra Pedas Level 4', description: 'Sangat pedas, hati-hati!', price: 20000, category: 'Extra Pedas', spicyLevel: 4, rating: 4.7, totalReviews: 280, stock: 30, isBestSeller: true),
  Menu(id: '5', storeId: storeId, name: 'Mie Extra Pedas Level 5', description: 'Tantangan pedas terdahsyat!', price: 22000, category: 'Extra Pedas', spicyLevel: 5, rating: 4.9, totalReviews: 500, stock: 25, isBestSeller: true),
  Menu(id: '6', storeId: storeId, name: 'Mie Seafood Spesial', description: 'Mie dengan topping seafood segar', price: 28000, category: 'Seafood', spicyLevel: 3, rating: 4.7, totalReviews: 200, stock: 20),
  Menu(id: '7', storeId: storeId, name: 'Mie Kepiting Pedas', description: 'Mie dengan daging kepiting asli', price: 35000, category: 'Seafood', spicyLevel: 3, rating: 4.8, totalReviews: 150, stock: 15, isNew: true),
  Menu(id: '8', storeId: storeId, name: 'Mie Pedas Keju', description: 'Kombinasi unik pedas dan keju leleh', price: 20000, category: 'Spesial', spicyLevel: 2, rating: 4.6, totalReviews: 180, stock: 35, isNew: true),
  Menu(id: '9', storeId: storeId, name: 'Mie Pedas Bakso', description: 'Mie pedas dengan bakso sapi premium', price: 23000, category: 'Spesial', spicyLevel: 3, rating: 4.8, totalReviews: 250, stock: 30, isBestSeller: true),
  Menu(id: '10', storeId: storeId, name: 'Es Teh Manis', description: 'Teh manis dingin menyegarkan', price: 8000, category: 'Minuman', spicyLevel: 0, rating: 4.5, totalReviews: 300, stock: 100),
  Menu(id: '11', storeId: storeId, name: 'Es Jeruk Peras', description: 'Jeruk segar diperas langsung', price: 10000, category: 'Minuman', spicyLevel: 0, rating: 4.6, totalReviews: 200, stock: 80),
  Menu(id: '12', storeId: storeId, name: 'Air Mineral', description: 'Air mineral dingin', price: 5000, category: 'Minuman', spicyLevel: 0, rating: 4.3, totalReviews: 500, stock: 200),
];

// ==================== REVIEW ====================
enum ReviewTarget { store, kurir }

class Review {
  final String id;
  final String orderId;
  final String memberId;
  final String memberName;
  final String targetId; // storeId atau kurirId
  final String targetName;
  final ReviewTarget target;
  final int rating; // 1-5
  final String comment;
  final List<String> photoUrls; // path foto lokal
  final String memberPhotoUrl; // foto profil pembeli yang kasih ulasan
  final int createdAt;

  Review({
    required this.id,
    required this.orderId,
    required this.memberId,
    required this.memberName,
    required this.targetId,
    required this.targetName,
    required this.target,
    required this.rating,
    this.comment = '',
    this.photoUrls = const [],
    this.memberPhotoUrl = '',
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'id': id, 'orderId': orderId, 'memberId': memberId, 'memberName': memberName,
    'targetId': targetId, 'targetName': targetName, 'target': target.name,
    'rating': rating, 'comment': comment,
    'photoUrls': photoUrls.join('||'),
    'memberPhotoUrl': memberPhotoUrl,
    'createdAt': createdAt,
  };

  factory Review.fromMap(Map<String, dynamic> m) => Review(
    id: m['id'], orderId: m['orderId'], memberId: m['memberId'],
    memberName: m['memberName'], targetId: m['targetId'], targetName: m['targetName'],
    target: ReviewTarget.values.firstWhere((t) => t.name == m['target'], orElse: () => ReviewTarget.store),
    rating: m['rating'], comment: m['comment'] ?? '',
    photoUrls: (m['photoUrls'] as String? ?? '').isEmpty ? [] : (m['photoUrls'] as String).split('||'),
    memberPhotoUrl: m['memberPhotoUrl'] ?? '',
    createdAt: m['createdAt'],
  );
}

// ==================== LAPORAN KOMISI RESTO ====================
class StoreCommissionReport {
  final Store store;
  final int totalOrders;
  final double totalSubtotal;    // total harga produk (basis potongan admin)
  final double totalDeliveryFee; // total ongkir (bukan hak resto)
  final double totalRevenue;     // subtotal + ongkir - diskon (nilai transaksi)
  final double adminFee;         // potongan admin dari subtotal
  final double netForStore;      // subtotal - adminFee (yang diterima resto)
  final List<Order> orders;

  StoreCommissionReport({
    required this.store,
    required this.totalOrders,
    required this.totalSubtotal,
    required this.totalDeliveryFee,
    required this.totalRevenue,
    required this.adminFee,
    required this.netForStore,
    required this.orders,
  });
}

// ==================== CHAT MESSAGE ====================
class ChatMessage {
  final String id;
  final String orderId;
  final String senderName;
  final bool isKurir;
  final String message;
  final String imageUrl;
  final String audioUrl;
  final int audioDurationMs;
  final int createdAt;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderName,
    required this.isKurir,
    required this.message,
    this.imageUrl = '',
    this.audioUrl = '',
    this.audioDurationMs = 0,
    this.isRead = false,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'id': id, 'orderId': orderId, 'senderName': senderName,
    'isKurir': isKurir ? 1 : 0, 'message': message,
    'imageUrl': imageUrl, 'audioUrl': audioUrl, 'audioDurationMs': audioDurationMs,
    'createdAt': createdAt, 'isRead': isRead ? 1 : 0,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'], orderId: m['orderId'], senderName: m['senderName'],
    isKurir: (m['isKurir'] ?? 0) == 1, message: m['message'] ?? '',
    imageUrl: m['imageUrl'] ?? '', audioUrl: m['audioUrl'] ?? '',
    audioDurationMs: m['audioDurationMs'] ?? 0,
    createdAt: m['createdAt'],
    isRead: (m['isRead'] ?? 0) == 1,
  );
}
