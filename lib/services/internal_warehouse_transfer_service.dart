import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class InternalWarehouseTransferService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getTransfers({
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

      final uri = Uri.parse('$baseUrl/api/approval-app/internal-warehouse-transfers').replace(
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
    } catch (e) {
      print('Error getting internal warehouse transfers: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/internal-warehouse-transfers/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting internal warehouse transfer create data: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/internal-warehouse-transfers/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting internal warehouse transfer detail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchItems(String query, {int? warehouseOutletId}) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$baseUrl/api/items/search-for-internal-warehouse-transfer').replace(
        queryParameters: {
          'q': query,
          if (warehouseOutletId != null) 'warehouse_outlet_id': warehouseOutletId.toString(),
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
      print('Error searching items for internal warehouse transfer: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createTransfer({
    required String transferDate,
    required int outletId,
    required int warehouseOutletFromId,
    required int warehouseOutletToId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/internal-warehouse-transfers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'transfer_date': transferDate,
          'outlet_id': outletId,
          'warehouse_outlet_from_id': warehouseOutletFromId,
          'warehouse_outlet_to_id': warehouseOutletToId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items': items,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': false, 'message': error['message'] ?? 'Gagal menyimpan transfer'};
      } catch (_) {
        return {'success': false, 'message': 'Gagal menyimpan (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
