import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AuthService {
  // API base URL for YM Soft ERP
  static const String baseUrl = 'https://ymsofterp.com';
  
  // Storage URL for file access (images, documents, etc.)
  static const String storageUrl = 'https://ymsofterp.com';
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Get device info
      String? deviceId;
      Map<String, dynamic>? deviceInfo;
      
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceId = androidInfo.id;
          deviceInfo = {
            'platform': 'android',
            'model': androidInfo.model,
            'manufacturer': androidInfo.manufacturer,
            'version': androidInfo.version.release,
          };
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceId = iosInfo.identifierForVendor;
          deviceInfo = {
            'platform': 'ios',
            'model': iosInfo.model,
            'name': iosInfo.name,
            'version': iosInfo.systemVersion,
          };
        }
      } catch (e) {
        // Device info is optional
      }

      // Increase timeout to 60 seconds and add retry logic
      http.Response? response;
      int retryCount = 0;
      const maxRetries = 2;
      final loginUrl = '$baseUrl/api/approval-app/auth/login';
      
      print('Login: Attempting to connect to $loginUrl');
      
      while (retryCount <= maxRetries) {
        try {
          print('Login: Attempt ${retryCount + 1} of ${maxRetries + 1}');
          final startTime = DateTime.now();
          
          response = await http.post(
            Uri.parse(loginUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
              if (deviceId != null) 'device_id': deviceId,
              if (deviceInfo != null) 'device_info': deviceInfo,
            }),
          ).timeout(
            const Duration(seconds: 60), // Increased from 30 to 60 seconds
            onTimeout: () {
              print('Login: Request timeout after 60 seconds');
              throw TimeoutException('Connection timeout. Please check your internet connection.');
            },
          );
          
          final duration = DateTime.now().difference(startTime);
          print('Login: Request completed in ${duration.inSeconds} seconds');
          break; // Success, exit retry loop
        } catch (e) {
          print('Login: Attempt ${retryCount + 1} failed: $e');
          if (e is TimeoutException && retryCount < maxRetries) {
            retryCount++;
            print('Login: Retrying in ${retryCount * 2} seconds...');
            await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
            continue;
          }
          rethrow; // Re-throw if not timeout or max retries reached
        }
      }
      
      if (response == null) {
        print('Login: All attempts failed');
        throw TimeoutException('Connection timeout after ${maxRetries + 1} attempts. Please check your internet connection and try again.');
      }

      // Debug: Print response for troubleshooting
      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          // Check if response has access_token (even if success field is missing)
          if (data['access_token'] != null) {
            // Save token and user data
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', data['access_token'] ?? '');
            await prefs.setString('user_data', jsonEncode(data['user'] ?? {}));
            
            return {
              'success': true,
              'token': data['access_token'],
              'user': data['user'],
            };
          } else if (data['success'] == false) {
            return {
              'success': false,
              'message': data['message'] ?? 'Login failed. Please check your credentials.',
            };
          } else {
            return {
              'success': false,
              'message': 'Invalid response format. Please try again.',
            };
          }
        } catch (e) {
          print('JSON Parse Error: $e');
          print('Response Body: ${response.body}');
          return {
            'success': false,
            'message': 'Failed to parse server response. Please try again.',
          };
        }
      } else {
        // Handle non-200 status codes
        String errorMessage = 'Login failed';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData is Map) {
              errorMessage = errorData['message'] ?? 
                           (errorData['errors'] != null ? errorData['errors'].toString() : null) ??
                           'Login failed. Please check your credentials.';
            } else {
              errorMessage = 'Login failed. Status: ${response.statusCode}';
            }
          } else {
            errorMessage = 'Server returned error ${response.statusCode}. Please try again.';
          }
        } catch (e) {
          // If response is not JSON, show raw response (limited length)
          final bodyPreview = response.body.length > 100 
              ? '${response.body.substring(0, 100)}...' 
              : response.body;
          errorMessage = 'Server error (${response.statusCode}): $bodyPreview';
        }
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      // More detailed error handling
      String errorMessage = 'Network error';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup') ||
                 e.toString().contains('Network is unreachable')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection.';
      } else if (e.toString().contains('HandshakeException') ||
                 e.toString().contains('CertificateException')) {
        errorMessage = 'SSL certificate error. Please contact administrator.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Server refused connection. Please try again later.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      print('Login Error: $e');
      print('Error Type: ${e.runtimeType}');
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  Future<bool> verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static const _secureStorage = FlutterSecureStorage();

  /// Remember Me: get saved email, password (secure), and checkbox state.
  Future<Map<String, dynamic>> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final email = prefs.getString('remembered_email');
    String? password;
    if (rememberMe) {
      try {
        password = await _secureStorage.read(key: 'remembered_password');
      } catch (_) {}
    }
    return {'remember_me': rememberMe, 'email': email, 'password': password};
  }

  /// Remember Me: save or clear email and password based on checkbox. Password disimpan di secure storage.
  Future<void> setRememberMe(bool rememberMe, String? email, String? password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', rememberMe);
    if (rememberMe) {
      if (email != null && email.trim().isNotEmpty) {
        await prefs.setString('remembered_email', email.trim());
      } else {
        await prefs.remove('remembered_email');
      }
      if (password != null && password.isNotEmpty) {
        await _secureStorage.write(key: 'remembered_password', value: password);
      } else {
        await _secureStorage.delete(key: 'remembered_password');
      }
    } else {
      await prefs.remove('remembered_email');
      await _secureStorage.delete(key: 'remembered_password');
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<Map<String, dynamic>> refreshUserData() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          // Save updated user data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(data['user']));
          
          return {
            'success': true,
            'user': data['user'],
          };
        }
      }
      return {'success': false, 'message': 'Failed to refresh user data'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> uploadBanner(String imagePath) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/user/upload-banner'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final file = await http.MultipartFile.fromPath('banner', imagePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Refresh user data after upload
          await refreshUserData();
          return data;
        }
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to upload banner',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(String imagePath) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/user/upload-avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final file = await http.MultipartFile.fromPath('avatar', imagePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Refresh user data after upload
          await refreshUserData();
          return data;
        }
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to upload avatar',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Update Profile
  Future<Map<String, dynamic>> updateProfile({
    required String namaLengkap,
    String? namaPanggilan,
    String? email,
    String? noHp,
    File? avatar,
    // Personal
    String? jenisKelamin,
    String? tempatLahir,
    String? tanggalLahir,
    String? suku,
    String? agama,
    String? statusPernikahan,
    String? golonganDarah,
    // Work
    String? pinPos,
    String? pinPayroll,
    String? imei,
    // Contact
    String? alamat,
    String? alamatKtp,
    String? namaKontakDarurat,
    String? noHpKontakDarurat,
    String? hubunganKontakDarurat,
    // Documents
    String? noKtp,
    String? nomorKk,
    String? npwpNumber,
    String? bpjsHealthNumber,
    String? bpjsEmploymentNumber,
    String? lastEducation,
    String? nameSchoolCollege,
    String? schoolCollegeMajor,
    String? namaRekening,
    String? noRekening,
    File? fotoKtp,
    File? fotoKk,
    File? colorPhoto,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/api/approval-app/user/update-profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Basic fields
      request.fields['nama_lengkap'] = namaLengkap;
      if (namaPanggilan != null) request.fields['nama_panggilan'] = namaPanggilan;
      if (email != null) request.fields['email'] = email;
      if (noHp != null) request.fields['no_hp'] = noHp;

      // Personal fields
      if (jenisKelamin != null) request.fields['jenis_kelamin'] = jenisKelamin;
      if (tempatLahir != null) request.fields['tempat_lahir'] = tempatLahir;
      if (tanggalLahir != null) request.fields['tanggal_lahir'] = tanggalLahir;
      if (suku != null) request.fields['suku'] = suku;
      if (agama != null) request.fields['agama'] = agama;
      if (statusPernikahan != null) request.fields['status_pernikahan'] = statusPernikahan;
      if (golonganDarah != null) request.fields['golongan_darah'] = golonganDarah;

      // Work fields
      if (pinPos != null) request.fields['pin_pos'] = pinPos;
      if (pinPayroll != null) request.fields['pin_payroll'] = pinPayroll;
      if (imei != null) request.fields['imei'] = imei;

      // Contact fields
      if (alamat != null) request.fields['alamat'] = alamat;
      if (alamatKtp != null) request.fields['alamat_ktp'] = alamatKtp;
      if (namaKontakDarurat != null) request.fields['nama_kontak_darurat'] = namaKontakDarurat;
      if (noHpKontakDarurat != null) request.fields['no_hp_kontak_darurat'] = noHpKontakDarurat;
      if (hubunganKontakDarurat != null) request.fields['hubungan_kontak_darurat'] = hubunganKontakDarurat;

      // Documents fields
      if (noKtp != null) request.fields['no_ktp'] = noKtp;
      if (nomorKk != null) request.fields['nomor_kk'] = nomorKk;
      if (npwpNumber != null) request.fields['npwp_number'] = npwpNumber;
      if (bpjsHealthNumber != null) request.fields['bpjs_health_number'] = bpjsHealthNumber;
      if (bpjsEmploymentNumber != null) request.fields['bpjs_employment_number'] = bpjsEmploymentNumber;
      if (lastEducation != null) request.fields['last_education'] = lastEducation;
      if (nameSchoolCollege != null) request.fields['name_school_college'] = nameSchoolCollege;
      if (schoolCollegeMajor != null) request.fields['school_college_major'] = schoolCollegeMajor;
      if (namaRekening != null) request.fields['nama_rekening'] = namaRekening;
      if (noRekening != null) request.fields['no_rekening'] = noRekening;

      // File uploads
      if (avatar != null) {
        final file = await http.MultipartFile.fromPath('avatar', avatar.path);
        request.files.add(file);
      }
      if (fotoKtp != null) {
        final file = await http.MultipartFile.fromPath('foto_ktp', fotoKtp.path);
        request.files.add(file);
      }
      if (fotoKk != null) {
        final file = await http.MultipartFile.fromPath('foto_kk', fotoKk.path);
        request.files.add(file);
      }
      if (colorPhoto != null) {
        final file = await http.MultipartFile.fromPath('upload_latest_color_photo', colorPhoto.path);
        request.files.add(file);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await refreshUserData();
          return data;
        }
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to update profile',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Update Password
  Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/user/update-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to update password',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Update Signature
  Future<Map<String, dynamic>> updateSignature({
    Uint8List? signatureData,
    File? signatureFile,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/user/update-signature'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      if (signatureFile != null) {
        final file = await http.MultipartFile.fromPath('signature', signatureFile.path);
        request.files.add(file);
      } else if (signatureData != null) {
        // Save to temp file first
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(signatureData);
        final file = await http.MultipartFile.fromPath('signature', tempFile.path);
        request.files.add(file);
      } else {
        return {'success': false, 'message': 'No signature data provided'};
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await refreshUserData();
          return data;
        }
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to update signature',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get Outlets
  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('No token found for getOutlets');
        return [];
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      // Try approval-app endpoint first (mobile app uses Bearer token)
      try {
        print('Trying endpoint: /api/approval-app/outlets');
        final response = await http.get(
          Uri.parse('$baseUrl/api/approval-app/outlets'),
          headers: headers,
        );

        print('GetOutlets (/api/approval-app/outlets) response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('GetOutlets parsed data type: ${data.runtimeType}');
          
          if (data is Map) {
            if (data['success'] == true && data['outlets'] != null) {
              print('GetOutlets: Found outlets in approval-app endpoint');
              return List<Map<String, dynamic>>.from(data['outlets']);
            }
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
          } else if (data is List) {
            return List<Map<String, dynamic>>.from(data);
          }
        } else {
          print('GetOutlets (/api/approval-app/outlets) error: ${response.statusCode}');
        }
      } catch (e) {
        print('Error with /api/approval-app/outlets: $e');
      }

      // Fallback to web app endpoint: /api/outlets (session-based, might not work)
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/outlets'),
          headers: headers,
        );

        print('GetOutlets (/api/outlets) response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('GetOutlets parsed data type: ${data.runtimeType}');
          
          // Web app expects direct array response (outlets.value = response.data)
          if (data is List) {
            print('GetOutlets: Response is a List with ${data.length} items');
            return List<Map<String, dynamic>>.from(data);
          } else if (data is Map) {
            // Handle object response with different possible structures
            if (data['success'] == true && data['outlets'] != null) {
              print('GetOutlets: Found outlets in success.outlets');
              return List<Map<String, dynamic>>.from(data['outlets']);
            }
            if (data['data'] != null && data['data'] is List) {
              print('GetOutlets: Found outlets in data');
              return List<Map<String, dynamic>>.from(data['data']);
            }
            if (data['outlets'] != null && data['outlets'] is List) {
              print('GetOutlets: Found outlets directly');
              return List<Map<String, dynamic>>.from(data['outlets']);
            }
            print('GetOutlets: Unknown response format: $data');
          }
        } else {
          print('GetOutlets (/api/outlets) error: ${response.statusCode}');
        }
      } catch (e) {
        print('Error with /api/outlets: $e');
      }

      // Fallback to approval-app endpoint
      try {
        print('Trying fallback endpoint: /api/approval-app/outlets');
        final response = await http.get(
          Uri.parse('$baseUrl/api/approval-app/outlets'),
          headers: headers,
        );

        print('GetOutlets (/api/approval-app/outlets) response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            if (data['success'] == true && data['outlets'] != null) {
              print('GetOutlets: Found outlets in approval-app endpoint');
              return List<Map<String, dynamic>>.from(data['outlets']);
            }
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
          } else if (data is List) {
            return List<Map<String, dynamic>>.from(data);
          }
        }
      } catch (e) {
        print('Error with /api/approval-app/outlets: $e');
      }
      
      return [];
    } catch (e, stackTrace) {
      print('Error loading outlets: $e');
      print('Error stack trace: $stackTrace');
      return [];
    }
  }

  // Get User PINs
  Future<List<Map<String, dynamic>>> getUserPins() async {
    try {
      final token = await getToken();
      if (token == null) {
        print('No token found for getUserPins');
        return [];
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      // Try /api/user-pins with Bearer token (same endpoint as web, but with Bearer auth)
      // Note: This might require backend to accept Bearer token for this route
      try {
        print('Trying endpoint: /api/user-pins with Bearer token');
        final response = await http.get(
          Uri.parse('$baseUrl/api/user-pins'),
          headers: headers,
        );

        print('GetUserPins (/api/user-pins) response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('GetUserPins parsed data type: ${data.runtimeType}');
          
          // Web app expects direct array response (userPins.value = response.data)
          if (data is List) {
            print('GetUserPins: Response is a List with ${data.length} items');
            return List<Map<String, dynamic>>.from(data);
          } else if (data is Map) {
            // Handle object response
            if (data['success'] == true) {
              if (data['pins'] != null && data['pins'] is List) {
                print('GetUserPins: Found pins in success.pins');
                return List<Map<String, dynamic>>.from(data['pins']);
              }
              if (data['data'] != null && data['data'] is List) {
                print('GetUserPins: Found pins in success.data');
                return List<Map<String, dynamic>>.from(data['data']);
              }
            }
            if (data['pins'] != null && data['pins'] is List) {
              print('GetUserPins: Found pins directly');
              return List<Map<String, dynamic>>.from(data['pins']);
            }
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
          }
        } else {
          print('GetUserPins (/api/user-pins) error: ${response.statusCode}');
          if (response.statusCode == 401) {
            print('GetUserPins: Unauthenticated - endpoint may require session auth');
          }
        }
      } catch (e) {
        print('Error with /api/user-pins: $e');
      }

      // Try approval-app endpoint (might not exist yet)
      try {
        print('Trying endpoint: /api/approval-app/user/pins');
        final response = await http.get(
          Uri.parse('$baseUrl/api/approval-app/user/pins'),
          headers: headers,
        );

        print('GetUserPins (/api/approval-app/user/pins) response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('GetUserPins parsed data type: ${data.runtimeType}');
          
          if (data is Map) {
            if (data['success'] == true) {
              if (data['pins'] != null && data['pins'] is List) {
                print('GetUserPins: Found pins in approval-app/user/pins endpoint');
                return List<Map<String, dynamic>>.from(data['pins']);
              }
              if (data['data'] != null && data['data'] is List) {
                print('GetUserPins: Found pins in data field');
                return List<Map<String, dynamic>>.from(data['data']);
              }
            }
            if (data['pins'] != null && data['pins'] is List) {
              print('GetUserPins: Found pins directly in response');
              return List<Map<String, dynamic>>.from(data['pins']);
            }
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
          } else if (data is List) {
            print('GetUserPins: Response is a List with ${data.length} items');
            return List<Map<String, dynamic>>.from(data);
          }
        } else {
          print('GetUserPins (/api/approval-app/user/pins) error: ${response.statusCode}');
          if (response.statusCode == 404) {
            print('GetUserPins: Endpoint not found - may need to be created in backend');
          }
        }
      } catch (e) {
        print('Error with /api/approval-app/user/pins: $e');
      }
      
      return [];
    } catch (e, stackTrace) {
      print('Error loading user pins: $e');
      print('Error stack trace: $stackTrace');
      return [];
    }
  }

  // Add User PIN
  Future<Map<String, dynamic>> addUserPin({
    required int outletId,
    required String pin,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/user/pins'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'outlet_id': outletId,
          'pin': pin,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to add PIN',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Delete User PIN
  Future<Map<String, dynamic>> deleteUserPin(int pinId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/user/pins/$pinId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to delete PIN',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

