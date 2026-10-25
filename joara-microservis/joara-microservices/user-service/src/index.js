// user-service — daftar, login, profil. Database sendiri: joara_users
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { Pool } = require('pg');

const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'ganti-secret-ini';
const APP_KEY = process.env.APP_KEY || 'ganti-app-key';
const SEED_DEMO = (process.env.SEED_DEMO || 'true') !== 'false';
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function initDb() {
  for (let i = 1; i <= 30; i++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS users (
          id            TEXT PRIMARY KEY,
          name          TEXT NOT NULL,
          email         TEXT UNIQUE NOT NULL,
          phone         TEXT NOT NULL DEFAULT '',
          password_hash TEXT NOT NULL,
          role          TEXT NOT NULL DEFAULT 'member',
          created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
        )`);
      await pool.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS store_id TEXT NOT NULL DEFAULT ''");
      if (SEED_DEMO) await seedDemo();
      console.log('[user-service] database siap');
      return;
    } catch (e) {
      console.log(`[user-service] menunggu database (${i}/30): ${e.message}`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  throw new Error('database tidak bisa dihubungi');
}

// Akun demo yang sama dengan app (member@demo.com / kurir@demo.com, password demo123)
async function seedDemo() {
  const demo = [
    ['Sari Member', 'member@demo.com', '083333333333', 'member'],
    ['Budi Kurir', 'kurir@demo.com', '082222222222', 'kurir'],
  ];
  const hash = await bcrypt.hash('demo123', 10);
  for (const [name, email, phone, role] of demo) {
    await pool.query(
      `INSERT INTO users (id, name, email, phone, password_hash, role) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (email) DO NOTHING`,
      [crypto.randomUUID(), name, email, phone, hash, role]);
  }
}

const publicUser = u => ({ id: u.id, name: u.name, email: u.email, phone: u.phone, role: u.role, storeId: u.store_id || '', createdAt: u.created_at });
const sign = u => jwt.sign({ sub: u.id, role: u.role, name: u.name, storeId: u.store_id || '' }, JWT_SECRET, { expiresIn: '7d' });

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Token tidak ada' });
  try { req.user = jwt.verify(token, JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'Token tidak valid / kedaluwarsa' }); }
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ service: 'user-service', status: 'ok' }));

app.post('/auth/register', async (req, res) => {
  try {
    const { name, email, phone = '', password, role = 'member' } = req.body || {};
    if (!name || !email || !password) return res.status(400).json({ error: 'name, email, password wajib diisi' });
    if (password.length < 6) return res.status(400).json({ error: 'Password minimal 6 karakter' });
    if (!['member', 'kurir'].includes(role)) return res.status(400).json({ error: 'Role hanya boleh member atau kurir' });
    const exists = await pool.query('SELECT 1 FROM users WHERE email = $1', [email.toLowerCase()]);
    if (exists.rowCount) return res.status(409).json({ error: 'Email sudah terdaftar' });
    const id = crypto.randomUUID();
    const hash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      'INSERT INTO users (id, name, email, phone, password_hash, role) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [id, name, email.toLowerCase(), phone, hash, role]);
    res.status(201).json({ token: sign(rows[0]), user: publicUser(rows[0]) });
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'email dan password wajib diisi' });
    const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [email.toLowerCase()]);
    if (!rows.length || !(await bcrypt.compare(password, rows[0].password_hash)))
      return res.status(401).json({ error: 'Email atau password salah' });
    res.json({ token: sign(rows[0]), user: publicUser(rows[0]) });
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

// Akun admin toko / superadmin. Di app, kredensial admin dibuat di sisi toko/superadmin;
// endpoint ini mendaftarkan/menyamakannya ke user-service dan mengembalikan token.
// Dilindungi header x-app-key (APP_KEY) — bukan untuk dipakai publik.
app.post('/auth/staff-sync', async (req, res) => {
  try {
    if (req.headers['x-app-key'] !== APP_KEY) return res.status(403).json({ error: 'app key tidak valid' });
    const { role, username, password, name = '', storeId = '' } = req.body || {};
    if (!['admin', 'superadmin'].includes(role) || !username || !password)
      return res.status(400).json({ error: 'role (admin/superadmin), username, password wajib diisi' });
    if (role === 'admin' && !storeId) return res.status(400).json({ error: 'storeId wajib untuk admin' });
    const email = `${role === 'admin' ? storeId : 'superadmin'}.${String(username).toLowerCase()}@staff.joara`;
    const hash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      `INSERT INTO users (id, name, email, phone, password_hash, role, store_id)
       VALUES ($1,$2,$3,'',$4,$5,$6)
       ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash, name = EXCLUDED.name, store_id = EXCLUDED.store_id
       RETURNING *`,
      [crypto.randomUUID(), name || username, email, hash, role, role === 'admin' ? storeId : '']);
    res.json({ token: sign(rows[0]), user: publicUser(rows[0]) });
  } catch (e) { console.error(e); res.status(500).json({ error: 'Terjadi kesalahan server' }); }
});

app.get('/users/me', auth, async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [req.user.sub]);
  if (!rows.length) return res.status(404).json({ error: 'User tidak ditemukan' });
  res.json(publicUser(rows[0]));
});

app.get('/users/:id', auth, async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'User tidak ditemukan' });
  res.json(publicUser(rows[0]));
});

initDb().then(() => app.listen(PORT, () => console.log(`[user-service] jalan di :${PORT}`)))
  .catch(e => { console.error(e); process.exit(1); });
