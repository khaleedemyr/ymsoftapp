import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletTransferService {
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

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-transfers').replace(
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
      print('Outlet transfer list error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error getting outlet transfers: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-transfers/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting outlet transfer create data: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTransfer(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-transfers/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting outlet transfer detail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchItems(String query, {int? warehouseOutletId}) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$baseUrl/api/items/search-for-outlet-transfer').replace(
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
      print('Error searching items for outlet transfer: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getStock({
    required int itemId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/stock').replace(
        queryParameters: {
          'item_id': itemId.toString(),
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
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('Error getting outlet stock: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> createTransfer({
    required String transferDate,
    required int outletFromId,
    required int warehouseOutletFromId,
    required int outletToId,
    required int warehouseOutletToId,
    String? notes,
    required List<Map<String, dynamic>> items,
    required List<int> approvers,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-transfers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'transfer_date': transferDate,
          'outlet_from_id': outletFromId,
          'warehouse_outlet_from_id': warehouseOutletFromId,
          'outlet_to_id': outletToId,
          'warehouse_outlet_to_id': warehouseOutletToId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items': items,
          'approvers': approvers,
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

  Future<Map<String, dynamic>> submit(int id, List<int> approvers) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-transfers/$id/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'approvers': approvers}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Gagal submit'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> approve(int id, {required String action, String? comments}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-transfers/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': action,
          if (comments != null && comments.isNotEmpty) 'comments': comments,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Gagal approve/reject'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getApprovers({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-transfer/approvers').replace(
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
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
        if (data is Map && data['users'] is List) {
          return (data['users'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting approvers: $e');
    }
    return [];
  }
}
