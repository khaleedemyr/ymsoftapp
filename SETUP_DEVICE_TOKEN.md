# Setup Device Token Registration - Quick Guide

## ✅ Yang Sudah Dilakukan

1. ✅ Service `DeviceTokenService` sudah dibuat
2. ✅ `AuthProvider` sudah diupdate untuk auto-register device token setelah login
3. ✅ Firebase initialization sudah ditambahkan di `main.dart`
4. ✅ Dependencies sudah ditambahkan ke `pubspec.yaml`

## 📋 Langkah Setup

### 1. Install Dependencies
```bash
cd D:\Gawean\web\ymsoftapp
flutter pub get
```

### 2. Pastikan Firebase Sudah Dikonfigurasi
- ✅ File `android/app/google-services.json` sudah ada
- Jika belum, download dari Firebase Console

### 3. Run App
```bash
flutter run
```

### 4. Test Login
- Login dengan user yang valid
- Cek console/log untuk:
  - "FCM Token obtained: ..."
  - "DeviceTokenService: Device token registered successfully"

### 5. Verifikasi di Database
```sql
SELECT * FROM employee_device_tokens WHERE user_id = 26;
```

## 🔍 Troubleshooting

### Device token tidak terdaftar

1. **Cek log Flutter:**
   - Buka console saat login
   - Cari log "FCM Token" atau "DeviceTokenService"

2. **Cek log backend:**
   ```bash
   tail -f storage/logs/laravel.log
   ```

3. **Cek permission:**
   - Pastikan user mengizinkan push notification
   - Cek di device settings

4. **Cek koneksi:**
   - Pastikan app bisa connect ke backend
   - Test endpoint: `POST /api/approval-app/device-token/register`

### Error: Firebase not initialized
- Pastikan `google-services.json` ada
- Pastikan `firebase_core` sudah di-install
- Restart app

### Error: Permission denied
- User perlu mengizinkan push notification
- Cek permission di device settings

## 📝 Catatan

- Device token akan otomatis terdaftar setelah login berhasil
- Jika registration gagal, login tetap berhasil (tidak blocking)
- Token akan di-update jika user login lagi dengan device yang sama
- Token akan di-deactivate jika user logout (perlu implementasi)

## 🎯 Testing Push Notification

Setelah device token terdaftar, test push notification:

```bash
# Di backend
php artisan test:notification-push 26
```

Atau via Tinker:
```php
use App\Models\Notification;

Notification::create([
    'user_id' => 26,
    'title' => 'Test Push Notification',
    'message' => 'Ini adalah test notification',
    'type' => 'test',
]);
```

