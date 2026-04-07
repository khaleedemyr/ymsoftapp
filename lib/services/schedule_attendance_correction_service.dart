import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ScheduleAttendanceCorrectionService {
  static String get baseUrl => AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// GET index data with filters (outlet_id, division_id, start_date, end_date, user_id, correction_type).
  Future<Map<String, dynamic>?> getIndexData({
    String? outletId,
    String? divisionId,
    String? startDate,
    String? endDate,
    int? userId,
    String? correctionType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return null;

      final queryParams = <String, String>{};
      if (outletId != null && outletId.isNotEmpty) queryParams['outlet_id'] = outletId;
      if (divisionId != null && divisionId.isNotEmpty) queryParams['division_id'] = divisionId;
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;
      if (userId != null) queryParams['user_id'] = userId.toString();
      if (correctionType != null && correctionType.isNotEmpty) queryParams['correction_type'] = correctionType;

      final uri = Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getIndexData: $e');
      return null;
    }
  }

  /// POST schedule correction (schedule_id, shift_id, reason).
  Future<Map<String, dynamic>> updateSchedule({
    required int scheduleId,
    int? shiftId,
    required String reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'schedule_id': scheduleId,
          'shift_id': shiftId,
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// POST attendance correction (sn, pin, scan_date, inoutmode, old_scan_date, reason).
  Future<Map<String, dynamic>> updateAttendance({
    required String sn,
    required String pin,
    required String scanDate,
    required int inoutmode,
    required String oldScanDate,
    required String reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction/attendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'sn': sn,
          'pin': pin,
          'scan_date': scanDate,
          'inoutmode': inoutmode,
          'old_scan_date': oldScanDate,
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// POST manual attendance (user_id, outlet_id, scan_date as Y-m-d H:i:s, inoutmode 1 or 2, reason).
  Future<Map<String, dynamic>> submitManualAttendance({
    required int userId,
    required int outletId,
    required String scanDate,
    required int inoutmode,
    required String reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction/manual-attendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'outlet_id': outletId,
          'scan_date': scanDate,
          'inoutmode': inoutmode,
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// GET check manual limit (user_id, scan_date as Y-m-d).
  Future<Map<String, dynamic>?> checkManualLimit({
    required int userId,
    required String scanDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction/check-manual-limit').replace(
        queryParameters: {'user_id': userId.toString(), 'scan_date': scanDate},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print('Error checkManualLimit: $e');
      return null;
    }
  }

  /// Get employees for dropdown (outlet_id, division_id) - reuse attendance report employees API.
  Future<List<Map<String, dynamic>>> getEmployees({
    String? outletId,
    String? divisionId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (outletId != null && outletId.isNotEmpty) queryParams['outlet_id'] = outletId;
      if (divisionId != null && divisionId.isNotEmpty) queryParams['division_id'] = divisionId;

      final uri = Uri.parse('$baseUrl/api/approval-app/attendance-report/employees').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body);
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getEmployees: $e');
      return [];
    }
  }
}
