# 🍜 Mie Pedas App - Flutter Multi-Platform

Aplikasi pemesanan Mie Pedas yang mendukung **Android, iOS, Windows, dan macOS**.

---

## ✅ Fitur Lengkap

### 👤 Member
- Login & Register akun baru
- Halaman Home dengan banner promo & menu best seller
- Daftar menu lengkap dengan filter kategori & pencarian
- Detail menu: pilih tingkat pedas, jumlah, catatan
- Keranjang belanja
- Checkout dengan pilihan metode pembayaran (Tunai / Transfer / E-Wallet)
- Riwayat pesanan

### ⚙️ Admin
- Dashboard statistik (total pesanan, pendapatan, dll)
- Kelola pesanan (ubah status)
- Kelola menu (tambah, edit, hapus)
- Daftar pengguna (Member, Kurir, Admin)

### 🛵 Kurir
- Lihat pesanan siap diambil
- Ambil pesanan & tandai terkirim
- Panel pengantaran aktif

### 🔐 Demo Login (Tanpa Daftar)
| Role | Email | Password |
|------|-------|----------|
| Member | member@demo.com | demo123 |
| Kurir | kurir@demo.com | demo123 |
| Admin | admin@demo.com | demo123 |

---

## 🚀 Cara Setup & Menjalankan

### Prasyarat
- **Flutter SDK** versi 3.10.0 ke atas → https://docs.flutter.dev/get-started/install
- **Android Studio** (untuk Android & emulator)
- **Xcode** (untuk iOS & macOS — hanya di Mac)
- **VS Build Tools** (untuk Windows)

---

### 1. Clone / Extract Project
```bash
# Ekstrak folder ini, lalu masuk ke dalamnya
cd mie_pedas_app
```

### 2. Generate Platform Folders
```bash
flutter create --platforms=android,ios,windows,macos .
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Jalankan Sesuai Platform

#### 📱 Android
```bash
# Pastikan emulator berjalan atau HP terhubung
flutter run -d android
```

#### 🍎 iOS (hanya di Mac)
```bash
flutter run -d ios
```

#### 🪟 Windows
```bash
flutter run -d windows
```

#### 💻 macOS (hanya di Mac)
```bash
flutter run -d macos
```

---

### 5. Build Release (APK / EXE / IPA)

#### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Windows EXE
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

#### iOS (Mac only)
```bash
flutter build ios --release
```

#### macOS (Mac only)
```bash
flutter build macos --release
```

---

## 📁 Struktur Project

```
lib/
├── main.dart                  # Entry point + Splash screen
├── models/
│   └── models.dart            # Semua data model (User, Menu, Order, dll)
├── providers/
│   └── providers.dart         # State management (Auth, Menu, Cart, Order)
├── utils/
│   ├── theme.dart             # Tema & warna
│   ├── utils.dart             # Helper functions (format rupiah, dll)
│   └── database_helper.dart   # SQLite (local database)
├── widgets/
│   └── widgets.dart           # Widget reusable (MenuCard, EmptyState, dll)
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── member/
    │   ├── member_main.dart
    │   ├── home_tab.dart
    │   ├── menu_tab.dart
    │   ├── orders_tab.dart
    │   ├── profile_tab.dart
    │   ├── detail_menu_screen.dart
    │   ├── cart_screen.dart
    │   └── checkout_screen.dart
    ├── admin/
    │   ├── admin_main.dart
    │   ├── admin_dashboard_tab.dart
    │   ├── admin_orders_tab.dart
    │   ├── admin_menu_tab.dart
    │   └── admin_users_tab.dart
    └── kurir/
        └── kurir_main.dart
```

---

## 🛠️ Teknologi

| Teknologi | Kegunaan |
|-----------|----------|
| Flutter | UI Framework cross-platform |
| Provider | State Management |
| SQLite (sqflite) | Database lokal |
| SharedPreferences | Simpan sesi login |
| Google Fonts | Tipografi (Poppins) |

---

## ⚠️ Catatan Penting

- App ini menggunakan **local storage (SQLite)** — tidak butuh backend/internet
- Data tersimpan di perangkat masing-masing
- Jika ingin multi-device sync, perlu ditambahkan backend (Firebase / REST API)

---

## 📞 Kontak & Dukungan
Dibuat dengan ❤️ menggunakan Flutter untuk usaha Mie Pedas.
