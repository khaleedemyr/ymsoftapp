import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletFoodReturnService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// List returns with filters and pagination
  Future<Map<String, dynamic>?> getList({
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
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-return').replace(
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
      print('Error getting outlet food return list: $e');
      return null;
    }
  }

  /// Create form data: outlets, user_outlet_id
  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-return/create-data'),
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
      print('Error getting outlet food return create data: $e');
      return null;
    }
  }

  /// Warehouse outlets by outlet_id
  Future<List<dynamic>> getWarehouseOutlets(int outletId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-return/get-warehouse-outlets')
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
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['error'] != null) return [];
      }
      return [];
    } catch (e) {
      print('Error getting warehouse outlets: $e');
      return [];
    }
  }

  /// Good receives by outlet + warehouse (completed, last 24h)
  Future<List<dynamic>> getGoodReceives({
    required int outletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-return/get-good-receives').replace(
        queryParameters: {
          'outlet_id': outletId.toString(),
          'warehouse_outlet_id': warehouseOutletId.toString(),
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
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
      }
      return [];
    } catch (e) {
      print('Error getting good receives: $e');
      return [];
    }
  }

  /// GR items for selected good receive (outlet + warehouse required for stock join)
  Future<List<dynamic>> getGoodReceiveItems({
    required int goodReceiveId,
    required int outletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-return/get-good-receive-items').replace(
        queryParameters: {
          'good_receive_id': goodReceiveId.toString(),
          'outlet_id': outletId.toString(),
          'warehouse_outlet_id': warehouseOutletId.toString(),
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
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
      }
      return [];
    } catch (e) {
      print('Error getting good receive items: $e');
      return [];
    }
  }

  /// Detail satu return
  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-return/$id'),
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
      print('Error getting outlet food return detail: $e');
      return null;
    }
  }

  /// Submit return
  Future<Map<String, dynamic>> store({
    required int outletFoodGoodReceiveId,
    required int outletId,
    required int warehouseOutletId,
    required String returnDate,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'outlet_food_good_receive_id': outletFoodGoodReceiveId,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'return_date': returnDate,
        'items': items,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-return'),
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

      final body = response.body;
      try {
        final err = jsonDecode(body);
        return {'success': false, 'message': err['message'] ?? 'Gagal menyimpan return'};
      } catch (_) {
        return {'success': false, 'message': body.isNotEmpty ? body : 'Gagal menyimpan return'};
      }
    } catch (e) {
      print('Error storing outlet food return: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Approve return (gudang) – hanya status pending
  Future<Map<String, dynamic>> approve(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-return/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      final data = response.statusCode == 200 ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      if (response.statusCode == 200 && data != null) {
        return data;
      }
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      final err = decoded?['message'];
      return {'success': false, 'message': err ?? 'Gagal approve return'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Hapus return (hanya superadmin / divisi gudang)
  Future<Map<String, dynamic>> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-return/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final data = response.statusCode == 200 ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      if (response.statusCode == 200 && data != null) {
        return data;
      }
      final fallbackDecoded = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      final err = data?['message'] ?? fallbackDecoded?['message'];
      return {'success': false, 'message': err ?? 'Gagal menghapus return'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
