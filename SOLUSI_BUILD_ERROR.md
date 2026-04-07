# Solusi Build Error - Flutter Native Libraries

## Error yang Terjadi
```
Could not resolve io.flutter:armeabi_v7a_release:1.0.0-13e658725ddaa270601426d1485636157e38c34c
Received status code 500 from server: Internal Server Error
```

## Solusi 1: Clear Semua Cache (RECOMMENDED)

Jalankan script yang sudah dibuat:
```bash
cd D:\Gawean\YM\web\ymsoftapp\android
gradlew_clean_cache.bat
```

Atau manual:
```bash
# 1. Clean Flutter
cd D:\Gawean\YM\web\ymsoftapp
flutter clean

# 2. Clean Gradle
cd android
gradlew clean

# 3. Hapus Gradle cache
# Windows: Hapus folder C:\Users\<username>\.gradle\caches

# 4. Repair Flutter cache
cd ..
flutter pub cache repair

# 5. Get dependencies
flutter pub get

# 6. Build lagi
flutter build apk --release
```

## Solusi 2: Update Flutter

```bash
flutter upgrade
flutter doctor -v
flutter pub get
flutter build apk --release
```

## Solusi 3: Build dengan Debug Mode Dulu

Coba build debug mode dulu untuk test:
```bash
flutter build apk --debug
```

Jika debug berhasil, baru coba release:
```bash
flutter build apk --release
```

## Solusi 4: Gunakan Flutter Engine dari Local

Jika sebelumnya sudah pernah build sukses, coba:

1. Cek Flutter engine di local:
```bash
# Cek Flutter SDK path
flutter doctor -v
# Biasanya di: C:\src\flutter
```

2. Build dengan offline mode (jika cache masih ada):
```bash
cd android
gradlew assembleRelease --offline
```

## Solusi 5: Cek Network dan Proxy

1. **Cek koneksi internet** - Pastikan bisa akses:
   - https://repo.maven.apache.org
   - https://storage.googleapis.com/download.flutter.io

2. **Jika pakai proxy/VPN** - Pastikan proxy tidak block Maven

3. **Coba tanpa proxy** - Matikan VPN/proxy sementara

## Solusi 6: Update Gradle Version

Cek versi Gradle di `android/gradle/wrapper/gradle-wrapper.properties`:
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
```

Jika perlu update, coba versi terbaru atau versi yang lebih stabil.

## Solusi 7: Build dengan Verbose untuk Debug

```bash
flutter build apk --release --verbose
```

Ini akan menampilkan detail error yang lebih lengkap.

## Solusi 8: Coba Build di Waktu Berbeda

Error 500 dari Maven Central biasanya temporary. Coba build lagi setelah beberapa jam.

## Solusi 9: Gunakan Flutter Channel Stable

```bash
flutter channel stable
flutter upgrade
flutter pub get
flutter build apk --release
```

## Solusi 10: Reinstall Flutter (Last Resort)

Jika semua solusi di atas tidak berhasil:

1. Backup project
2. Uninstall Flutter
3. Install Flutter versi terbaru
4. Setup ulang
5. Build project

## Troubleshooting

### Cek Flutter Version
```bash
flutter --version
flutter doctor -v
```

### Cek Gradle Version
```bash
cd android
gradlew --version
```

### Cek Network
```bash
# Test koneksi ke Maven
curl -I https://repo.maven.apache.org/maven2/
curl -I https://storage.googleapis.com/download.flutter.io
```

## Catatan Penting

- Error 500 biasanya temporary dari server Maven Central
- Repository alternatif sudah ditambahkan di `build.gradle.kts`
- Pastikan Flutter SDK path benar di `local.properties`
- Pastikan Android SDK sudah terinstall dan dikonfigurasi

## Jika Masih Error

Kirimkan output lengkap dari:
```bash
flutter build apk --release --verbose
```

Dan juga:
```bash
flutter doctor -v
```

