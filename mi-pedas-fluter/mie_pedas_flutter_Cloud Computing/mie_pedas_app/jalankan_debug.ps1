# jalankan_debug.ps1
# Taruh file ini di folder mie_pedas_app (satu folder dengan pubspec.yaml).
# Jalankan dari PowerShell di folder itu:
#   powershell -ExecutionPolicy Bypass -File .\jalankan_debug.ps1
#
# Yang dilakukan: baca APP_KEY dari .env backend, cari IP Wi-Fi laptop, cek backend jalan,
# cek APP_KEY di server sama dengan .env, cari HP, lalu flutter run dengan nilai yang benar.

$backend = Join-Path $PSScriptRoot '..\..\joara-microservices'
$envFile = Join-Path $backend '.env'

if (-not (Test-Path $envFile)) {
  Write-Host "File .env tidak ditemukan di: $envFile" -ForegroundColor Red
  Write-Host "Pastikan folder joara-microservices ada dua tingkat di atas mie_pedas_app." -ForegroundColor Yellow
  exit 1
}

# 1. APP_KEY dari .env
$line = Get-Content $envFile | Where-Object { $_ -match '^APP_KEY=' } | Select-Object -First 1
if (-not $line) { Write-Host "APP_KEY tidak ada di .env" -ForegroundColor Red; exit 1 }
$key = $line.Substring('APP_KEY='.Length).Trim()
if ($key.Length -lt 16) { Write-Host "APP_KEY di .env terlalu pendek / kosong" -ForegroundColor Red; exit 1 }

# 2. IP Wi-Fi laptop (hotspot)
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
if (-not $ip) { $ip = Read-Host 'IP Wi-Fi tidak terdeteksi. Ketik IPv4 Wi-Fi dari ipconfig' }

# 3. Backend jalan?
foreach ($port in 3001, 3002, 3003) {
  try {
    Invoke-WebRequest -UseBasicParsing "http://localhost:$port/health" -TimeoutSec 5 | Out-Null
    Write-Host "Backend port $port : OK" -ForegroundColor Green
  } catch {
    Write-Host "Backend port $port tidak merespons. Jalankan dulu: docker compose up" -ForegroundColor Red
    exit 1
  }
}

# 4. APP_KEY di server sama dengan .env?
Push-Location $backend
$serverKey = (docker compose exec -T user-service printenv APP_KEY 2>$null | Out-String).Trim()
Pop-Location
if ($serverKey -ne $key) {
  Write-Host "APP_KEY di server BERBEDA dengan .env." -ForegroundColor Red
  Write-Host "Bangun ulang backend: docker compose up --build" -ForegroundColor Yellow
  exit 1
}
Write-Host "APP_KEY server = .env : COCOK" -ForegroundColor Green

# 5. Cari HP
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$dev = $null
if (Test-Path $adb) {
  $m = (& $adb devices) | Select-String '\sdevice$' | Select-Object -First 1
  if ($m) { $dev = ($m.ToString() -split '\s+')[0] }
}
if (-not $dev) {
  Write-Host "HP belum terdeteksi atau belum diizinkan (not authorized)." -ForegroundColor Red
  Write-Host "Colok kabel, buka kunci layar, izinkan dialog debugging USB, lalu ulangi." -ForegroundColor Yellow
  exit 1
}

$tail = $key.Substring($key.Length - 4)
Write-Host ""
Write-Host "IP laptop : $ip"
Write-Host "APP_KEY   : $($key.Substring(0,4))...$tail"
Write-Host "HP        : $dev"
Write-Host ""

# 6. Jalankan
flutter run -d $dev "--dart-define=API_HOST=http://$ip" "--dart-define=APP_KEY=$key"
