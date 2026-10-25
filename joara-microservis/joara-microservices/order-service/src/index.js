// order-service — pesanan: order id, waktu, nominal, status. Database sendiri: joara_orders
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'ganti-secret-ini';
const INTERNAL_KEY = process.env.INTERNAL_KEY || 'ganti-internal-key';
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const ORDER_STATUS = ['pending', 'processing', 'ready', 'delivering', 'delivered', 'done', 'cancelled'];
const PAYMENT_STATUS = ['pending', 'paid', 'failed', 'refunded'];
const PAYMENT_METHOD = ['cash', 'transfer', 'ewallet', 'qris'];

async function initDb() {
  for (let i = 1; i <= 30; i++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS orders (
          id               TEXT PRIMARY KEY,
          member_id        TEXT NOT NULL,
          member_name      TEXT NOT NULL DEFAULT '',
          member_phone     TEXT NOT NULL DEFAULT '',
          store_id         TEXT NOT NULL,
          store_name       TEXT NOT NULL DEFAULT '',
          kurir_id         TEXT NOT NULL DEFAULT '',
          kurir_name       TEXT NOT NULL DEFAULT '',
          kurir_phone      TEXT NOT NULL DEFAULT '',
          delivery_address TEXT NOT NULL,
          items            JSONB NOT NULL,
          subtotal         NUMERIC(14,2) NOT NULL,
          delivery_fee     NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount         NUMERIC(14,2) NOT NULL DEFAULT 0,
          total_amount     NUMERIC(14,2) NOT NULL,
          payment_method   TEXT NOT NULL DEFAULT 'cash',
          payment_status   TEXT NOT NULL DEFAULT 'pending',
          order_status     TEXT NOT NULL DEFAULT 'pending',
          note             TEXT NOT NULL DEFAULT '',
          promo_code       TEXT NOT NULL DEFAULT '',
          created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
        )`);
      await pool.query("ALTER TABLE orders ADD COLUMN IF NOT EXISTS kurir_phone TEXT NOT NULL DEFAULT ''");
      await pool.query('CREATE INDEX IF NOT EXISTS idx_orders_member ON orders(member_id)');
      await pool.query('CREATE INDEX IF NOT EXISTS idx_orders_store ON orders(store_id)');
      console.log('[order-service] database siap');
      return;
    } catch (e) {
      console.log(`[order-service] menunggu database (${i}/30): ${e.message}`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  throw new Error('database tidak bisa dihubungi');
}

const toOrder = r => ({
  orderId: r.id,
  memberId: r.member_id, memberName: r.member_name, memberPhone: r.member_phone,
  storeId: r.store_id, storeName: r.store_name,
  kurirId: r.kurir_id, kurirName: r.kurir_name, kurirPhone: r.kurir_phone,
  deliveryAddress: r.delivery_address,
  items: r.items,
  subtotal: Number(r.subtotal), deliveryFee: Number(r.delivery_fee), discount: Number(r.discount),
  totalAmount: Number(r.total_amount),
  paymentMethod: r.payment_method, paymentStatus: r.payment_status, orderStatus: r.order_status,
  note: r.note, promoCode: r.promo_code,
  createdAt: r.created_at, updatedAt: r.updated_at,
});

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Token tidak ada' });
  try { req.user = jwt.verify(token, JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'Token tidak valid / kedaluwarsa' }); }
}
const requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'Akses ditolak untuk role ini' });
function internalOnly(req, res, next) {
  if (req.headers['x-internal-key'] !== INTERNAL_KEY) return res.status(403).json({ error: 'Hanya untuk layanan internal' });
  next();
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ service: 'order-service', status: 'ok' }));

// Buat pesanan baru (member). Nominal dihitung ulang di server, bukan percaya angka dari aplikasi.
app.post('/orders', auth, requireRole('member'), async (req, res) => {
  try {
    const b = req.body || {};
    const items = Array.isArray(b.items) ? b.items : [];
    if (!b.storeId || !b.deliveryAddress || !items.length)
      return res.status(400).json({ error: 'storeId, deliveryAddress, dan items wajib diisi' });
    for (const it of items) {
      if (!it.menuId || !it.menuName || !(Number(it.price) >= 0) || !(Number(it.quantity) > 0))
        return res.status(400).json({ error: 'Setiap item butuh menuId, menuName, price, quantity > 0' });
    }
    const paymentMethod = b.paymentMethod || 'cash';
    if (!PAYMENT_METHOD.includes(paymentMethod)) return res.status(400).json({ error: 'paymentMethod tidak valid' });

    const subtotal = items.reduce((s, it) => s + Number(it.price) * Number(it.quantity), 0);
    const deliveryFee = Number(b.deliveryFee || 0);
    const discount = Number(b.discount || 0);
    const total = Math.max(subtotal + deliveryFee - discount, 0);
    const id = 'ORD' + Date.now();

    const { rows } = await pool.query(
      `INSERT INTO orders (id, member_id, member_name, member_phone, store_id, store_name, delivery_address,
         items, subtotal, delivery_fee, discount, total_amount, payment_method, note, promo_code)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING *`,
      [id, req.user.sub, req.user.name || '', b.memberPhone || '', b.storeId, b.storeName || '', b.deliveryAddress,
       JSON.stringify(items), subtotal, deliveryFee, discount, total, paymentMethod, b.note || '', b.promoCode || '']);
    res.status(201).json(toOrder(rows[0]));
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

// Daftar pesanan sesuai role
//  member: miliknya sendiri | admin: ?storeId= | kurir: ?status=ready atau miliknya | superadmin: semua
app.get('/orders', auth, async (req, res) => {
  try {
    const { role, sub } = req.user;
    let q = 'SELECT * FROM orders', params = [];
    if (role === 'member') { q += ' WHERE member_id = $1'; params = [sub]; }
    else if (role === 'admin') {
      const sid = req.user.storeId || req.query.storeId;
      if (!sid) return res.status(400).json({ error: 'storeId wajib untuk admin' });
      q += ' WHERE store_id = $1'; params = [sid];
    } else if (role === 'kurir') {
      if (req.query.status) { q += ' WHERE order_status = $1 AND kurir_id = \'\''; params = [req.query.status]; }
      else { q += ' WHERE kurir_id = $1'; params = [sub]; }
    }
    q += ' ORDER BY created_at DESC LIMIT 200';
    const { rows } = await pool.query(q, params);
    res.json(rows.map(toOrder));
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

app.get('/orders/:id', async (req, res) => {
  // Boleh dipanggil layanan internal (payment-service) atau user yang login
  let user = null;
  if (req.headers['x-internal-key'] !== INTERNAL_KEY) {
    const h = req.headers.authorization || '';
    try { user = jwt.verify(h.startsWith('Bearer ') ? h.slice(7) : '', JWT_SECRET); }
    catch { return res.status(401).json({ error: 'Token tidak valid / kedaluwarsa' }); }
  }
  const { rows } = await pool.query('SELECT * FROM orders WHERE id = $1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
  if (user && user.role === 'member' && rows[0].member_id !== user.sub)
    return res.status(403).json({ error: 'Itu bukan pesananmu' });
  res.json(toOrder(rows[0]));
});

// Ubah status pesanan (admin toko / kurir / superadmin)
app.patch('/orders/:id/status', auth, requireRole('member', 'admin', 'kurir', 'superadmin'), async (req, res) => {
  const { status } = req.body || {};
  if (!ORDER_STATUS.includes(status)) return res.status(400).json({ error: `status harus salah satu dari: ${ORDER_STATUS.join(', ')}` });
  if (req.user.role === 'member') {
    const { rows: own } = await pool.query('SELECT member_id, order_status FROM orders WHERE id = $1', [req.params.id]);
    if (!own.length) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    if (own[0].member_id !== req.user.sub) return res.status(403).json({ error: 'Itu bukan pesananmu' });
    if (status !== 'cancelled' || own[0].order_status !== 'pending')
      return res.status(403).json({ error: 'Member hanya bisa membatalkan pesanan yang masih menunggu konfirmasi' });
  }
  const { rows } = await pool.query(
    'UPDATE orders SET order_status = $1, updated_at = now() WHERE id = $2 RETURNING *', [status, req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
  res.json(toOrder(rows[0]));
});

// Kurir mengambil pesanan
app.patch('/orders/:id/assign', auth, requireRole('kurir'), async (req, res) => {
  const { rows } = await pool.query(
    `UPDATE orders SET kurir_id = $1, kurir_name = $2, kurir_phone = $3, order_status = 'delivering', updated_at = now()
     WHERE id = $4 AND kurir_id = '' AND order_status = 'ready' RETURNING *`,
    [req.user.sub, req.user.name || '', (req.body && req.body.kurirPhone) || '', req.params.id]);
  if (!rows.length) return res.status(409).json({ error: 'Pesanan tidak tersedia untuk diambil' });
  res.json(toOrder(rows[0]));
});

// Admin toko menandai lunas secara manual (mis. verifikasi bukti transfer)
app.patch('/orders/:id/mark-paid', auth, requireRole('admin', 'superadmin'), async (req, res) => {
  const { rows } = await pool.query(
    "UPDATE orders SET payment_status = 'paid', updated_at = now() WHERE id = $1 RETURNING *", [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
  res.json(toOrder(rows[0]));
});

// Dipanggil payment-service saat pembayaran QRIS berubah status (lewat webhook)
app.patch('/internal/orders/:id/payment-status', internalOnly, async (req, res) => {
  const { paymentStatus } = req.body || {};
  if (!PAYMENT_STATUS.includes(paymentStatus)) return res.status(400).json({ error: 'paymentStatus tidak valid' });
  const { rows } = await pool.query(
    'UPDATE orders SET payment_status = $1, updated_at = now() WHERE id = $2 RETURNING *', [paymentStatus, req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
  res.json(toOrder(rows[0]));
});

initDb().then(() => app.listen(PORT, () => console.log(`[order-service] jalan di :${PORT}`)))
  .catch(e => { console.error(e); process.exit(1); });
