# Cara Build dan Install APK dengan Logging

## Build APK untuk Testing (Dengan Log)

### 1. Build Debug APK (Recommended)
```bash
# Masuk ke folder project
cd D:\Gawean\web\ymsoftapp

# Build APK debug (masih include semua log)
flutter build apk --debug

# APK akan ada di: build/app/outputs/flutter-apk/app-debug.apk
```

**Keuntungan:**
- ✅ Semua `print()` statements masih muncul di log
- ✅ Mudah untuk debugging
- ✅ Hot reload masih bisa digunakan

**Kekurangan:**
- ❌ Ukuran file lebih besar
- ❌ Performa sedikit lebih lambat

### 2. Build Profile APK (Alternatif)
```bash
flutter build apk --profile
```

**Keuntungan:**
- ✅ Log masih muncul
- ✅ Performa lebih baik dari debug
- ✅ Ukuran lebih kecil dari debug

**Kekurangan:**
- ❌ Tidak bisa hot reload

### 3. Build Release APK (Hanya untuk Production)
```bash
flutter build apk --release
```

**⚠️ WARNING:**
- ❌ Semua `print()` statements dihilangkan untuk optimasi
- ❌ Log tidak akan muncul
- ✅ Hanya gunakan untuk production final

## Install APK ke HP

### Cara 1: Via USB (Paling Mudah)
```bash
# Pastikan HP terhubung dan USB Debugging aktif
adb devices

# Install APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# Atau install dengan replace jika sudah ada
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Cara 2: Manual Transfer
1. Copy file APK dari `build/app/outputs/flutter-apk/app-debug.apk`
2. Transfer ke HP (via USB, email, atau cloud storage)
3. Install manual di HP (aktifkan "Install from Unknown Sources" jika perlu)

## Melihat Log Setelah Install

### 1. Hubungkan HP via USB
```bash
# Pastikan HP terdeteksi
adb devices
```

### 2. Clear Log Lama
```bash
adb logcat -c
```

### 3. Monitor Log Real-time
```bash
# Lihat semua log
adb logcat

# Filter hanya log Flutter
adb logcat | findstr "flutter"

# Filter log dengan keyword tertentu
adb logcat | findstr "PO Ops\|Budget\|Error"
```

### 4. Simpan Log ke File
```bash
# Simpan semua log
adb logcat > app_logs.txt

# Simpan hanya error
adb logcat *:E > error_logs.txt
```

## Quick Command untuk Testing

```bash
# 1. Build debug APK
flutter build apk --debug

# 2. Install ke HP
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 3. Clear log
adb logcat -c

# 4. Monitor log (di terminal terpisah)
adb logcat | findstr "flutter\|PO Ops\|Budget\|Error"
```

## Tips

1. **Selalu gunakan `--debug` untuk testing** agar log muncul
2. **Gunakan `--profile`** jika ingin performa lebih baik tapi masih butuh log
3. **Hanya gunakan `--release`** untuk production final
4. **Jangan lupa clear log** sebelum testing: `adb logcat -c`
5. **Simpan log ke file** jika perlu analisis lebih lanjut

## Troubleshooting

### APK tidak bisa di-install:
- Pastikan "Install from Unknown Sources" aktif
- Atau gunakan `adb install` yang lebih reliable

### Log tidak muncul:
- Pastikan build dengan `--debug` atau `--profile`, BUKAN `--release`
- Pastikan USB Debugging aktif
- Coba restart adb: `adb kill-server && adb start-server`

### Build error:
```bash
# Clean build
flutter clean
flutter pub get
flutter build apk --debug
```


