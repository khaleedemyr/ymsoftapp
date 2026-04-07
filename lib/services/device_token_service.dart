import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_service.dart';

class DeviceTokenService {
  static String get baseUrl => '${AuthService.baseUrl}/api/approval-app';
  
  /// Register device token to backend
  /// This should be called after successful login
  static Future<bool> registerDeviceToken(String deviceToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        print('DeviceTokenService: No auth token found, skipping device token registration');
        return false;
      }

      // Get device info
      String? deviceId;
      String deviceType = 'android';
      String? appVersion;

      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceId = androidInfo.id;
          deviceType = 'android';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceId = iosInfo.identifierForVendor;
          deviceType = 'ios';
        }

        // Get app version (optional)
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          appVersion = packageInfo.version;
        } catch (e) {
          // Package info is optional
          print('DeviceTokenService: Could not get app version: $e');
        }
      } catch (e) {
        print('DeviceTokenService: Error getting device info: $e');
        // Continue with defaults
      }

      final response = await http.post(
        Uri.parse('$baseUrl/device-token/register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'device_token': deviceToken,
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
          if (appVersion != null) 'app_version': appVersion,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('DeviceTokenService: Device token registered successfully');
          return true;
        } else {
          print('DeviceTokenService: Registration failed: ${data['message']}');
          return false;
        }
      } else {
        print('DeviceTokenService: Registration failed with status ${response.statusCode}');
        print('DeviceTokenService: Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('DeviceTokenService: Error registering device token: $e');
      return false;
    }
  }

  /// Unregister device token (on logout)
  static Future<bool> unregisterDeviceToken(String deviceToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        print('DeviceTokenService: No auth token found, skipping device token unregistration');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/device-token/unregister'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'device_token': deviceToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('DeviceTokenService: Device token unregistered successfully');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('DeviceTokenService: Error unregistering device token: $e');
      return false;
    }
  }
}

