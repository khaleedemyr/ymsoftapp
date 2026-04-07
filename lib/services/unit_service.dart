import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class UnitService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

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

      final uri = Uri.parse('$baseUrl/api/approval-app/units').replace(
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
      print('UnitService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/units/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('UnitService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> create({
    required String code,
    required String name,
    String status = 'active',
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = {'code': code, 'name': name, 'status': status};

      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/units'),
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
      print('UnitService.create error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> update(
    int id, {
    required String code,
    required String name,
    String status = 'active',
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = {'code': code, 'name': name, 'status': status};

      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/units/$id'),
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
      print('UnitService.update error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleStatus(int id, {String? status}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = status != null ? {'status': status} : {};
      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/units/$id/toggle-status'),
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
      print('UnitService.toggleStatus error: $e');
    }
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/units/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return resp.statusCode == 200;
    } catch (e) {
      print('UnitService.delete error: $e');
    }
    return false;
  }
}
