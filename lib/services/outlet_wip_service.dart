import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletWIPService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _prefix = '$baseUrl/api/approval-app/outlet-wip';

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// GET list with pagination and filters.
  Future<Map<String, dynamic>?> getList({
    String? dateFrom,
    String? dateTo,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse(_prefix).replace(queryParameters: queryParams);
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
      print('Error outlet WIP getList: $e');
      return null;
    }
  }

  /// GET create form data: items, warehouse_outlets, outlets, user_outlet_id.
  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$_prefix/create-data');
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
      print('Error outlet WIP getCreateData: $e');
      return null;
    }
  }

  /// POST getBomAndStock: item_id, qty, outlet_id, warehouse_outlet_id.
  /// Returns List<dynamic> (array of BOM lines) on success.
  Future<dynamic> getBomAndStock({
    required int itemId,
    required double qty,
    required int outletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final payload = {
        'item_id': itemId,
        'qty': qty,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
      };

      final response = await http.post(
        Uri.parse('$_prefix/bom'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded; // API returns array of BOM lines
      }
      return null;
    } catch (e) {
      print('Error outlet WIP getBomAndStock: $e');
      return null;
    }
  }

  /// POST store (save draft).
  Future<Map<String, dynamic>> store({
    required int outletId,
    required int warehouseOutletId,
    required String productionDate,
    String? batchNumber,
    String? notes,
    required List<Map<String, dynamic>> productions,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'production_date': productionDate,
        'batch_number': batchNumber ?? '',
        'notes': notes ?? '',
        'productions': productions,
      };

      final response = await http.post(
        Uri.parse(_prefix),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final decoded = response.statusCode == 200 || response.statusCode == 201
          ? jsonDecode(response.body)
          : <String, dynamic>{'success': false, 'message': response.body};
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// POST store-and-submit (simpan dan proses stok langsung).
  Future<Map<String, dynamic>> storeAndSubmit({
    required int outletId,
    required int warehouseOutletId,
    required String productionDate,
    String? batchNumber,
    String? notes,
    required List<Map<String, dynamic>> productions,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'production_date': productionDate,
        'batch_number': batchNumber ?? '',
        'notes': notes ?? '',
        'productions': productions,
      };

      final response = await http.post(
        Uri.parse('$_prefix/store-and-submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final decoded = response.statusCode == 200 || response.statusCode == 201
          ? jsonDecode(response.body)
          : <String, dynamic>{'success': false, 'message': response.body};
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// POST submit (draft -> processed).
  Future<Map<String, dynamic>> submit(int headerId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$_prefix/$headerId/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      );

      final decoded = response.statusCode == 200
          ? jsonDecode(response.body)
          : <String, dynamic>{'success': false, 'message': response.body};
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// GET detail (header + productions + outlet + warehouse + stock_cards + bom_data).
  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_prefix/$id'),
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
      print('Error outlet WIP getDetail: $e');
      return null;
    }
  }

  /// DELETE header (only allowed for certain roles).
  Future<Map<String, dynamic>> destroy(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$_prefix/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return {'success': false, 'message': response.body};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// GET report: productions with optional start_date, end_date.
  Future<Map<String, dynamic>?> getReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-wip-report').replace(
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
      print('Error outlet WIP getReport: $e');
      return null;
    }
  }
}
