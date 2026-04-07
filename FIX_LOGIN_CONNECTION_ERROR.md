# Fix Login "Cannot Connect to Server" Error

## Masalah
Aplikasi tidak bisa login dengan error "Cannot connect to server".

## Perubahan yang Sudah Diterapkan

### 1. Menambahkan Timeout (30 detik)
- HTTP request sekarang punya timeout 30 detik
- Akan throw `TimeoutException` jika melebihi timeout

### 2. Menambahkan Internet Permission
- Menambahkan `INTERNET` permission di AndroidManifest.xml
- Menambahkan `ACCESS_NETWORK_STATE` permission

### 3. Improved Error Handling
- Deteksi `TimeoutException` dengan lebih baik
- Deteksi `SocketException` dan `Failed host lookup`
- Deteksi SSL certificate errors
- Deteksi connection refused

## Troubleshooting

### 1. Cek Koneksi Internet
Pastikan device/emulator punya koneksi internet yang stabil.

### 2. Cek Base URL
Base URL saat ini: `https://ymsofterp.com`

Cek apakah server bisa diakses:
```bash
# Test dari browser atau terminal
curl https://ymsofterp.com/api/approval-app/auth/login
```

### 3. Cek Android Network Security Config
Jika server menggunakan self-signed certificate atau HTTP (bukan HTTPS), perlu menambahkan network security config.

### 4. Cek Firewall/Proxy
Pastikan tidak ada firewall atau proxy yang block koneksi ke server.

### 5. Test dengan Postman/curl
Test endpoint login dengan Postman atau curl untuk memastikan server bisa diakses:
```bash
curl -X POST https://ymsofterp.com/api/approval-app/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

## Jika Masih Error

### Cek Log di Flutter
Jalankan dengan verbose untuk melihat error detail:
```bash
flutter run --verbose
```

Atau cek log di Android Studio/VS Code.

### Kemungkinan Penyebab Lain

1. **Server Down** - Server `ymsofterp.com` mungkin sedang down
2. **SSL Certificate Issue** - Certificate server mungkin expired atau invalid
3. **Network Configuration** - Device/emulator tidak bisa akses internet
4. **Firewall** - Firewall block koneksi ke server
5. **DNS Issue** - DNS tidak bisa resolve `ymsofterp.com`

## Solusi Alternatif

### Jika Server Menggunakan HTTP (bukan HTTPS)
Perlu menambahkan network security config untuk allow cleartext traffic.

### Jika Server Menggunakan Self-Signed Certificate
Perlu menambahkan network security config untuk trust self-signed certificate.

## Catatan
- Timeout sudah ditambahkan: 30 detik
- Error handling sudah diperbaiki untuk memberikan pesan error yang lebih jelas
- Internet permission sudah ditambahkan di AndroidManifest.xml

