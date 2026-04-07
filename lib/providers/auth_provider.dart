import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/device_token_service.dart';
import '../services/push_notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _authService.login(email, password);
    
    if (result['success']) {
      _isAuthenticated = true;
      _token = result['token'];
      _user = result['user'];
      notifyListeners();
      
      // Register device token for push notifications
      _registerDeviceToken();
    }
    
    return result;
  }
  
  /// Register device token after successful login
  Future<void> _registerDeviceToken() async {
    try {
      // Ensure push notification service is initialized
      await PushNotificationService.initialize();
      
      // Get FCM token
      final token = await PushNotificationService.getToken();
      if (token != null) {
        print('FCM Token obtained: ${token.substring(0, 20)}...');
        // Register token to backend
        final success = await DeviceTokenService.registerDeviceToken(token);
        if (success) {
          print('Device token registered successfully');
        } else {
          print('Failed to register device token to backend');
        }
      } else {
        print('FCM Token is null - permission may be denied');
      }
    } catch (e) {
      print('Error registering device token: $e');
      // Don't fail login if device token registration fails
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final token = await _authService.getToken();
    if (token != null) {
      final isValid = await _authService.verifyToken(token);
      if (isValid) {
        _isAuthenticated = true;
        _token = token;
        _user = await _authService.getUserData();
        notifyListeners();
      }
    }
  }
}

