# Fix Flutter Build Error - Maven Repository Issue

## Masalah
Build gagal dengan error:
```
Could not resolve io.flutter:armeabi_v7a_release:1.0.0-...
Received status code 500 from server: Internal Server Error
```

## Penyebab
- Maven Central server mengalami masalah (error 500)
- Network timeout saat download Flutter native libraries
- Gradle cache corrupt

## Solusi yang Sudah Diterapkan

### 1. Tambahkan Repository Alternatif
- Menambahkan Flutter's own repository: `https://storage.googleapis.com/download.flutter.io`
- Menambahkan Maven repository alternatif

### 2. Update Gradle Properties
- Menambahkan timeout settings untuk network
- Enable parallel build dan daemon

## Langkah-langkah Fix Manual (Jika Masih Error)

### 1. Clear Gradle Cache
```bash
cd android
./gradlew clean
cd ..
flutter clean
```

### 2. Clear Flutter Cache
```bash
flutter pub cache repair
```

### 3. Clear Gradle Cache Directory
```bash
# Windows
rmdir /s /q %USERPROFILE%\.gradle\caches

# Atau hapus folder:
# C:\Users\<username>\.gradle\caches
```

### 4. Rebuild
```bash
flutter pub get
cd android
./gradlew clean
cd ..
flutter build apk --release
```

## Alternatif: Build dengan Offline Mode (Jika Sudah Pernah Build)

Jika sebelumnya sudah pernah build sukses, bisa coba:

```bash
cd android
./gradlew assembleRelease --offline
```

## Jika Masih Error

### Cek Flutter Version
```bash
flutter doctor -v
```

### Update Flutter
```bash
flutter upgrade
flutter pub get
```

### Cek Network
Pastikan koneksi internet stabil dan bisa akses:
- https://repo.maven.apache.org
- https://storage.googleapis.com/download.flutter.io

### Gunakan VPN/Proxy
Jika ada masalah dengan network, coba gunakan VPN atau proxy.

## Catatan
- Error 500 dari Maven Central biasanya temporary
- Coba build lagi setelah beberapa saat
- Repository alternatif sudah ditambahkan untuk fallback

