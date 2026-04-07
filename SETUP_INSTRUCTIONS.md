# Setup Instructions

## Initial Setup

1. **Navigate to project directory:**
```bash
cd D:\Gawean\YM\web\ymsoftapp
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Update API Configuration:**
   - Open `lib/services/auth_service.dart`
   - Update `baseUrl` constant with your API domain:
   ```dart
   static const String baseUrl = 'https://your-domain.com';
   ```

## Running the App

### Android
```bash
flutter run
```
Or select an Android device/emulator and run from IDE.

### iOS
```bash
flutter run
```
Requires macOS and Xcode for iOS development.

## Building

### Android APK
```bash
flutter build apk
```

### Android App Bundle
```bash
flutter build appbundle
```

### iOS
```bash
flutter build ios
```

## Testing

Run tests:
```bash
flutter test
```

## Important Notes

1. **API Base URL:** Must be updated before running the app
2. **Network Permissions:** Android and iOS require network permissions configured
3. **Token Storage:** Tokens are stored securely using SharedPreferences
4. **Device Info:** App automatically collects device information for security

## API Endpoints Used

- `POST /api/login` - User authentication
- `GET /api/user` - User information (future use)

Make sure these endpoints are accessible from your mobile app domain.
