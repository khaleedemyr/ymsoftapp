import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetInventoryAdjustmentService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> getAdjustments({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? type,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final qp = <String, String>{};
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
      if (type != null && type.isNotEmpty) qp['type'] = type;
      if (page != null) qp['page'] = page.toString();
      if (perPage != null) qp['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getAdjustments: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments/create-data'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getCreateData: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAdjustment(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments/$id'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getAdjustment: $e');
      return null;
    }
  }

  Future<List<dynamic>> searchItems(String query, {int? warehouseOutletId}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final qp = <String, String>{'q': query};
      if (warehouseOutletId != null) {
        qp['warehouse_outlet_id'] = warehouseOutletId.toString();
      }

      final uri = Uri.parse('$baseUrl/api/items/search-for-asset-transfer')
          .replace(queryParameters: qp);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (e) {
      print('Error searchItems: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createAdjustment({
    required String date,
    required int outletId,
    required int warehouseOutletId,
    required String type,
    String? reason,
    required List<Map<String, dynamic>> items,
    List<int>? approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final body = {
        'date': date,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'type': type,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'items': items,
        if (approvers != null && approvers.isNotEmpty) 'approvers': approvers,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments'),
        headers: _headers(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(res.body)};
      }
      try {
        final err = jsonDecode(res.body);
        return {'success': false, 'message': err['message'] ?? 'Failed'};
      } catch (_) {
        return {'success': false, 'message': 'Failed (${res.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> approve(int id, {String? comments}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({
          'action': 'approve',
          if (comments != null && comments.isNotEmpty) 'comments': comments,
        }),
      );

      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> reject(int id, {required String comments}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({
          'action': 'reject',
          'comments': comments,
        }),
      );

      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>?> getApprovers({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final qp = <String, String>{};
      if (search != null && search.isNotEmpty) qp['search'] = search;

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustment/approvers')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getApprovers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> deleteAdjustment(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-adjustments/$id'),
        headers: _headers(token),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        try {
          final data = jsonDecode(res.body);
          return {'success': true, 'message': data['message'] ?? 'Deleted'};
        } catch (_) {
          return {'success': true, 'message': 'Deleted'};
        }
      }
      try {
        final err = jsonDecode(res.body);
        return {'success': false, 'message': err['message'] ?? 'Failed'};
      } catch (_) {
        return {'success': false, 'message': 'Failed (${res.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
