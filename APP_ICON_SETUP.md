# App Icon Setup Guide

## Menggunakan flutter_launcher_icons (Recommended)

### 1. Install flutter_launcher_icons
```bash
flutter pub get
```

### 2. Update pubspec.yaml
Tambahkan konfigurasi berikut di `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo-icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/images/logo-icon.png"
```

### 3. Generate Icons
```bash
flutter pub run flutter_launcher_icons
```

## Manual Setup (Alternative)

### Android

1. Copy `assets/images/logo-icon.png` ke folder berikut dengan ukuran yang sesuai:
   - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
   - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
   - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
   - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
   - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

2. Untuk adaptive icon (Android 8.0+), buat:
   - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
   - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`

### iOS

1. Buka Xcode project: `ios/Runner.xcworkspace`
2. Pilih `Runner` di project navigator
3. Pilih `Assets.xcassets` > `AppIcon`
4. Drag dan drop `assets/images/logo-icon.png` ke semua ukuran yang diperlukan

## Catatan

- Pastikan logo-icon.png memiliki ukuran minimal 1024x1024 untuk kualitas terbaik
- Format PNG dengan transparansi untuk hasil terbaik
- Setelah update icon, jalankan `flutter clean` dan rebuild aplikasi

