import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ItemService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    int? categoryId,
    String? status,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/items').replace(
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
      print('ItemService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/items/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('ItemService.getCreateData error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true && data['item'] != null) {
          return data;
        }
        return data;
      }
    } catch (e) {
      print('ItemService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> create(Map<String, dynamic> body) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return decoded;
      }
      return decoded;
    } catch (e) {
      print('ItemService.create error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> update(int id, Map<String, dynamic> body) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (resp.statusCode == 200) {
        return decoded;
      }
      return decoded;
    } catch (e) {
      print('ItemService.update error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> toggleStatus(int id, {required String status}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/items/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>?;
    } catch (e) {
      print('ItemService.toggleStatus error: $e');
    }
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        return data?['success'] == true;
      }
    } catch (e) {
      print('ItemService.delete error: $e');
    }
    return false;
  }
}
