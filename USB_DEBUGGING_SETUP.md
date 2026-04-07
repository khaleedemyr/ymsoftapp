# Panduan Setup USB Debugging untuk Flutter di HP

## 📱 Setup di HP Android

### Langkah 1: Aktifkan Developer Options

1. **Buka Settings** di HP Anda
2. **Cari "About Phone"** atau "Tentang Telepon"
3. **Cari "Build Number"** atau "Nomor Build"
4. **Tap "Build Number" sebanyak 7 kali** sampai muncul pesan "You are now a developer!" atau "Anda sekarang adalah developer!"
5. Kembali ke Settings, sekarang akan ada menu **"Developer Options"** atau **"Opsi Pengembang"**

### Langkah 2: Aktifkan USB Debugging

1. **Buka "Developer Options"** di Settings
2. **Aktifkan "USB Debugging"** (toggle ON)
3. **Aktifkan "Stay Awake"** (opsional, agar layar tidak mati saat charging)
4. **Aktifkan "Install via USB"** (opsional, untuk install APK via USB)

### Langkah 3: Hubungkan HP ke Komputer

1. **Hubungkan HP ke komputer via USB cable**
2. **Di HP akan muncul popup "Allow USB Debugging?"**
3. **Centang "Always allow from this computer"** (opsional, agar tidak muncul lagi)
4. **Tap "OK" atau "Allow"**

## 💻 Setup di Komputer

### Langkah 1: Install USB Driver (Jika Perlu)

**Untuk HP Samsung:**
- Download Samsung USB Driver: https://developer.samsung.com/mobile/android-usb-driver.html

**Untuk HP Xiaomi:**
- Download Mi USB Driver: https://www.xiaomi.com/support/download/driver

**Untuk HP lainnya:**
- Biasanya Windows akan otomatis install driver
- Atau download dari website resmi brand HP Anda

### Langkah 2: Install ADB (Android Debug Bridge)

ADB biasanya sudah terinstall bersama:
- ✅ Android Studio
- ✅ Flutter SDK
- ✅ Android SDK Platform Tools

**Cek apakah ADB sudah terinstall:**
```bash
adb version
```

**Jika belum ada, install Android SDK Platform Tools:**
1. Download dari: https://developer.android.com/studio/releases/platform-tools
2. Extract ke folder (contoh: `C:\platform-tools`)
3. Tambahkan ke PATH environment variable

### Langkah 3: Verifikasi Koneksi

```bash
# Masuk ke folder project
cd D:\Gawean\web\ymsoftapp

# Cek apakah HP terdeteksi
adb devices
```

**Output yang benar:**
```
List of devices attached
ABC123XYZ    device
```

**Jika muncul "unauthorized":**
- Di HP, muncul popup "Allow USB Debugging?"
- Tap "Allow" atau "OK"
- Coba lagi: `adb devices`

**Jika tidak terdeteksi:**
- Coba ganti kabel USB
- Coba port USB lain di komputer
- Restart adb: `adb kill-server && adb start-server`
- Cek apakah USB Debugging aktif di HP

## 🚀 Menggunakan untuk Development

### Cara 1: Run Langsung dari Flutter (Hot Reload)

```bash
# Masuk ke folder project
cd D:\Gawean\web\ymsoftapp

# Cek device
flutter devices

# Run aplikasi langsung ke HP (akan install dan run)
flutter run

# Atau run dengan specific device
flutter run -d <device-id>
```

**Keuntungan:**
- ✅ Hot Reload (tekan `r` di terminal)
- ✅ Hot Restart (tekan `R` di terminal)
- ✅ Full Restart (tekan `q` untuk quit, lalu `flutter run` lagi)
- ✅ Log langsung muncul di terminal

### Cara 2: Build dan Install APK

```bash
# Build debug APK
flutter build apk --debug

# Install ke HP
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Atau install dengan flutter
flutter install
```

### Cara 3: Melihat Log

```bash
# Lihat log real-time
flutter logs

# Atau dengan adb
adb logcat | findstr "flutter"

# Filter log tertentu
adb logcat | findstr "PO Ops\|Budget\|Error"
```

## 🔧 Troubleshooting

### HP Tidak Terdeteksi

**1. Cek USB Debugging:**
- Pastikan USB Debugging aktif di HP
- Cek di Settings → Developer Options → USB Debugging

**2. Cek Kabel USB:**
- Gunakan kabel USB data (bukan hanya charging)
- Coba ganti kabel
- Coba port USB lain

**3. Restart ADB:**
```bash
adb kill-server
adb start-server
adb devices
```

**4. Install Driver:**
- Install USB driver untuk brand HP Anda
- Restart komputer setelah install driver

**5. Cek Mode USB:**
- Di HP, saat connect USB, pilih mode "File Transfer" atau "MTP"
- Bukan "Charging Only"

### "Unauthorized" Error

**Solusi:**
1. Di HP, muncul popup "Allow USB Debugging?"
2. Centang "Always allow from this computer"
3. Tap "Allow" atau "OK"
4. Coba lagi: `adb devices`

### "Device Offline" Error

**Solusi:**
1. Disconnect HP dari USB
2. Restart adb: `adb kill-server && adb start-server`
3. Connect HP lagi
4. Allow USB Debugging di HP
5. Coba lagi: `adb devices`

### Flutter Tidak Detect Device

**Solusi:**
```bash
# Cek dengan adb dulu
adb devices

# Jika adb detect tapi flutter tidak:
flutter doctor
flutter devices

# Restart Flutter daemon
flutter daemon --shutdown
flutter devices
```

## 📋 Quick Reference Commands

```bash
# 1. Cek device
adb devices
flutter devices

# 2. Run aplikasi ke HP
flutter run

# 3. Build APK
flutter build apk --debug

# 4. Install APK
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 5. Lihat log
flutter logs
# atau
adb logcat | findstr "flutter"

# 6. Uninstall aplikasi
adb uninstall com.ymsoft.app  # ganti dengan package name Anda

# 7. Restart adb
adb kill-server && adb start-server

# 8. Clear log
adb logcat -c
```

## ✅ Checklist Setup

- [ ] Developer Options aktif di HP
- [ ] USB Debugging aktif di HP
- [ ] HP terhubung via USB ke komputer
- [ ] Popup "Allow USB Debugging" sudah di-allow
- [ ] `adb devices` menampilkan device
- [ ] `flutter devices` menampilkan device
- [ ] Bisa run aplikasi dengan `flutter run`

## 🎯 Tips

1. **Selalu allow USB Debugging** saat pertama kali connect
2. **Centang "Always allow"** agar tidak muncul popup lagi
3. **Gunakan kabel USB data** yang bagus (bukan hanya charging)
4. **Jangan disconnect** saat sedang run aplikasi
5. **Gunakan `flutter run`** untuk development (lebih mudah hot reload)
6. **Gunakan `flutter build apk --debug`** jika ingin test install manual

## 📞 Masih Bermasalah?

Jika masih tidak bisa, coba:
1. Restart HP
2. Restart komputer
3. Install ulang USB driver
4. Coba di komputer lain
5. Cek apakah HP support USB Debugging (HP Android modern biasanya support)

