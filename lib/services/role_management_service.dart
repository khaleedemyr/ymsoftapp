import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class RoleManagementService {
  static final RoleManagementService _instance = RoleManagementService._internal();
  factory RoleManagementService() => _instance;
  RoleManagementService._internal();

  static const String baseUrl = AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getRolesAndMenus() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/roles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'roles': data['roles'] ?? [],
          'menus': data['menus'] ?? [],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to load roles',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> createRole({
    required String name,
    String? description,
    required List<String> permissions,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/roles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'description': description,
          'permissions': permissions,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Role berhasil dibuat',
          'role': data['role'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create role',
          'errors': errorData['errors'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> updateRole({
    required int roleId,
    required String name,
    String? description,
    required List<String> permissions,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/roles/$roleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'description': description,
          'permissions': permissions,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Role berhasil diupdate',
          'role': data['role'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to update role',
          'errors': errorData['errors'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> deleteRole(int roleId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/roles/$roleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Role berhasil dihapus',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to delete role',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}

