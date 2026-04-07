import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletSupplierGoodReceiveService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getOutletSupplierGoodReceives({
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

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives').replace(
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
      print('Error getting outlet supplier good receives: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOutletSupplierGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives/$id'),
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
      print('Error getting outlet supplier good receive detail: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableROs() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives/available-ros'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }

      return [];
    } catch (e) {
      print('Error getting available RO suppliers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableDOs() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives/available-dos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }

      return [];
    } catch (e) {
      print('Error getting available DOs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRoDetail(int roSupplierId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives/ro-detail/$roSupplierId'),
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
      print('Error getting RO detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDoDetail(int deliveryOrderId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives/do-detail/$deliveryOrderId'),
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
      print('Error getting DO detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createFromRO({
    required int roSupplierId,
    required String receiveDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'ro_supplier_id': roSupplierId,
        'receive_date': receiveDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives'),
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

      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['message'] ?? 'Failed to create good receive'};
    } catch (e) {
      print('Error creating good receive from RO: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createFromDO({
    required int deliveryOrderId,
    required String receiveDate,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'delivery_order_id': deliveryOrderId,
        'receive_date': receiveDate,
        'items': items,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives'),
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

      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['message'] ?? 'Failed to create good receive'};
    } catch (e) {
      print('Error creating good receive from DO: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteOutletSupplierGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/outlet-supplier-good-receives/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          return {'success': true, 'message': 'Good receive deleted'};
        }
      }

      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['message'] ?? 'Failed to delete'};
    } catch (e) {
      print('Error deleting outlet supplier good receive: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
