import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class MKProductionService {
  static const String _base = '${AuthService.baseUrl}/api/approval-app/mk-production';

  Future<String?> _getToken() async {
    final authService = AuthService();
    return authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? itemId,
    String? fromDate,
    String? toDate,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final query = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
      };
      if ((search ?? '').isNotEmpty) query['search'] = search!;
      if ((itemId ?? '').isNotEmpty) query['item_id'] = itemId!;
      if ((fromDate ?? '').isNotEmpty) query['from_date'] = fromDate!;
      if ((toDate ?? '').isNotEmpty) query['to_date'] = toDate!;

      final uri = Uri.parse(_base).replace(queryParameters: query);
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
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/create-data'),
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
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> getBomAndStock({
    required int itemId,
    required double qty,
    required int warehouseId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_base/bom'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'item_id': itemId,
          'qty': qty,
          'warehouse_id': warehouseId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> store({
    required int warehouseId,
    required String productionDate,
    required String batchNumber,
    required int itemId,
    required double qty,
    required double qtyJadi,
    required int unitId,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No auth token'};
      final response = await http.post(
        Uri.parse(_base),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'warehouse_id': warehouseId,
          'production_date': productionDate,
          'batch_number': batchNumber,
          'item_id': itemId,
          'qty': qty,
          'qty_jadi': qtyJadi,
          'unit_jadi': unitId,
          'unit_id': unitId,
          'notes': notes ?? '',
        }),
      );
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/$id'),
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
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> destroy(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No auth token'};
      final response = await http.delete(
        Uri.parse('$_base/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
