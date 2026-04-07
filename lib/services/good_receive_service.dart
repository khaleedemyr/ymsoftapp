import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class GoodReceiveService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Get list of Good Receives
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
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      // Use approval-app API endpoint
      final uri = Uri.parse('$baseUrl/api/approval-app/food-good-receives').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      print('getGoodReceives: Fetching from $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('getGoodReceives: Response status: ${response.statusCode}');
      print('getGoodReceives: Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      print('Good Receives List Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting Good Receives: $e');
      return null;
    }
  }

  // Get Good Receive detail
  Future<Map<String, dynamic>?> getGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      print('getGoodReceive: Fetching ID $id');

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/food-good-receives/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('getGoodReceive: Response status: ${response.statusCode}');
      print('getGoodReceive: Response body: ${response.body}');

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

      print('Good Receive Detail Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting Good Receive detail: $e');
      return null;
    }
  }

  // Fetch PO by number (for scanning)
  Future<Map<String, dynamic>?> fetchPO(String poNumber) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      print('fetchPO: Fetching PO $poNumber');

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-good-receives/fetch-po'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'po_number': poNumber}),
      );

      print('fetchPO: Response status: ${response.statusCode}');
      print('fetchPO: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'PO tidak ditemukan'};
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'PO sudah pernah diterima'};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'message': error['message'] ?? 'Failed to fetch PO'};
        } catch (e) {
          return {'success': false, 'message': 'Failed to fetch PO (Status: ${response.statusCode})'};
        }
      }
    } catch (e) {
      print('Error fetching PO: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Create Good Receive
  Future<Map<String, dynamic>> createGoodReceive({
    required String receiveDate,
    required int poId,
    required int supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      print('createGoodReceive: Sending data');
      print('createGoodReceive: Items: $items');

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-good-receives'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'receive_date': receiveDate,
          'po_id': poId,
          'supplier_id': supplierId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items': items,
        }),
      );

      print('createGoodReceive: Response status: ${response.statusCode}');
      print('createGoodReceive: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'message': error['message'] ?? 'Failed to create Good Receive'};
        } catch (e) {
          return {'success': false, 'message': 'Failed to create Good Receive (Status: ${response.statusCode})'};
        }
      }
    } catch (e) {
      print('Error creating Good Receive: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Update Good Receive
  Future<Map<String, dynamic>> updateGoodReceive({
    required int id,
    required String receiveDate,
    required int poId,
    required int supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/food-good-receives/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'receive_date': receiveDate,
          'po_id': poId,
          'supplier_id': supplierId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items': items,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to update Good Receive'};
      }
    } catch (e) {
      print('Error updating Good Receive: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Delete Good Receive
  Future<Map<String, dynamic>> deleteGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      print('deleteGoodReceive: Deleting ID $id');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/food-good-receives/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('deleteGoodReceive: Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          final data = jsonDecode(response.body);
          return {'success': true, 'message': data['message'] ?? 'Good Receive deleted successfully'};
        } catch (e) {
          return {'success': true, 'message': 'Good Receive deleted successfully'};
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'message': error['message'] ?? 'Failed to delete Good Receive'};
        } catch (e) {
          return {'success': false, 'message': 'Failed to delete Good Receive (Status: ${response.statusCode})'};
        }
      }
    } catch (e) {
      print('Error deleting Good Receive: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
