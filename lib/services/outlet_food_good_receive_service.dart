import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletFoodGoodReceiveService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getOutletGoodReceives({
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

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-good-receives').replace(
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
      print('Error getting outlet good receives: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOutletGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-good-receives/$id'),
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
      print('Error getting outlet good receive detail: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableDeliveryOrders({String? query}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-food-good-receives/available-dos')
          .replace(queryParameters: query != null && query.isNotEmpty ? {'q': query} : null);

      final response = await http.get(
        uri,
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

  Future<Map<String, dynamic>?> getDeliveryOrderDetail(int doId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-good-receives/do-detail/$doId'),
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

  Future<Map<String, dynamic>> createOutletGoodReceive({
    required int deliveryOrderId,
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
        'delivery_order_id': deliveryOrderId,
        'receive_date': receiveDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-good-receives'),
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
      print('Error creating outlet good receive: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteOutletGoodReceive(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-good-receives/$id'),
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
      print('Error deleting outlet good receive: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>?> getItemDetail(int itemId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/items/$itemId/detail'),
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
      print('Error getting item detail: $e');
      return null;
    }
  }
}
