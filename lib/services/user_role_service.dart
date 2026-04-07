import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/user_role_models.dart';

class UserRoleService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Get users with roles and filters
  Future<Map<String, dynamic>> getUsers({
    int? outletId,
    int? divisionId,
    int? roleId,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (divisionId != null) queryParams['division_id'] = divisionId.toString();
      if (roleId != null) queryParams['role_id'] = roleId.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/api/approval-app/user-roles')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'data': data,
          };
        } catch (e) {
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
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to fetch users',
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

  // Update user role
  Future<Map<String, dynamic>> updateUserRole(int userId, int roleId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/user-roles/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'role_id': roleId,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Role updated successfully',
            'data': data['data'],
          };
        } catch (e) {
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
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to update role',
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

  // Bulk assign role
  Future<Map<String, dynamic>> bulkAssignRole(List<int> userIds, int roleId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/user-roles/bulk-assign'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_ids': userIds,
          'role_id': roleId,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Roles assigned successfully',
            'data': data['data'],
          };
        } catch (e) {
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
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to assign roles',
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

