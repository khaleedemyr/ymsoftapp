import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetOwnerTransferService {
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
    String? status,
    int? ownerOutletId,
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
      if (ownerOutletId != null) qp['owner_outlet_id'] = ownerOutletId.toString();
      if (page != null) qp['page'] = page.toString();
      if (perPage != null) qp['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getOwnerTransfers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers/create-data'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error getCreateData owner transfer: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getWarehousesByOutlet(int outletId) async {
    try {
      final token = await _getToken();

      Future<List<Map<String, dynamic>>> parseResponse(http.Response res) async {
        if (res.statusCode != 200) return [];
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (decoded is Map && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return [];
      }

      if (token != null) {
        final approvalUri = Uri.parse(
          '$baseUrl/api/approval-app/outlet-inventory/warehouse-outlets',
        ).replace(queryParameters: {'outlet_id': outletId.toString()});
        final approvalRes = await http.get(approvalUri, headers: _headers(token));
        final fromApproval = await parseResponse(approvalRes);
        if (fromApproval.isNotEmpty) return fromApproval;
      }

      final publicUri = Uri.parse('$baseUrl/api/warehouse-outlets/by-outlet')
          .replace(queryParameters: {'outlet_id': outletId.toString()});
      final headers = token != null
          ? _headers(token)
          : {'Accept': 'application/json'};
      final publicRes = await http.get(publicUri, headers: headers);
      return await parseResponse(publicRes);
    } catch (e) {
      print('Error getWarehousesByOutlet: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllWarehouses() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/lost-breakage/form-meta'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['warehouse_outlets'] is List) {
          return (decoded['warehouse_outlets'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getAllWarehouses: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlets'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (decoded is Map && decoded['outlets'] is List) {
          return (decoded['outlets'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getOutlets owner transfer: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers/$id'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('Error getOwnerTransfer: $e');
      return null;
    }
  }

  Future<List<dynamic>> searchItems(
    String query, {
    required int ownerOutletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/items/search-for-asset-transfer').replace(
        queryParameters: {
          'q': query,
          'owner_outlet_id': ownerOutletId.toString(),
          'warehouse_outlet_id': warehouseOutletId.toString(),
        },
      );

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (e) {
      print('Error searchItems owner transfer: $e');
      return [];
    }
  }

  Future<List<dynamic>> searchApprovers(String query) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-owner-transfer/approvers')
          .replace(queryParameters: {'search': query});

      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['users'] as List<dynamic>? ?? [];
      }
      return [];
    } catch (e) {
      print('Error searchApprovers owner transfer: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createTransfer({
    required String transferDate,
    required int ownerOutletFromId,
    required int ownerOutletToId,
    required int outletId,
    required int warehouseOutletId,
    String? notes,
    required List<Map<String, dynamic>> items,
    List<int>? approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final body = {
        'transfer_date': transferDate,
        'owner_outlet_from_id': ownerOutletFromId,
        'owner_outlet_to_id': ownerOutletToId,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
        if (approvers != null && approvers.isNotEmpty) 'approvers': approvers,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers'),
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

  Future<Map<String, dynamic>> submit(int id, {List<int>? approvers}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final body = <String, dynamic>{};
      if (approvers != null && approvers.isNotEmpty) {
        body['approvers'] = approvers;
      }

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers/$id/submit'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> approve(int id, String action, {String? comments}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({
          'action': action,
          if (comments != null) 'comments': comments,
        }),
      );
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-owner-transfers/$id'),
        headers: _headers(token),
      );
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
