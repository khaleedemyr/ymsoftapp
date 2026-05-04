import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ContraBonService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // --- Create Form Methods ---

  Future<Map<String, dynamic>?> getPoWithGr({String? search, int page = 1}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{'page': page.toString()};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final uri = Uri.parse('$baseUrl/api/approval-app/contra-bon/form/po-with-gr')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      debugPrint('ContraBonService getPoWithGr: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getRetailFoodSources({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final uri = Uri.parse('$baseUrl/api/approval-app/contra-bon/form/retail-food')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
      return null;
    } catch (e) {
      debugPrint('ContraBonService getRetailFoodSources: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getWarehouseRetailFoodSources({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final uri = Uri.parse('$baseUrl/api/approval-app/contra-bon/form/warehouse-retail-food')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
      return null;
    } catch (e) {
      debugPrint('ContraBonService getWarehouseRetailFoodSources: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRetailNonFoodSources({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final uri = Uri.parse('$baseUrl/api/approval-app/contra-bon/form/retail-non-food')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      debugPrint('ContraBonService getRetailNonFoodSources: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRetailNonFoodItems(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/contra-bon/form/retail-non-food-items/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      debugPrint('ContraBonService getRetailNonFoodItems: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createContraBon(Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/contra-bon'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ContraBonService createContraBon: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/contra-bon').replace(
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
      debugPrint('ContraBonService getList: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/contra-bon/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['contra_bon'] != null) {
          return body['contra_bon'] as Map<String, dynamic>;
        }
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('ContraBonService getDetail: $e');
      return null;
    }
  }
}
