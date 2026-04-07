import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_shift_models.dart';
import 'auth_service.dart';

class UserShiftService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>> getUserShifts({
    int? outletId,
    int? divisionId,
    String? startDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      print('UserShift Token retrieved: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');

      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (divisionId != null) queryParams['division_id'] = divisionId.toString();
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;

      // Use API route for approval-app
      final uri = Uri.parse('$baseUrl/api/approval-app/user-shifts')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      print('UserShift API Response Status: ${response.statusCode}');
      final bodyPreview = response.body.length > 500 
          ? '${response.body.substring(0, 500)}...' 
          : response.body;
      print('UserShift API Response Body: $bodyPreview');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('UserShift API Parsed Data keys: ${data is Map ? data.keys.toList() : 'not a map'}');
        
        // Handle Inertia response format (if data is wrapped)
        Map<String, dynamic> responseData;
        if (data is Map && data.containsKey('props')) {
          final props = data['props'];
          if (props is Map) {
            responseData = Map<String, dynamic>.from(props);
          } else {
            throw Exception('Invalid props format');
          }
        } else if (data is Map) {
          responseData = Map<String, dynamic>.from(data);
        } else {
          throw Exception('Invalid response format');
        }
        
        print('UserShift Response Data keys: ${responseData.keys.toList()}');
        
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to load user shifts');
        } catch (e) {
          throw Exception('Failed to load user shifts: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching user shifts: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> saveUserShifts({
    required int outletId,
    required int divisionId,
    required String startDate,
    required Map<int, Map<String, int?>> shifts, // {user_id: {tanggal: shift_id}}
    Map<int, Map<String, bool>>? explicitOff, // {user_id: {tanggal: true}}
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      // Convert shifts to the format expected by backend (convert int keys to string)
      final shiftsFormatted = <String, dynamic>{};
      shifts.forEach((userId, dates) {
        shiftsFormatted[userId.toString()] = dates;
      });

      // Convert explicit_off to plain object (convert int keys to string)
      final explicitOffFormatted = <String, dynamic>{};
      if (explicitOff != null) {
        explicitOff.forEach((userId, dates) {
          explicitOffFormatted[userId.toString()] = dates;
        });
      }

      final body = {
        'outlet_id': outletId,
        'division_id': divisionId,
        'start_date': startDate,
        'shifts': shiftsFormatted,
        if (explicitOffFormatted.isNotEmpty) 'explicit_off': explicitOffFormatted,
      };

      print('Saving user shifts: ${jsonEncode(body)}');

      // Use API route for approval-app
      final uri = Uri.parse('$baseUrl/api/approval-app/user-shifts');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': data['success'] ?? true,
            'message': data['message'] ?? 'Jadwal shift berhasil disimpan!',
          };
        } catch (e) {
          // If response is not JSON (e.g., redirect), treat as success
          return {
            'success': true,
            'message': 'Jadwal shift berhasil disimpan!',
          };
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to save user shifts');
        } catch (e) {
          throw Exception('Failed to save user shifts: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error saving user shifts: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

