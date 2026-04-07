import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class AttendanceService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Get attendance data (main index) - API endpoint
  Future<Map<String, dynamic>?> getAttendanceData({
    int? bulan,
    int? tahun,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        print('❌ AttendanceService: No token found or token is empty');
        return null;
      }
      
      print('🔑 AttendanceService: Token found (length: ${token.length})');

      final queryParams = <String, String>{};
      if (bulan != null) queryParams['bulan'] = bulan.toString();
      if (tahun != null) queryParams['tahun'] = tahun.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/attendance/data').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      print('🌐 AttendanceService: Calling $uri');
      print('🌐 AttendanceService: Query params: $queryParams');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('🌐 AttendanceService: Status code: ${response.statusCode}');
      print('🌐 AttendanceService: Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🌐 AttendanceService: Success: ${data['success']}');
        if (data['success'] == true) {
          print('🌐 AttendanceService: Data keys: ${data.keys.toList()}');
          return data;
        } else {
          print('🌐 AttendanceService: API returned success=false');
        }
      } else {
        print('🌐 AttendanceService: Non-200 status: ${response.statusCode}');
        print('🌐 AttendanceService: Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      }

      return null;
    } catch (e) {
      print('❌ Error getting attendance data: $e');
      return null;
    }
  }

  // Get calendar data
  Future<Map<String, dynamic>?> getCalendarData({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/attendance/calendar-data').replace(
          queryParameters: {
            'start_date': startDate,
            'end_date': endDate,
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('Error getting calendar data: $e');
      return null;
    }
  }

  // Submit absent request
  Future<Map<String, dynamic>> submitAbsentRequest({
    required int leaveTypeId,
    required String dateFrom,
    required String dateTo,
    required String reason,
    required List<int> approvers,
    List<File>? documents,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/attendance/absent-request'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add form fields
      request.fields['leave_type_id'] = leaveTypeId.toString();
      request.fields['date_from'] = dateFrom;
      request.fields['date_to'] = dateTo;
      request.fields['reason'] = reason;
      
      // Add approvers as array - Laravel expects approvers[0], approvers[1], etc.
      for (var i = 0; i < approvers.length; i++) {
        request.fields['approvers[$i]'] = approvers[i].toString();
      }

      // Add files if provided - Laravel expects documents[0], documents[1], etc.
      if (documents != null && documents.isNotEmpty) {
        for (var i = 0; i < documents.length; i++) {
          final file = documents[i];
          if (await file.exists()) {
            final fileExtension = file.path.split('.').last.toLowerCase();
            final contentType = _getContentType(fileExtension);
            
            final multipartFile = await http.MultipartFile.fromPath(
              'documents[$i]', // Use indexed array format for Laravel
              file.path,
              filename: file.path.split('/').last,
              contentType: contentType,
            );
            request.files.add(multipartFile);
          }
        }
      }

      // Send request
      print('🟡 Sending multipart request...');
      final streamedResponse = await request.send();
      print('🟡 Response status code: ${streamedResponse.statusCode}');
      final response = await http.Response.fromStream(streamedResponse);
      print('🟡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ Request successful: $result');
        return result;
      }

      print('❌ Request failed with status: ${response.statusCode}');
      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to submit absent request',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Helper to get content type from file extension
  MediaType? _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('image', 'jpeg'); // Default to jpeg
    }
  }

  // Get approvers for leave request
  Future<List<Map<String, dynamic>>> getApprovers({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return [];
      }

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/attendance/approvers').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] != null) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
      }

      return [];
    } catch (e) {
      print('Error getting approvers: $e');
      return [];
    }
  }

  // Cancel leave request
  Future<Map<String, dynamic>> cancelLeaveRequest({
    required int id,
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final body = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        body['reason'] = reason;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/attendance/cancel-leave/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to cancel leave request',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Report Attendance: fetch only outlets & divisions for filter dropdowns (no report data).
  Future<Map<String, dynamic>?> getAttendanceReportFilters() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/attendance-report/filters'),
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
      print('Error getAttendanceReportFilters: $e');
      return null;
    }
  }

  /// Report Attendance: fetch report data with filters (outlet_id, division_id, search, bulan, tahun).
  /// Returns { data, outlets, divisions, filter, summary } or null.
  Future<Map<String, dynamic>?> getAttendanceReport({
    String? outletId,
    String? divisionId,
    String? search,
    int? bulan,
    int? tahun,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return null;

      final queryParams = <String, String>{};
      if (outletId != null && outletId.isNotEmpty) queryParams['outlet_id'] = outletId;
      if (divisionId != null && divisionId.isNotEmpty) queryParams['division_id'] = divisionId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (bulan != null) queryParams['bulan'] = bulan.toString();
      if (tahun != null) queryParams['tahun'] = tahun.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/attendance-report').replace(
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
      print('Error getAttendanceReport: $e');
      return null;
    }
  }

  /// Report Attendance: fetch employees list for filter (outlet_id, division_id, search).
  Future<List<Map<String, dynamic>>> getAttendanceReportEmployees({
    String? outletId,
    String? divisionId,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (outletId != null && outletId.isNotEmpty) queryParams['outlet_id'] = outletId;
      if (divisionId != null && divisionId.isNotEmpty) queryParams['division_id'] = divisionId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

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
          return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
      return [];
    } catch (e) {
      print('Error getAttendanceReportEmployees: $e');
      return [];
    }
  }

  /// Report Attendance: detail absensi per user per tanggal (scan per outlet).
  Future<List<Map<String, dynamic>>> getAttendanceReportDetail({
    required int userId,
    required String tanggal,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/attendance-report/detail').replace(
        queryParameters: {'user_id': userId.toString(), 'tanggal': tanggal},
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body);
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getAttendanceReportDetail: $e');
      return [];
    }
  }

  /// Report Attendance: info shift karyawan per tanggal.
  Future<Map<String, dynamic>?> getAttendanceReportShiftInfo({
    required int userId,
    required String tanggal,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/attendance-report/shift-info').replace(
        queryParameters: {'user_id': userId.toString(), 'tanggal': tanggal},
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) return Map<String, dynamic>.from(data);
        if (data is List && (data as List).isEmpty) return null;
      }
      return null;
    } catch (e) {
      print('Error getAttendanceReportShiftInfo: $e');
      return null;
    }
  }

  // Get extra off days from Public Holiday
  Future<List<Map<String, dynamic>>> getMyExtraOffDays() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/holiday-attendance/my-extra-off-days'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error getting extra off days: $e');
      return [];
    }
  }
}

