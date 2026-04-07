import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ActivityLogService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>> getActivityLogs({
    String? search,
    int? userId,
    String? activityType,
    String? module,
    String? dateFrom,
    String? dateTo,
    int perPage = 25,
    int page = 1,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final queryParams = <String, String>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (userId != null) queryParams['user_id'] = userId.toString();
      if (activityType != null && activityType.isNotEmpty) queryParams['activity_type'] = activityType;
      if (module != null && module.isNotEmpty) queryParams['module'] = module;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/approval-app/report/activity-log')
          .replace(queryParameters: queryParams);

      print('Activity Log - Request URL: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Activity Log - Response Status: ${response.statusCode}');
      print('Activity Log - Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Activity Log API Response Status: ${response.statusCode}');
          print('Activity Log API Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
          print('Activity Log Parsed Data Keys: ${data is Map ? (data as Map).keys.toList() : 'Not a Map'}');
          
          // Check if response has 'success' field
          if (data is Map && data.containsKey('success')) {
            return {
              'success': data['success'] == true,
              'data': data,
            };
          }
          
          return {
            'success': true,
            'data': data,
          };
        } catch (e) {
          print('Error parsing activity log response: $e');
          return {
            'success': false,
            'message': 'Failed to parse response: ${e.toString()}',
          };
        }
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to fetch activity logs',
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}

