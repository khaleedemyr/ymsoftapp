# YM Soft Approval Mobile App

Flutter mobile application for managing approvals from YM Soft ERP system.

## Features

- ✅ Splash Screen with smooth animations
- ✅ Login with email and password
- ✅ Device information tracking
- ⏳ Approval management (coming soon)
- ⏳ Real-time notifications (coming soon)

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / Xcode (for mobile development)

## Setup

1. **Install Flutter dependencies:**
```bash
cd D:\Gawean\YM\web\ymsoftapp
flutter pub get
```

2. **Update API base URL** in `lib/services/auth_service.dart`:
```dart
static const String baseUrl = 'https://your-api-domain.com';
```
Replace `your-api-domain.com` with your actual YM Soft ERP domain.

3. **Run the app:**
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   ├── splash_screen.dart   # Splash screen with logo & animation
│   ├── login_screen.dart    # Login form with validation
│   └── home_screen.dart     # Home/Approval list screen (placeholder)
├── services/
│   └── auth_service.dart    # Authentication API service
└── providers/
    └── auth_provider.dart   # Auth state management (Provider)
```

## API Integration

The app integrates with YM Soft ERP API using dedicated Approval App endpoints (separate from web and member app):

### Login Endpoint
- **URL:** `POST /api/approval-app/auth/login`
- **Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password",
  "imei": "device-id",  // Optional
  "device_info": {      // Optional
    "platform": "android",
    "model": "device-model",
    "manufacturer": "manufacturer-name",
    "version": "android-version"
  }
}
```
- **Response:**
```json
{
  "access_token": "token-string",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "nama_lengkap": "User Name",
    ...
  }
}
```

### Authentication
- Token is stored in SharedPreferences
- Token is sent in `Authorization: Bearer {token}` header for authenticated requests
- Token is verified using `/api/approval-app/auth/me` endpoint
- Uses custom middleware `ApprovalAppAuth` (different from web and member app)

### Available Endpoints
- `POST /api/approval-app/auth/login` - Login
- `GET /api/approval-app/auth/me` - Get current user (requires auth)
- `POST /api/approval-app/auth/logout` - Logout (requires auth)

## Configuration

### Update Base URL
Edit `lib/services/auth_service.dart`:
```dart
static const String baseUrl = 'https://your-domain.com';
```

### Android Configuration
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 33+

### iOS Configuration
- Minimum iOS: 12.0
- Requires Info.plist configuration for network requests

## Development Notes

- Uses Provider for state management
- SharedPreferences for local storage
- Device info is automatically collected and sent during login
- Splash screen checks authentication status and routes accordingly
- Login form includes email validation and password visibility toggle

## Next Steps

1. Implement approval list screen
2. Add approval detail modal
3. Implement approve/reject functionality
4. Add push notifications
5. Add offline support

## Troubleshooting

### Build Errors
- Run `flutter clean` then `flutter pub get`
- Ensure Flutter SDK is up to date: `flutter upgrade`

### API Connection Issues
- Verify base URL is correct
- Check network permissions in AndroidManifest.xml / Info.plist
- Ensure API server allows CORS for mobile requests

### Login Issues
- Verify email and password format
- Check API response format matches expected structure
- Review error messages in console

