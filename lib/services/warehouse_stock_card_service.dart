import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseStockCardService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/warehouses'),
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
      print('WarehouseStockCardService getWarehouses: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getStockCardItems({String? search, int? limit}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/inventory/stock-card/items')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

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
      print('WarehouseStockCardService getStockCardItems: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getStockCard({
    required int itemId,
    int? warehouseId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'item_id': itemId.toString(),
      };
      if (warehouseId != null) queryParams['warehouse_id'] = warehouseId.toString();
      if (fromDate != null && fromDate.isNotEmpty) queryParams['from'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) queryParams['to'] = toDate;

      final uri = Uri.parse('$baseUrl/api/approval-app/inventory/stock-card')
          .replace(queryParameters: queryParams);

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
      print('WarehouseStockCardService getStockCard: $e');
    }
    return null;
  }
}
