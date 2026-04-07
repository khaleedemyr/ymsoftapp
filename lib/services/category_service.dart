import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CategoryService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  /// GET /api/approval-app/categories
  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/categories').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('CategoryService.getList error: $e');
    }
    return null;
  }

  /// GET /api/approval-app/categories/create-data
  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/categories/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('CategoryService.getCreateData error: $e');
    }
    return null;
  }

  /// GET /api/approval-app/categories/{id}
  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('CategoryService.getDetail error: $e');
    }
    return null;
  }

  /// POST /api/approval-app/categories
  Future<Map<String, dynamic>?> create({
    required String code,
    required String name,
    String? description,
    String status = 'active',
    int showPos = 1,
    List<int>? outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = {
        'code': code,
        'name': name,
        'description': description ?? '',
        'status': status,
        'show_pos': showPos.toString(),
        'outlet_ids': outletIds ?? [],
      };

      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(resp.body);
      return {'success': false, 'errors': err};
    } catch (e) {
      print('CategoryService.create error: $e');
    }
    return null;
  }

  /// PUT /api/approval-app/categories/{id}
  Future<Map<String, dynamic>?> update(
    int id, {
    required String code,
    required String name,
    String? description,
    String status = 'active',
    int showPos = 1,
    List<int>? outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = {
        'code': code,
        'name': name,
        'description': description ?? '',
        'status': status,
        'show_pos': showPos.toString(),
        'outlet_ids': outletIds ?? [],
      };

      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(resp.body);
      return {'success': false, 'errors': err};
    } catch (e) {
      print('CategoryService.update error: $e');
    }
    return null;
  }

  /// PATCH /api/approval-app/categories/{id}/toggle-status
  Future<Map<String, dynamic>?> toggleStatus(int id, {String? status}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = status != null ? {'status': status} : {};
      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/categories/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('CategoryService.toggleStatus error: $e');
    }
    return null;
  }

  /// DELETE /api/approval-app/categories/{id} (soft: set status inactive)
  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return resp.statusCode == 200;
    } catch (e) {
      print('CategoryService.delete error: $e');
    }
    return false;
  }
}
