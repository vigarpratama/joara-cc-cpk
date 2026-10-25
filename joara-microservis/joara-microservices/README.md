# Joara Delivery — Microservice

Backend Joara dipecah jadi **3 layanan**, masing-masing jalan di **container sendiri** dan punya **database PostgreSQL sendiri** (container terpisah).

```
                     Aplikasi Flutter
              ┌──────────┼───────────┐
              ▼          ▼           ▼
        user-service  order-service  payment-service
          :3001         :3002          :3003
              │          │   ▲          │
              ▼          ▼   └──────────┤ (internal, x-internal-key)
          user-db     order-db       payment-db
        joara_users  joara_orders   joara_payments
```

| Layanan | Tugas | Database |
|---|---|---|
| user-service | daftar, login (JWT), profil | `joara_users` (tabel `users`) |
| order-service | pesanan: **order id, waktu, nominal**, status, alamat, item | `joara_orders` (tabel `orders`) |
| payment-service | **generate QRIS**, terima webhook, update status lunas | `joara_payments` (tabel `payments`) |

Layanan tidak saling membaca database. payment-service meminta data pesanan ke order-service lewat HTTP, dan memberi tahu order-service kalau pembayaran lunas lewat endpoint internal yang dilindungi `INTERNAL_KEY`.

## Menjalankan
```bash
cp .env.example .env      # ganti JWT_SECRET, INTERNAL_KEY, DB_PASSWORD
docker compose up --build
bash scripts/smoke-test.sh   # tes alur: daftar -> pesan -> QRIS -> bayar -> lunas
```
Tanpa Docker (pakai npm): di tiap folder layanan jalankan `npm install` lalu `npm start`, dengan environment `DATABASE_URL`, `JWT_SECRET`, `INTERNAL_KEY` (dan `ORDER_SERVICE_URL` untuk payment-service).

## Endpoint
**user-service (3001)**
- `POST /auth/register` `{name,email,phone,password,role}` (role: member/kurir) → `{token,user}`
- `POST /auth/login` `{email,password}` → `{token,user}`
- `GET /users/me`, `GET /users/:id` (header `Authorization: Bearer <token>`)

**order-service (3002)**
- `POST /orders` (member) `{storeId,storeName,deliveryAddress,paymentMethod,deliveryFee,discount,items:[{menuId,menuName,price,quantity}]}` → `{orderId,createdAt,totalAmount,...}`. Nominal dihitung ulang di server.
- `GET /orders` (member: miliknya · admin: `?storeId=` · kurir: `?status=ready` · superadmin: semua)
- `GET /orders/:id`
- `PATCH /orders/:id/status` (admin/kurir/superadmin) · `PATCH /orders/:id/assign` (kurir) · `PATCH /orders/:id/mark-paid` (admin/superadmin)

**payment-service (3003)**
- `POST /payments/qris` `{orderId}` → `{paymentId,qrString,qrUrl,amount,expiresAt,status}`
- `GET /payments/order/:orderId`
- `POST /payments/webhook/midtrans` (URL notifikasi untuk dashboard Midtrans, signature SHA-512 diverifikasi)
- `POST /payments/:id/mock-pay` (hanya mode mock, untuk demo)

## QRIS dan rekening
`PAYMENT_PROVIDER` di `.env`:
- `mock` (default): QRIS tiruan untuk demo/tes, tanpa akun apa pun.
- `midtrans`: QRIS asli lewat Midtrans. Isi `MIDTRANS_SERVER_KEY`. Pakai `MIDTRANS_BASE_URL=https://api.sandbox.midtrans.com` untuk uji coba (uang tidak sungguhan). Untuk uang sungguhan, daftar akun merchant Midtrans, lengkapi verifikasinya, isi nomor rekening kamu di dashboard, lalu pakai server key production dan `https://api.midtrans.com`. Dana pembayaran di-settle Midtrans ke rekening yang kamu daftarkan.
- Di dashboard Midtrans, set *Payment Notification URL* ke `https://<domain-kamu>/payments/webhook/midtrans`. Server harus bisa diakses dari internet (deploy ke cloud kamu sendiri).

## Menyambungkan app Flutter (salinan tugas)
App memakai backend ini lewat `lib/utils/api_config.dart` dan `lib/utils/api_service.dart`.

```bash
# 1. jalankan backend
docker compose up --build

# 2. jalankan app (pilih salah satu)
flutter run                                              # emulator Android (otomatis http://10.0.2.2)
flutter run --dart-define=API_HOST=http://192.168.1.10   # HP asli, satu WiFi dengan laptop (pakai IP laptop)
flutter run --dart-define=APP_KEY=<APP_KEY di .env>      # wajib kalau APP_KEY di .env diganti
flutter run --dart-define=USE_BACKEND=false              # mode lama: semua data di SQLite lokal
```
Untuk build rilis/cloud, pakai `--dart-define=USER_URL=... --dart-define=ORDER_URL=... --dart-define=PAYMENT_URL=...`.

Yang sudah lewat backend: login, daftar (member/kurir), buat pesanan (order id, waktu, nominal dari server),
daftar pesanan (member / admin toko / kurir / superadmin), ubah status, kurir mengambil pesanan, tandai lunas.
Akun demo `member@demo.com` dan `kurir@demo.com` (password `demo123`) dibuat otomatis (SEED_DEMO=true).
Admin toko dan superadmin tetap login dengan kredensial di app, lalu otomatis didaftarkan ke user-service (`/auth/staff-sync`) untuk mendapat token.

Catatan:
- Pesanan lama yang hanya ada di SQLite (sebelum backend dipakai) tidak ada di backend, jadi tidak bisa diubah statusnya.
- Foto (bukti bayar, foto profil, KTP) dan data menu/toko/stok masih di SQLite lokal.
- Android memblokir HTTP biasa pada build rilis; manifest sudah diberi `usesCleartextTraffic`. Pakai HTTPS untuk server sungguhan.
