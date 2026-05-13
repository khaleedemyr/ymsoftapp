import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetGoodReceiveService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getGoodReceives({
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
      if (dateFrom != null && dateFrom.isNotEmpty) {
        queryParams['from'] = dateFrom;
      }
      if (dateTo != null && dateTo.isNotEmpty) queryParams['to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri =
          Uri.parse('$baseUrl/api/approval-app/asset-good-receives').replace(
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
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('Error getting Asset Good Receives: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-good-receives/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true && decoded['good_receive'] != null) {
            return decoded['good_receive'] as Map<String, dynamic>;
          }
          return decoded;
        }
        return null;
      }

      return null;
    } catch (e) {
      print('Error getting Asset Good Receive detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPO(String poNumber) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/asset-good-receives/fetch-po'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'po_number': poNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to fetch PO'
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to fetch PO (Status: ${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Error fetching PO: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createGoodReceive({
    required String receiveDate,
    required int poId,
    required int outletId,
    int? warehouseOutletId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-good-receives'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'receive_date': receiveDate,
          'po_id': poId,
          'outlet_id': outletId,
          if (warehouseOutletId != null)
            'warehouse_outlet_id': warehouseOutletId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items': items,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message':
                error['message'] ?? 'Failed to create Asset Good Receive'
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Failed to create Asset Good Receive (Status: ${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Error creating Asset Good Receive: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-good-receives/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'message':
                data['message'] ?? 'Asset Good Receive deleted successfully'
          };
        } catch (e) {
          return {
            'success': true,
            'message': 'Asset Good Receive deleted successfully'
          };
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message':
                error['message'] ?? 'Failed to delete Asset Good Receive'
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Failed to delete Asset Good Receive (Status: ${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Error deleting Asset Good Receive: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
