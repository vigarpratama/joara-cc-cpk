#!/usr/bin/env bash
# Tes alur lengkap: daftar -> buat pesanan QRIS -> generate QRIS -> bayar (mock) -> pesanan lunas.
# Jalankan setelah `docker compose up`. Butuh: curl + node.
U=${USER_URL:-http://localhost:3001}; O=${ORDER_URL:-http://localhost:3002}; P=${PAYMENT_URL:-http://localhost:3003}
J='Content-Type: application/json'
jget() { node -e "let s='';process.stdin.on('data',c=>s+=c).on('end',()=>{const d=JSON.parse(s);console.log(d$1)})"; }
EMAIL="tes$(date +%s)@demo.com"

echo "1) daftar akun member";   R=$(curl -s -X POST $U/auth/register -H "$J" -d "{\"name\":\"Sari Member\",\"email\":\"$EMAIL\",\"phone\":\"083333333333\",\"password\":\"demo123\"}")
TOKEN=$(echo "$R" | jget ".token"); [ -n "$TOKEN" ] && [ "$TOKEN" != "undefined" ] && echo "   OK token diterima" || { echo "   GAGAL: $R"; exit 1; }
AUTH="Authorization: Bearer $TOKEN"

echo "2) buat pesanan (QRIS)";  ORD=$(curl -s -X POST $O/orders -H "$J" -H "$AUTH" -d '{"storeId":"store_joara","storeName":"Mie Pedas Djora","deliveryAddress":"Jl. Raya Bungah 46","paymentMethod":"qris","deliveryFee":6206,"items":[{"menuId":"m1","menuName":"Mie Pedas Level 1","price":15000,"quantity":1}]}')
OID=$(echo "$ORD" | jget ".orderId"); echo "   order id : $OID"; echo "   nominal  : $(echo "$ORD" | jget ".totalAmount")"; echo "   waktu    : $(echo "$ORD" | jget ".createdAt")"

echo "3) generate QRIS";        PAY=$(curl -s -X POST $P/payments/qris -H "$J" -H "$AUTH" -d "{\"orderId\":\"$OID\"}")
PID=$(echo "$PAY" | jget ".paymentId"); echo "   payment id: $PID"; echo "   qr string : $(echo "$PAY" | jget ".qrString")"

echo "4) status sebelum bayar"; echo "   paymentStatus: $(curl -s $O/orders/$OID -H "$AUTH" | jget ".paymentStatus")"

echo "5) bayar (hanya mode mock)"; curl -s -X POST $P/payments/$PID/mock-pay -H "$AUTH" > /dev/null
echo "   paymentStatus: $(curl -s $O/orders/$OID -H "$AUTH" | jget ".paymentStatus")  (harus: paid)"
