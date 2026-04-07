# Fix "Cannot Connect to Server" Error di Device Fisik (HP)

## Masalah
- Di emulator: **Normal** ✅
- Di HP (device fisik): **Server error terus** ❌

## Penyebab
1. **Network Security Config** - Android 9+ (API 28+) memblokir koneksi yang tidak aman
2. **SSL Certificate** - Device fisik lebih ketat dalam validasi SSL
3. **Network Permission** - Permission tidak ter-apply dengan benar
4. **Firewall/Proxy** - Device fisik mungkin punya firewall atau proxy

## Solusi yang Sudah Diterapkan

### 1. Network Security Config
File: `android/app/src/main/res/xml/network_security_config.xml`
- Mengizinkan HTTPS ke `ymsofterp.com`
- Trust system certificates
- Trust user certificates (untuk debugging)

### 2. AndroidManifest.xml
- Menambahkan `networkSecurityConfig` reference
- Internet permission sudah ada
- Network state permission sudah ada

### 3. Error Handling
- Timeout 30 detik
- Error handling yang lebih baik

## Langkah-langkah Fix

### 1. Rebuild Aplikasi
```bash
cd D:\Gawean\YM\web\ymsoftapp
flutter clean
flutter pub get
flutter build apk --release
```

### 2. Install di HP
```bash
flutter install
```

### 3. Test Koneksi
- Buka aplikasi
- Coba login
- Cek log jika masih error

## Troubleshooting

### Cek Log di Device
```bash
# Connect device via USB
adb logcat | grep -i "flutter\|http\|socket"
```

### Test Koneksi dari Device
1. Buka browser di HP
2. Akses: `https://ymsofterp.com/api/approval-app/auth/login`
3. Cek apakah bisa diakses

### Cek Network di Device
1. Pastikan HP terhubung ke internet
2. Cek apakah ada VPN/Proxy yang aktif
3. Cek apakah ada firewall yang block

### Jika Masih Error

#### Cek Base URL
Base URL saat ini: `https://ymsofterp.com`

Jika server menggunakan IP atau domain lain, perlu update di:
- `lib/services/auth_service.dart` (line 10)

#### Cek SSL Certificate
Jika server menggunakan self-signed certificate, perlu:
1. Tambahkan certificate ke trust store
2. Atau gunakan network security config untuk trust semua certificates (tidak recommended untuk production)

#### Debug dengan Log
Tambahkan log untuk debug:
```dart
print('Attempting to connect to: $baseUrl/api/approval-app/auth/login');
```

## Alternatif: Test dengan HTTP (Development Only)

Jika server menggunakan HTTP (bukan HTTPS) untuk development:

1. Update `network_security_config.xml`:
```xml
<domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="true">ymsofterp.com</domain>
</domain-config>
```

2. Update `AndroidManifest.xml`:
```xml
android:usesCleartextTraffic="true"
```

**WARNING:** Jangan gunakan ini untuk production!

## Catatan Penting

- Network security config sudah ditambahkan
- File: `android/app/src/main/res/xml/network_security_config.xml`
- AndroidManifest sudah diupdate untuk reference network security config
- Rebuild aplikasi setelah perubahan

## Jika Masih Error Setelah Rebuild

1. **Cek log detail:**
   ```bash
   adb logcat | grep -i "error\|exception\|socket"
   ```

2. **Test endpoint dari device:**
   - Buka browser di HP
   - Akses: `https://ymsofterp.com`
   - Cek apakah bisa diakses

3. **Cek network permission:**
   - Settings > Apps > ymsoftapp > Permissions
   - Pastikan Internet permission enabled

4. **Cek firewall/VPN:**
   - Matikan VPN sementara
   - Cek firewall settings

