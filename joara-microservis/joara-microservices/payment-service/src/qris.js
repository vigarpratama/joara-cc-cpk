// qris.js — pembuat & pembaca QRIS DINAMIS (MPM = Merchant Presented Mode)
// Format mengikuti standar EMV QR Code (EMVCo Merchant-Presented) yang dipakai QRIS Bank Indonesia.
//
// QRIS dinamis = QR dibuat PER TRANSAKSI:
//   - tag 01 = "12"  -> dinamis (statis = "11")
//   - tag 54         -> nominal sudah tertanam, pembeli tidak mengetik nominal
//   - tag 62/01      -> nomor tagihan (nomor pesanan)
//   - tag 63         -> CRC16 supaya QR yang diubah-ubah ditolak
// Masa berlaku TIDAK ada di dalam isi QR pada standar QRIS; batas waktu dijaga server
// (kolom expires_at di database, ditolak setelah lewat).
//
// DATA MERCHANT DI BAWAH FIKTIF (hanya demo). Jangan isi dengan NMID/QRIS toko sungguhan.

const MERCHANT = {
  name: (process.env.QRIS_MERCHANT_NAME || 'MIE PEDAS DJORA').toUpperCase().slice(0, 25),
  city: (process.env.QRIS_MERCHANT_CITY || 'GRESIK').toUpperCase().slice(0, 15),
  postal: process.env.QRIS_MERCHANT_POSTAL || '61111',
  mcc: process.env.QRIS_MERCHANT_MCC || '5812', // 5812 = restoran
  nmid: process.env.QRIS_NMID || 'ID1000000000001', // fiktif
  pan: process.env.QRIS_MERCHANT_PAN || '9360000000000000017', // fiktif
  merchantId: process.env.QRIS_MERCHANT_ID || 'JOARA0000001', // fiktif
};

function tlv(id, value) {
  const v = String(value);
  if (v.length > 99) throw new Error(`QRIS tag ${id} terlalu panjang`);
  return id + String(v.length).padStart(2, '0') + v;
}

// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) — sesuai spesifikasi EMV QR
function crc16(str) {
  let crc = 0xffff;
  for (let i = 0; i < str.length; i++) {
    crc ^= str.charCodeAt(i) << 8;
    for (let j = 0; j < 8; j++) {
      crc = crc & 0x8000 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

function buildDynamicQris({ amount, billNumber }) {
  const nominal = Math.round(Number(amount));
  if (!Number.isFinite(nominal) || nominal <= 0) throw new Error('Nominal QRIS tidak valid');
  const bill = String(billNumber || '').replace(/[^A-Za-z0-9\-]/g, '').slice(0, 25);

  const body =
    tlv('00', '01') +                       // payload format indicator
    tlv('01', '12') +                       // 12 = DINAMIS
    tlv('26', tlv('00', 'ID.CO.QRIS.WWW') + tlv('01', MERCHANT.pan) + tlv('02', MERCHANT.merchantId) + tlv('03', 'UMI')) +
    tlv('51', tlv('00', 'ID.CO.QRIS.WWW') + tlv('02', MERCHANT.nmid) + tlv('03', 'UMI')) +
    tlv('52', MERCHANT.mcc) +               // kategori merchant
    tlv('53', '360') +                      // mata uang IDR
    tlv('54', String(nominal)) +            // NOMINAL
    tlv('58', 'ID') +
    tlv('59', MERCHANT.name) +
    tlv('60', MERCHANT.city) +
    tlv('61', MERCHANT.postal) +
    tlv('62', tlv('01', bill) + tlv('07', 'JOARA01')) + // nomor tagihan + label terminal
    '6304';
  return body + crc16(body);
}

// Baca TLV level atas (dan satu tingkat di dalam tag 62)
function parseTlv(s) {
  const out = {};
  let i = 0;
  while (i + 4 <= s.length) {
    const id = s.slice(i, i + 2);
    const len = parseInt(s.slice(i + 2, i + 4), 10);
    if (Number.isNaN(len) || i + 4 + len > s.length) return null;
    out[id] = s.slice(i + 4, i + 4 + len);
    i += 4 + len;
  }
  return i === s.length ? out : null;
}

function decodeQris(payload) {
  const s = String(payload || '').trim();
  const res = { valid: false, crcOk: false, dynamic: false, amount: null, merchantName: null, merchantCity: null, billNumber: null, error: null };
  if (s.length < 12 || !s.startsWith('000201')) { res.error = 'Bukan format QRIS (EMV)'; return res; }
  const tail = s.slice(-8); // "6304" + CRC
  if (!tail.startsWith('6304')) { res.error = 'Tag CRC (63) tidak ditemukan'; return res; }
  res.crcOk = crc16(s.slice(0, -4)) === s.slice(-4).toUpperCase();
  const t = parseTlv(s);
  if (!t) { res.error = 'Struktur TLV rusak'; return res; }
  res.dynamic = t['01'] === '12';
  res.amount = t['54'] ? Number(t['54']) : null;
  res.merchantName = t['59'] || null;
  res.merchantCity = t['60'] || null;
  const add = t['62'] ? parseTlv(t['62']) : null;
  res.billNumber = add ? add['01'] || null : null;
  if (!res.crcOk) res.error = 'CRC tidak cocok (QR diubah atau rusak)';
  else if (!res.dynamic) res.error = 'Ini QRIS statis, bukan dinamis';
  else if (!res.amount) res.error = 'Nominal tidak ada di QR';
  res.valid = res.crcOk && res.dynamic && !!res.amount;
  return res;
}

module.exports = { buildDynamicQris, decodeQris, crc16, tlv };
