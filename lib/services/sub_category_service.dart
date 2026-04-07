import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SubCategoryService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    int? categoryId,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/sub-categories').replace(
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
      print('SubCategoryService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/sub-categories/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SubCategoryService.getCreateData error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/sub-categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SubCategoryService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> create({
    required String name,
    String? description,
    required int categoryId,
    String status = 'active',
    int showPos = 1,
    String? availabilityType,
    List<int>? regionIds,
    List<int>? outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = {
        'name': name,
        'description': description ?? '',
        'category_id': categoryId,
        'status': status,
        'show_pos': showPos.toString(),
        'availability_type': availabilityType,
        'region_ids': regionIds ?? [],
        'outlet_ids': outletIds ?? [],
      };

      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/sub-categories'),
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
      print('SubCategoryService.create error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> update(
    int id, {
    required String name,
    String? description,
    required int categoryId,
    String status = 'active',
    int showPos = 1,
    String? availabilityType,
    List<int>? regionIds,
    List<int>? outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = {
        'name': name,
        'description': description ?? '',
        'category_id': categoryId,
        'status': status,
        'show_pos': showPos.toString(),
        'availability_type': availabilityType,
        'region_ids': regionIds ?? [],
        'outlet_ids': outletIds ?? [],
      };

      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/sub-categories/$id'),
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
      print('SubCategoryService.update error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleStatus(int id, {String? status}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final body = status != null ? {'status': status} : {};
      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/sub-categories/$id/toggle-status'),
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
      print('SubCategoryService.toggleStatus error: $e');
    }
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/sub-categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return resp.statusCode == 200;
    } catch (e) {
      print('SubCategoryService.delete error: $e');
    }
    return false;
  }
}
