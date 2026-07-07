import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetServiceOrderService {
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

  Future<Map<String, dynamic>?> getOrders({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? status,
    String? serviceType,
    int? outletId,
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
      if (status != null && status.isNotEmpty) qp['status'] = status;
      if (serviceType != null && serviceType.isNotEmpty) {
        qp['service_type'] = serviceType;
      }
      if (outletId != null) qp['outlet_id'] = outletId.toString();
      if (page != null) qp['page'] = page.toString();
      if (perPage != null) qp['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-service-orders')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getOrders: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/create-data'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getCreateData: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOrder(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/$id'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getOrder: $e');
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

  Future<List<dynamic>> searchSuppliers(String query) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/suppliers')
          .replace(queryParameters: {'q': query});

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
        return [];
      }
      return [];
    } catch (e) {
      print('Error searchSuppliers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required int ownerOutletId,
    required String date,
    required int outletId,
    required int warehouseOutletId,
    required String serviceType,
    int? supplierId,
    required String description,
    double? estimatedCost,
    required List<Map<String, dynamic>> items,
    required List<int> approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final body = <String, dynamic>{
        'owner_outlet_id': ownerOutletId,
        'date': date,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'service_type': serviceType,
        'description': description,
        'estimated_cost': estimatedCost ?? 0,
        'items': items,
        'approvers': approvers,
      };
      body['supplier_id'] = supplierId;

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders'),
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
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/$id/approve'),
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
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/$id/approve'),
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

  Future<Map<String, dynamic>> receiveReturn(int id, {
    required List<Map<String, dynamic>> items,
    double? actualCost,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final body = <String, dynamic>{
        'items': items,
      };
      if (actualCost != null) body['actual_cost'] = actualCost;

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/$id/receive-return'),
        headers: _headers(token),
        body: jsonEncode(body),
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

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-service-order/approvers')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getApprovers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> deleteOrder(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/$id'),
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

  Future<Map<String, dynamic>> uploadVendorInvoice(int id, File file) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/asset-service-orders/$id/vendor-invoice'),
      );
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';
      req.files.add(await http.MultipartFile.fromPath('invoice', file.path));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': streamed.statusCode >= 200 && streamed.statusCode < 300};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
