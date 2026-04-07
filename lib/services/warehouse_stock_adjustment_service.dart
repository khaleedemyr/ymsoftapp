import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseStockAdjustmentService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// GET /api/approval-app/food-inventory-adjustment/warehouses
  Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/food-inventory-adjustment/warehouses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['warehouses'] != null) {
          final list = data['warehouses'] as List;
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      print('WarehouseStockAdjustmentService getWarehouses: $e');
      return [];
    }
  }

  /// Search items - tries approval-app endpoint then fallback to global API
  Future<List<Map<String, dynamic>>> searchItems(String q, {int? warehouseId}) async {
    if (q.trim().isEmpty) return [];
    try {
      final token = await _getToken();
      if (token == null) return [];
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      // 1) Try approval-app endpoint
      var url = '$baseUrl/api/approval-app/food-inventory-adjustment/items/search?q=${Uri.encodeComponent(q.trim())}';
      if (warehouseId != null) url += '&warehouse_id=$warehouseId';
      var response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final list = _parseItemSearchResponse(response.body);
        if (list.isNotEmpty) return list;
      }

      // 2) Fallback: global API (same as web form)
      url = '$baseUrl/api/items/search-for-warehouse-transfer?q=${Uri.encodeComponent(q.trim())}';
      if (warehouseId != null) url += '&warehouse_id=$warehouseId';
      response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return _parseItemSearchResponse(response.body);
      }
      return [];
    } catch (e) {
      print('WarehouseStockAdjustmentService searchItems: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _parseItemSearchResponse(String body) {
    try {
      final data = jsonDecode(body);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map && data['data'] is List) {
        raw = data['data'] as List;
      } else if (data is Map && data['items'] is List) {
        raw = data['items'] as List;
      }
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// GET /api/approval-app/food-inventory-adjustment?page=&search=&from=&to=&warehouse_id=
  Future<Map<String, dynamic>?> getAdjustmentsList({
    int page = 1,
    String? search,
    String? from,
    String? to,
    int? warehouseId,
    int perPage = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (from != null && from.isNotEmpty) query['from'] = from;
      if (to != null && to.isNotEmpty) query['to'] = to;
      if (warehouseId != null) query['warehouse_id'] = warehouseId.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/food-inventory-adjustment').replace(queryParameters: query);
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
      print('WarehouseStockAdjustmentService getAdjustmentsList: $e');
      return null;
    }
  }

  /// POST /api/approval-app/food-inventory-adjustment
  Future<Map<String, dynamic>> store({
    required String date,
    required int warehouseId,
    required String type,
    required String reason,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Sesi habis'};
      final body = jsonEncode({
        'date': date,
        'warehouse_id': warehouseId,
        'type': type,
        'reason': reason,
        'items': items,
      });
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-inventory-adjustment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : {'success': true};
      }
      final err = jsonDecode(response.body);
      return {
        'success': false,
        'message': err['message'] ?? err['error'] ?? 'Gagal menyimpan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
