import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletStockAdjustmentService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getAdjustments({
    String? search,
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
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustments').replace(
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
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }

      return null;
    } catch (e) {
      print('Error getting outlet stock adjustments: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAdjustment(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustments/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }

      return null;
    } catch (e) {
      print('Error getting outlet stock adjustment detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createAdjustment({
    required String date,
    required int outletId,
    required int warehouseOutletId,
    required String type,
    required String reason,
    required List<Map<String, dynamic>> items,
    required List<int> approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'date': date,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'type': type,
        'reason': reason,
        'items': items,
        'approvers': approvers,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'success': true};
      }

      final error = jsonDecode(response.body);
      return {
        'success': false,
        'message': error['message'] ?? 'Failed to create outlet stock adjustment',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting outlets: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getOutletDetail(int outletId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/outlet/$outletId'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('Error getting outlet detail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getWarehouseOutlets(int outletId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustment/warehouse-outlets')
          .replace(queryParameters: {'outlet_id': outletId.toString()});

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting warehouse outlets: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchItems({
    required String query,
    required int outletId,
    required int regionId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/items/search-for-outlet-stock-adjustment').replace(
        queryParameters: {
          'q': query,
          'outlet_id': outletId.toString(),
          'region_id': regionId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error searching items: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getApprovers(String search) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustment/approvers')
          .replace(queryParameters: {'search': search});

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['users'] is List) {
          return (decoded['users'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      print('Error getting approvers: $e');
    }
    return [];
  }
}
