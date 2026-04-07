import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseStockOpnameService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    int? warehouseId,
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
      if (status != null && status.isNotEmpty && status != 'all') queryParams['status'] = status;
      if (warehouseId != null) queryParams['warehouse_id'] = warehouseId.toString();
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('Error getList warehouse stock opname: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/create-data'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
      }
      return null;
    } catch (e) {
      print('Error getCreateData warehouse stock opname: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkDivisions(int warehouseId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/check-divisions')
          .replace(queryParameters: {'warehouse_id': warehouseId.toString()});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
      }
      return null;
    } catch (e) {
      print('Error checkDivisions: $e');
      return null;
    }
  }

  Future<List<dynamic>> getItems({required int warehouseId, int? warehouseDivisionId}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final queryParams = <String, String>{'warehouse_id': warehouseId.toString()};
      if (warehouseDivisionId != null) queryParams['warehouse_division_id'] = warehouseDivisionId.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/get-items').replace(
        queryParameters: queryParams,
      );
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is List) return d;
      }
      return [];
    } catch (e) {
      print('Error getItems warehouse stock opname: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getApprovers(String search) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/approvers')
          .replace(queryParameters: {'search': search});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['users'] is List) {
          return (decoded['users'] as List)
              .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
              .toList();
        }
      }
    } catch (e) {
      print('Error getApprovers warehouse stock opname: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
      }
      return null;
    } catch (e) {
      print('Error getDetail warehouse stock opname: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> store({
    required int warehouseId,
    required int? warehouseDivisionId,
    required String opnameDate,
    required List<Map<String, dynamic>> items,
    String? notes,
    List<int>? approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final payload = {
        'warehouse_id': warehouseId,
        'warehouse_division_id': warehouseDivisionId,
        'opname_date': opnameDate,
        'items': items,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (approvers != null && approvers.isNotEmpty) 'approvers': approvers,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
        return {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['message']?.toString() ?? 'Gagal menyimpan'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required int warehouseId,
    required int? warehouseDivisionId,
    required String opnameDate,
    required List<Map<String, dynamic>> items,
    String? notes,
    List<int>? approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final payload = {
        'warehouse_id': warehouseId,
        'warehouse_division_id': warehouseDivisionId,
        'opname_date': opnameDate,
        'items': items,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (approvers != null && approvers.isNotEmpty) 'approvers': approvers,
      };
      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/$id'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
        return {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['message']?.toString() ?? 'Gagal update'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {'success': true};
        }
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['message']?.toString() ?? 'Gagal hapus'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitForApproval({required int id, required List<int> approvers}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/$id/submit-approval'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'approvers': approvers}),
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
        return {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['message']?.toString() ?? 'Gagal submit'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> approve({required int id, required String action, String? comments}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/$id/approve'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'action': action, if (comments != null) 'comments': comments}),
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
        return {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['message']?.toString() ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> process(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-stock-opnames/$id/process'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
        return {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['message']?.toString() ?? 'Gagal process'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
