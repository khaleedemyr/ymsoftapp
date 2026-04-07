# Troubleshooting Push Notification di Mobile App

## Status
✅ Backend sudah mengirim push notification (V1 API berhasil)
✅ Device token sudah terdaftar
❌ Notification belum muncul di mobile app

## Checklist

### 1. Device Token Terdaftar
Cek apakah device token sudah terdaftar di database:
```sql
SELECT * FROM employee_device_tokens WHERE user_id = 26 AND is_active = 1;
```

### 2. Install Dependencies
Pastikan sudah install dependencies baru:
```bash
cd D:\Gawean\web\ymsoftapp
flutter pub get
```

### 3. Rebuild App
Setelah menambahkan dependencies, rebuild app:
```bash
flutter clean
flutter pub get
flutter run
```

### 4. Cek Permission
Pastikan permission notification sudah diberikan:
- Android: Settings > Apps > ymsoftapp > Notifications (harus ON)
- iOS: Settings > Notifications > ymsoftapp (harus Allow)

### 5. Cek Log Flutter
Saat login, cek console untuk:
- "FCM Token obtained: ..."
- "Device token registered successfully"
- "Push notification service initialized"

### 6. Test Push Notification
Setelah login, test dengan:
```bash
php artisan test:notification-push 26
```

Cek log Flutter app untuk:
- "Received foreground message: ..." (jika app sedang terbuka)
- Notification muncul di notification tray

## Masalah Umum

### Notification tidak muncul saat app terbuka (foreground)
- ✅ Sudah di-handle dengan `FirebaseMessaging.onMessage`
- ✅ Akan menampilkan local notification
- Cek log: "Received foreground message"

### Notification tidak muncul saat app di background
- ✅ Sudah di-handle dengan background handler
- Pastikan background handler sudah di-register di `main.dart`
- Cek log: "Handling background message"

### Notification tidak muncul saat app terminated
- ✅ Sudah di-handle dengan `getInitialMessage`
- Cek log saat app dibuka: "App opened from notification"

### Permission denied
- User perlu mengizinkan notification di device settings
- Cek log: "Push notification permission: ..."

### Device token tidak terdaftar
- Pastikan login berhasil
- Cek log: "FCM Token obtained" dan "Device token registered successfully"
- Cek database: `SELECT * FROM employee_device_tokens WHERE user_id = 26;`

## Testing Steps

1. **Login di app** → Cek log untuk "FCM Token obtained"
2. **Cek database** → Pastikan token terdaftar
3. **Test push** → `php artisan test:notification-push 26`
4. **Cek log backend** → Pastikan "FCM V1 notification sent successfully"
5. **Cek log Flutter** → Pastikan "Received foreground message" atau notification muncul

## Next Steps

Jika masih tidak muncul:
1. Cek log Flutter app untuk error
2. Cek log backend untuk detail pengiriman
3. Test dengan device token langsung via Firebase Console
4. Pastikan app sudah rebuild setelah menambahkan dependencies

