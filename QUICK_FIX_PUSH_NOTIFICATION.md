# Quick Fix: Push Notification Tidak Muncul di Mobile App

## Yang Sudah Ditambahkan

1. ✅ **PushNotificationService** - Service untuk handle push notification
2. ✅ **Local Notifications** - Untuk menampilkan notification di foreground
3. ✅ **Background Handler** - Untuk handle notification saat app di background
4. ✅ **Android Permissions** - Permission untuk notification
5. ✅ **Notification Channel** - Channel untuk Android 8.0+

## Langkah Fix

### 1. Install Dependencies Baru
```bash
cd D:\Gawean\web\ymsoftapp
flutter pub get
```

### 2. Rebuild App (PENTING!)
```bash
flutter clean
flutter pub get
flutter run
```

### 3. Login Lagi di App
- Login dengan user yang valid
- Cek console untuk log:
  - "FCM Token obtained: ..."
  - "Device token registered successfully"
  - "Push notification service initialized"

### 4. Verifikasi Device Token Terdaftar
```sql
SELECT * FROM employee_device_tokens WHERE user_id = 26 AND is_active = 1;
```

### 5. Test Push Notification
```bash
php artisan test:notification-push 26
```

### 6. Cek Hasil
- **App terbuka**: Notification muncul sebagai local notification
- **App di background**: Notification muncul di notification tray
- **App terminated**: Notification muncul, tap untuk buka app

## Yang Perlu Dicek

1. **Permission**: Pastikan notification permission sudah diberikan
2. **Device Token**: Pastikan terdaftar di database
3. **Log Backend**: Pastikan "FCM V1 notification sent successfully"
4. **Log Flutter**: Cek console untuk error atau log notification

## Jika Masih Tidak Muncul

1. **Cek log Flutter**: 
   - Apakah ada "Received foreground message"?
   - Apakah ada error?

2. **Cek log backend**:
   - Apakah "employee_success" > 0?
   - Apakah ada error?

3. **Test manual**:
   - Cek device token di database
   - Test via Firebase Console dengan token tersebut

4. **Rebuild app**:
   - Pastikan sudah `flutter clean` dan rebuild
   - Pastikan semua dependencies ter-install

