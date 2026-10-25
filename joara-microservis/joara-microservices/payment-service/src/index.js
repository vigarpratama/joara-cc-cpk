// payment-service — generate QRIS DINAMIS (MPM: nominal + batas waktu) + terima webhook. Database sendiri: joara_payments
//
// PAYMENT_PROVIDER=midtrans -> QRIS asli lewat Midtrans (sandbox / production).
//                              Dana yang masuk akan di-settle Midtrans ke REKENING MERCHANT kamu.
// PAYMENT_PROVIDER=mock     -> QRIS tiruan buat demo/tes tanpa akun (default).
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { buildDynamicQris, decodeQris } = require('./qris');
const { Pool } = require('pg');

const PORT = process.env.PORT || 3003;
const JWT_SECRET = process.env.JWT_SECRET || 'ganti-secret-ini';
const INTERNAL_KEY = process.env.INTERNAL_KEY || 'ganti-internal-key';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://localhost:3002';
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'mock').toLowerCase();
const MIDTRANS_SERVER_KEY = process.env.MIDTRANS_SERVER_KEY || '';
const MIDTRANS_BASE = process.env.MIDTRANS_BASE_URL || 'https://api.sandbox.midtrans.com'; // production: https://api.midtrans.com
const QRIS_EXPIRE_MINUTES = Number(process.env.QRIS_EXPIRE_MINUTES || 1);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function initDb() {
  for (let i = 1; i <= 30; i++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS payments (
          id                TEXT PRIMARY KEY,
          order_id          TEXT NOT NULL,
          provider          TEXT NOT NULL,
          provider_order_id TEXT NOT NULL UNIQUE,
          gross_amount      NUMERIC(14,2) NOT NULL,
          method            TEXT NOT NULL DEFAULT 'qris',
          qr_string         TEXT NOT NULL DEFAULT '',
          qr_url            TEXT NOT NULL DEFAULT '',
          status            TEXT NOT NULL DEFAULT 'pending',
          expires_at        TIMESTAMPTZ,
          created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
        )`);
      await pool.query('CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id)');
      console.log(`[payment-service] database siap (provider: ${PROVIDER})`);
      return;
    } catch (e) {
      console.log(`[payment-service] menunggu database (${i}/30): ${e.message}`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  throw new Error('database tidak bisa dihubungi');
}

const toPayment = r => ({
  paymentId: r.id, orderId: r.order_id, provider: r.provider,
  amount: Number(r.gross_amount), method: r.method,
  qrString: r.qr_string, qrUrl: r.qr_url,
  status: r.status, expiresAt: r.expires_at, createdAt: r.created_at, updatedAt: r.updated_at,
  // Sisa detik dihitung SERVER, supaya hitung mundur di app tidak bergantung pada jam HP
  secondsLeft: r.expires_at ? Math.max(0, Math.floor((new Date(r.expires_at).getTime() - Date.now()) / 1000)) : 0,
});

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Token tidak ada' });
  try { req.user = jwt.verify(token, JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'Token tidak valid / kedaluwarsa' }); }
}

async function setOrderPaymentStatus(orderId, paymentStatus) {
  const r = await fetch(`${ORDER_SERVICE_URL}/internal/orders/${encodeURIComponent(orderId)}/payment-status`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', 'x-internal-key': INTERNAL_KEY },
    body: JSON.stringify({ paymentStatus }),
  });
  if (!r.ok) throw new Error(`order-service membalas ${r.status}`);
}

// ---- provider: generate QRIS ----
async function createQrisCharge({ providerOrderId, amount, order }) {
  if (PROVIDER === 'midtrans') {
    if (!MIDTRANS_SERVER_KEY) throw new Error('MIDTRANS_SERVER_KEY belum diisi');
    const r = await fetch(`${MIDTRANS_BASE}/v2/charge`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json', Accept: 'application/json',
        Authorization: 'Basic ' + Buffer.from(MIDTRANS_SERVER_KEY + ':').toString('base64'),
      },
      body: JSON.stringify({
        payment_type: 'qris',
        transaction_details: { order_id: providerOrderId, gross_amount: Math.round(amount) },
        qris: { acquirer: 'gopay' },
        customer_details: { first_name: order.memberName || 'Pelanggan', phone: order.memberPhone || '' },
        custom_expiry: { expiry_duration: QRIS_EXPIRE_MINUTES, unit: 'minute' },
      }),
    });
    const data = await r.json();
    if (!['200', '201'].includes(String(data.status_code))) throw new Error(`Midtrans: ${data.status_message || r.status}`);
    const qrAction = (data.actions || []).find(a => a.name === 'generate-qr-code');
    return { qrString: data.qr_string || '', qrUrl: qrAction ? qrAction.url : '' };
  }
  // mock: QRIS dinamis format EMV/QRIS (nominal tertanam di QR, CRC16 valid, merchant fiktif)
  return { qrString: buildDynamicQris({ amount, billNumber: providerOrderId }), qrUrl: '' };
}

// Tandai pembayaran pending yang sudah lewat batas waktu sebagai 'expired'
async function expireOldPayments(orderId) {
  if (orderId) {
    await pool.query("UPDATE payments SET status = 'expired', updated_at = now() WHERE order_id = $1 AND status = 'pending' AND expires_at <= now()", [orderId]);
  } else {
    await pool.query("UPDATE payments SET status = 'expired', updated_at = now() WHERE status = 'pending' AND expires_at <= now()");
  }
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ service: 'payment-service', status: 'ok', provider: PROVIDER }));

// Generate QRIS untuk satu pesanan
app.post('/payments/qris', auth, async (req, res) => {
  try {
    const { orderId } = req.body || {};
    if (!orderId) return res.status(400).json({ error: 'orderId wajib diisi' });

    // Ambil pesanan dari order-service (pakai token user, jadi cek kepemilikan ikut berjalan di sana)
    const or = await fetch(`${ORDER_SERVICE_URL}/orders/${encodeURIComponent(orderId)}`, {
      headers: { Authorization: req.headers.authorization },
    });
    if (or.status === 404) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    if (or.status === 403) return res.status(403).json({ error: 'Itu bukan pesananmu' });
    if (!or.ok) return res.status(502).json({ error: 'Gagal mengambil pesanan dari order-service' });
    const order = await or.json();

    if (order.paymentMethod !== 'qris') return res.status(400).json({ error: 'Pesanan ini bukan metode QRIS' });
    if (order.paymentStatus === 'paid') return res.status(409).json({ error: 'Pesanan sudah lunas' });

    // Pakai QRIS yang masih aktif kalau ada (jangan bikin dobel)
    await expireOldPayments(orderId);
    const active = await pool.query(
      `SELECT * FROM payments WHERE order_id = $1 AND status = 'pending' AND expires_at > now() ORDER BY created_at DESC LIMIT 1`, [orderId]);
    if (active.rowCount) {
      const row = active.rows[0];
      // QR mock lama (format JOARA-MOCK-QRIS|...) bukan QRIS valid -> tutup, lalu buat QRIS dinamis baru
      if (row.provider === 'mock' && !row.qr_string.startsWith('000201')) {
        await pool.query("UPDATE payments SET status = 'expired', updated_at = now() WHERE id = $1", [row.id]);
      } else {
        return res.json(toPayment(row));
      }
    }

    const attempt = (await pool.query('SELECT count(*)::int AS n FROM payments WHERE order_id = $1', [orderId])).rows[0].n + 1;
    const providerOrderId = `${orderId}-${attempt}`;
    const { qrString, qrUrl } = await createQrisCharge({ providerOrderId, amount: order.totalAmount, order });
    const id = crypto.randomUUID();
    const { rows } = await pool.query(
      `INSERT INTO payments (id, order_id, provider, provider_order_id, gross_amount, qr_string, qr_url, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7, now() + ($8 || ' minutes')::interval) RETURNING *`,
      [id, orderId, PROVIDER, providerOrderId, order.totalAmount, qrString, qrUrl, String(QRIS_EXPIRE_MINUTES)]);
    res.status(201).json(toPayment(rows[0]));
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || 'Terjadi kesalahan server' }); }
});

// Status pembayaran terakhir sebuah pesanan
app.get('/payments/order/:orderId', auth, async (req, res) => {
  await expireOldPayments(req.params.orderId);
  const { rows } = await pool.query('SELECT * FROM payments WHERE order_id = $1 ORDER BY created_at DESC LIMIT 1', [req.params.orderId]);
  if (!rows.length) return res.status(404).json({ error: 'Belum ada pembayaran untuk pesanan ini' });
  res.json(toPayment(rows[0]));
});

// Baca & verifikasi isi QRIS (dipakai buat demo: membuktikan QR benar-benar QRIS dinamis)
// Contoh: POST /payments/decode  {"qrString":"000201..."}
app.post('/payments/decode', async (req, res) => {
  try {
    const qr = String((req.body || {}).qrString || '').trim();
    const info = decodeQris(qr);
    let payment = null;
    if (info.crcOk) {
      await expireOldPayments();
      const { rows } = await pool.query('SELECT * FROM payments WHERE qr_string = $1 ORDER BY created_at DESC LIMIT 1', [qr]);
      if (rows.length) {
        const r = rows[0];
        payment = {
          orderId: r.order_id, status: r.status, expiresAt: r.expires_at,
          secondsLeft: Math.max(0, Math.floor((new Date(r.expires_at).getTime() - Date.now()) / 1000)),
        };
      }
    }
    res.json({ ...info, payment });
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

// Webhook dari Midtrans (daftarkan URL ini di dashboard Midtrans -> Payment Notification URL)
app.post('/payments/webhook/midtrans', async (req, res) => {
  try {
    const n = req.body || {};
    const expected = crypto.createHash('sha512')
      .update(`${n.order_id}${n.status_code}${n.gross_amount}${MIDTRANS_SERVER_KEY}`).digest('hex');
    if (!MIDTRANS_SERVER_KEY || n.signature_key !== expected) return res.status(403).json({ error: 'Signature tidak valid' });

    const { rows } = await pool.query('SELECT * FROM payments WHERE provider_order_id = $1', [n.order_id]);
    if (!rows.length) return res.status(404).json({ error: 'Pembayaran tidak dikenal' });
    const p = rows[0];

    let status = p.status;
    if (['settlement', 'capture'].includes(n.transaction_status)) status = 'paid';
    else if (['expire'].includes(n.transaction_status)) status = 'expired';
    else if (['cancel', 'deny', 'failure'].includes(n.transaction_status)) status = 'failed';

    await pool.query('UPDATE payments SET status = $1, updated_at = now() WHERE id = $2', [status, p.id]);
    if (status === 'paid') await setOrderPaymentStatus(p.order_id, 'paid');
    else if (status === 'failed') await setOrderPaymentStatus(p.order_id, 'failed');
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

// Simulasi bayar — hanya aktif di mode mock (untuk demo tugas tanpa akun Midtrans)
app.post('/payments/:id/mock-pay', auth, async (req, res) => {
  try {
    if (PROVIDER !== 'mock') return res.status(403).json({ error: 'Hanya tersedia di mode mock' });
    // Hanya bisa dibayar kalau QR belum kedaluwarsa
    const { rows } = await pool.query(
      "UPDATE payments SET status = 'paid', updated_at = now() WHERE id = $1 AND status = 'pending' AND expires_at > now() RETURNING *", [req.params.id]);
    if (!rows.length) {
      await expireOldPayments();
      const cur = await pool.query('SELECT status FROM payments WHERE id = $1', [req.params.id]);
      if (cur.rowCount && cur.rows[0].status === 'expired') return res.status(410).json({ error: 'QRIS sudah kedaluwarsa, buat QRIS baru' });
      return res.status(404).json({ error: 'Pembayaran tidak ditemukan / sudah diproses' });
    }
    await setOrderPaymentStatus(rows[0].order_id, 'paid');
    res.json(toPayment(rows[0]));
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

initDb().then(() => app.listen(PORT, () => console.log(`[payment-service] jalan di :${PORT}`)))
  .catch(e => { console.error(e); process.exit(1); });
