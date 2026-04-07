# Cara Melihat Log Console di HP untuk Aplikasi Flutter

**PENTING:** Jika Anda build APK dan install di HP, pastikan build dengan mode yang masih include logging!

## ⚠️ Build Mode untuk Testing

### 1. Build Debug APK (Recommended untuk Testing)
```bash
# Build APK debug (masih include semua log)
flutter build apk --debug

# APK akan ada di: build/app/outputs/flutter-apk/app-debug.apk
# Install ke HP dan log akan tetap muncul
```

### 2. Build Profile APK (Masih ada log, lebih optimal)
```bash
# Build APK profile (masih include log, performa lebih baik dari debug)
flutter build apk --profile

# APK akan ada di: build/app/outputs/flutter-apk/app-profile.apk
```

### 3. Build Release APK (Log dihilangkan untuk optimasi)
```bash
# Build APK release (log dihilangkan, ukuran lebih kecil)
flutter build apk --release

# ⚠️ WARNING: Release build menghilangkan print() statements!
# Gunakan ini hanya untuk production final
```

## Cara Melihat Log dari APK yang Sudah Di-Install

Ada beberapa cara untuk melihat log dari aplikasi Flutter yang di-install di HP:

## 1. Menggunakan Flutter CLI (Paling Mudah)

### Persiapan:
1. Hubungkan HP ke komputer via USB
2. Aktifkan **USB Debugging** di HP:
   - Settings → About Phone → Tap "Build Number" 7 kali
   - Settings → Developer Options → Enable "USB Debugging"
3. Pastikan HP terdeteksi:
   ```bash
   flutter devices
   ```

### Melihat Log:
```bash
# Masuk ke folder project
cd D:\Gawean\web\ymsoftapp

# Jalankan flutter logs (akan menampilkan semua log real-time)
flutter logs

# Atau filter log tertentu (contoh: hanya log dari aplikasi kita)
flutter logs | findstr "PO Ops"
```

## 2. Menggunakan ADB (Android Debug Bridge)

### Install ADB:
- ADB biasanya sudah terinstall bersama Flutter/Android Studio
- Atau download dari: https://developer.android.com/studio/releases/platform-tools

### Melihat Log:
```bash
# Lihat semua log
adb logcat

# Filter log berdasarkan tag aplikasi
adb logcat | findstr "flutter"

# Filter log berdasarkan keyword
adb logcat | findstr "PO Ops Budget"

# Clear log dan mulai fresh
adb logcat -c
adb logcat

# Simpan log ke file
adb logcat > log.txt
```

## 3. Menggunakan Android Studio

1. Buka Android Studio
2. Hubungkan HP via USB
3. Pilih device di toolbar
4. Buka tab **Logcat** di bagian bawah
5. Filter log berdasarkan:
   - Package name: `com.justusgroup.ymsoftapp`
   - Tag: `flutter`
   - Level: `Debug`, `Info`, `Warning`, `Error`

## 4. Menggunakan VS Code

1. Install extension: **Flutter** dan **Dart**
2. Hubungkan HP via USB
3. Buka **Output** panel (View → Output)
4. Pilih **Flutter** dari dropdown
5. Atau gunakan **Debug Console** saat running in debug mode

## 5. Melihat Log di HP Langsung (Tanpa Komputer)

Untuk production, bisa menggunakan package logging yang menyimpan log ke file atau mengirim ke server:

### Package yang bisa digunakan:
- `logger` - Log dengan berbagai level dan format
- `firebase_crashlytics` - Log error ke Firebase
- `sentry_flutter` - Error tracking dan logging
- `path_provider` + file logging - Simpan log ke file lokal

### Contoh implementasi logger ke file:
```dart
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FileLogger {
  static Logger? _logger;
  static File? _logFile;
  
  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/app_logs.txt');
    
    _logger = Logger(
      printer: FilePrinter(_logFile!),
      level: Level.debug,
    );
  }
  
  static void log(String message) {
    _logger?.d(message);
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }
}
```

## Tips Debugging:

### 1. Filter Log yang Penting
```bash
# Hanya error dan warning
adb logcat *:E *:W

# Hanya log dari Flutter
adb logcat | findstr "flutter"

# Hanya log dengan keyword tertentu
adb logcat | findstr "Budget\|Error\|Exception"
```

### 2. Clear Log Sebelum Testing
```bash
adb logcat -c
```

### 3. Simpan Log untuk Analisis
```bash
# Simpan semua log
adb logcat > full_log.txt

# Simpan hanya error
adb logcat *:E > error_log.txt
```

### 4. Real-time Monitoring
```bash
# Monitor log sambil menggunakan aplikasi
adb logcat | findstr "PO Ops\|Budget\|Error"
```

## Troubleshooting:

### HP tidak terdeteksi:
1. Install driver USB untuk HP Anda
2. Pastikan USB Debugging aktif
3. Coba ganti kabel USB
4. Restart adb: `adb kill-server && adb start-server`

### Log tidak muncul setelah install APK:
1. **Pastikan build dengan --debug atau --profile, BUKAN --release!**
   ```bash
   # ✅ BENAR - Log akan muncul
   flutter build apk --debug
   
   # ❌ SALAH - Log dihilangkan
   flutter build apk --release
   ```

2. Pastikan HP terhubung via USB dan USB Debugging aktif
3. Check apakah HP terdeteksi: `adb devices`
4. Clear log dan coba lagi:
   ```bash
   adb logcat -c
   adb logcat | findstr "flutter"
   ```

5. Jika masih tidak muncul, coba build ulang dengan debug:
   ```bash
   flutter clean
   flutter build apk --debug
   ```

### Log terlalu banyak:
- Gunakan filter untuk fokus pada log yang penting
- Clear log sebelum testing: `adb logcat -c`

## Contoh Log yang Akan Muncul:

Ketika aplikasi berjalan, Anda akan melihat log seperti:
```
I/flutter: PO Ops Detail Build - PO keys: [number, supplier, grand_total, ...]
I/flutter: PO Ops Detail Build - Budget Info: exists
I/flutter: PO Ops Budget Info - No breakdown data found. Keys: [budget_type, total_budget, ...]
I/flutter: Error building Breakdown Budget section: ...
```

Log ini akan membantu Anda debug masalah seperti:
- Data tidak ter-load
- Error saat rendering
- Missing data fields

