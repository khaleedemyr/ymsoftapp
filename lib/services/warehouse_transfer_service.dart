import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseTransferService {
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
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting warehouses: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getTransfers({
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
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/warehouse-transfers').replace(
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

      print('Warehouse transfer list error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error getting transfers: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/warehouse-transfers/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      print('Warehouse transfer detail error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error getting transfer detail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchItems(String query, {int? warehouseId}) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$baseUrl/api/items/search-for-warehouse-transfer').replace(
        queryParameters: {
          'q': query,
          if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error searching items: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getStock({required int itemId, required int warehouseId}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/inventory/stock').replace(
        queryParameters: {
          'item_id': itemId.toString(),
          'warehouse_id': warehouseId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('Error getting stock: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> createTransfer({
    required String transferDate,
    required int warehouseFromId,
    required int warehouseToId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-transfers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'transfer_date': transferDate,
          'warehouse_from_id': warehouseFromId,
          'warehouse_to_id': warehouseToId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items': items,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }

      try {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to create transfer'};
      } catch (e) {
        return {'success': false, 'message': 'Failed to create transfer (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
