import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletStockPositionService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
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

  Future<List<Map<String, dynamic>>> getWarehouseOutlets({int? outletId}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/warehouse-outlets').replace(
        queryParameters: outletId != null ? {'outlet_id': outletId.toString()} : null,
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
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting warehouse outlets: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getStockPosition({
    required int? outletId,
    required int? warehouseOutletId,
    String? search,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (warehouseOutletId != null) queryParams['warehouse_outlet_id'] = warehouseOutletId.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/stock-position').replace(
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
      print('Error getting stock position: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStockCardDetail({
    required int itemId,
    required int outletId,
    int? warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'item_id': itemId.toString(),
        'outlet_id': outletId.toString(),
      };
      if (warehouseOutletId != null) {
        queryParams['warehouse_outlet_id'] = warehouseOutletId.toString();
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/stock-card/detail').replace(
        queryParameters: queryParams,
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
    } catch (e) {
      print('Error getting stock card detail: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getStockCard({
    required int itemId,
    int? outletId,
    int? warehouseOutletId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'item_id': itemId.toString(),
      };
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (warehouseOutletId != null) {
        queryParams['warehouse_outlet_id'] = warehouseOutletId.toString();
      }
      if (fromDate != null && fromDate.isNotEmpty) queryParams['from'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) queryParams['to'] = toDate;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/stock-card').replace(
        queryParameters: queryParams,
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
    } catch (e) {
      print('Error getting stock card: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getStockCardItems({String? search, int? limit}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/stock-card/items').replace(
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
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting stock card items: $e');
    }
    return [];
  }
}
