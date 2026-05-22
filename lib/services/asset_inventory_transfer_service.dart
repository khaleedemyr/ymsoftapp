import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetInventoryTransferService {
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

      final qp = <String, String>{};
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
      if (page != null) qp['page'] = page.toString();
      if (perPage != null) qp['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getTransfers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers/create-data'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getCreateData: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers/$id'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getTransfer: $e');
      return null;
    }
  }

  Future<List<dynamic>> searchItems(
    String query, {
    int? ownerOutletId,
    int? warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final qp = <String, String>{'q': query};
      if (ownerOutletId != null) {
        qp['owner_outlet_id'] = ownerOutletId.toString();
      }
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

  Future<Map<String, dynamic>> createTransfer({
    required int ownerOutletId,
    required String transferDate,
    required int warehouseOutletFromId,
    required int warehouseOutletToId,
    String? notes,
    required List<Map<String, dynamic>> items,
    List<int>? approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final body = {
        'owner_outlet_id': ownerOutletId,
        'transfer_date': transferDate,
        'warehouse_outlet_from_id': warehouseOutletFromId,
        'warehouse_outlet_to_id': warehouseOutletToId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
        if (approvers != null && approvers.isNotEmpty) 'approvers': approvers,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers'),
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

  Future<Map<String, dynamic>> submit(int id, List<int> approvers) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers/$id/submit'),
        headers: _headers(token),
        body: jsonEncode({'approvers': approvers}),
      );

      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> approve(int id, {required String action, String? comments}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({
          'action': action,
          if (comments != null && comments.isNotEmpty) 'comments': comments,
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

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfer/approvers')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getApprovers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> deleteTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-inventory-transfers/$id'),
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
