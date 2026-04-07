# Firebase Setup untuk Push Notification

## Status
✅ Device token registration sudah diimplementasikan di Flutter app
✅ Otomatis register device token setelah login berhasil

## Dependencies yang Ditambahkan

Tambahkan ke `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10
  package_info_plus: ^8.0.0
```

Jalankan:
```bash
flutter pub get
```

## Setup Firebase

### 1. Android Setup
✅ File `google-services.json` sudah ada di `android/app/`
- Pastikan file sudah sesuai dengan Firebase project

### 2. iOS Setup (jika perlu)
- Download `GoogleService-Info.plist` dari Firebase Console
- Tambahkan ke `ios/Runner/GoogleService-Info.plist`

### 3. Generate Firebase Options (Optional)
Jika menggunakan FlutterFire CLI:
```bash
flutterfire configure
```

Atau buat file `lib/firebase_options.dart` secara manual jika diperlukan.

## Cara Kerja

1. **User login** → `AuthProvider.login()` dipanggil
2. **Login berhasil** → `_registerDeviceToken()` dipanggil otomatis
3. **Request permission** → Minta izin push notification
4. **Get FCM token** → Ambil token dari Firebase Messaging
5. **Register ke backend** → Kirim token ke `/api/approval-app/device-token/register`

## Testing

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run app:**
   ```bash
   flutter run
   ```

3. **Login dengan user yang valid**

4. **Cek console/log:**
   - Harus ada log: "FCM Token obtained: ..."
   - Harus ada log: "DeviceTokenService: Device token registered successfully"

5. **Cek database:**
   ```sql
   SELECT * FROM employee_device_tokens WHERE user_id = {user_id};
   ```

6. **Test push notification:**
   ```bash
   php artisan test:notification-push {user_id}
   ```

## Troubleshooting

### Error: Firebase not initialized
- Pastikan `google-services.json` ada di `android/app/`
- Pastikan `firebase_core` sudah di-install
- Cek log untuk error detail

### Error: Permission denied
- User perlu mengizinkan push notification
- Cek permission di device settings

### Error: Token registration failed
- Cek koneksi internet
- Cek apakah user sudah login (ada auth token)
- Cek log backend untuk error detail
- Pastikan endpoint `/api/approval-app/device-token/register` sudah tersedia

### Token tidak terdaftar di database
- Cek log Flutter app untuk error
- Cek log backend (Laravel log)
- Pastikan tabel `employee_device_tokens` sudah dibuat
- Pastikan user_id valid

## Next Steps (Optional)

Untuk handle push notification yang diterima:
1. Setup background message handler
2. Setup foreground message handler  
3. Handle notification tap untuk navigasi

Contoh:
```dart
// Di main.dart atau service terpisah
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Got a message whilst in the foreground!');
  print('Message data: ${message.data}');
  
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
    // Show local notification
  }
});

// Background message handler (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}
```

