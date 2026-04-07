import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PrFoodService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Get list of PR Foods
  Future<Map<String, dynamic>?> getPrFoods({
    String? search,
    String? status,
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
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/pr-foods').replace(
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

      print('PR Foods List Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting PR Foods: $e');
      return null;
    }
  }

  // Get PR Food detail
  Future<Map<String, dynamic>?> getPrFood(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/pr-foods/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // Handle both formats: direct object or wrapped in success/pr_food
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true && decoded['pr_food'] != null) {
            return decoded['pr_food'] as Map<String, dynamic>;
          }
          // Direct object format
          return decoded;
        }
        return null;
      }

      print('PR Food Detail Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting PR Food detail: $e');
      return null;
    }
  }

  // Create PR Food
  Future<Map<String, dynamic>> createPrFood({
    required String tanggal,
    required int warehouseId,
    int? warehouseDivisionId,
    String? description,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/pr-foods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'tanggal': tanggal,
          'warehouse_id': warehouseId,
          if (warehouseDivisionId != null) 'warehouse_division_id': warehouseDivisionId,
          if (description != null && description.isNotEmpty) 'description': description,
          'items': items,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to create PR Food'};
      }
    } catch (e) {
      print('Error creating PR Food: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Update PR Food
  Future<Map<String, dynamic>> updatePrFood({
    required int id,
    required String tanggal,
    required int warehouseId,
    int? warehouseDivisionId,
    String? description,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/pr-foods/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'tanggal': tanggal,
          'warehouse_id': warehouseId,
          if (warehouseDivisionId != null) 'warehouse_division_id': warehouseDivisionId,
          if (description != null && description.isNotEmpty) 'description': description,
          'items': items,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to update PR Food'};
      }
    } catch (e) {
      print('Error updating PR Food: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Delete PR Food
  Future<Map<String, dynamic>> deletePrFood(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/pr-foods/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          final data = jsonDecode(response.body);
          return {'success': true, 'message': data['message'] ?? 'PR Food deleted successfully'};
        } catch (e) {
          return {'success': true, 'message': 'PR Food deleted successfully'};
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'message': error['message'] ?? 'Failed to delete PR Food'};
        } catch (e) {
          return {'success': false, 'message': 'Failed to delete PR Food (Status: ${response.statusCode})'};
        }
      }
    } catch (e) {
      print('Error deleting PR Food: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get warehouses
  Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('getWarehouses: No token available');
        return [];
      }

      final url = Uri.parse('$baseUrl/api/approval-app/warehouses');
      print('getWarehouses: Fetching from $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('getWarehouses: Response status: ${response.statusCode}');
      print('getWarehouses: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('getWarehouses: Decoded data type: ${data.runtimeType}');
        
        if (data is List) {
          print('getWarehouses: Found ${data.length} warehouses (List format)');
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map) {
          print('getWarehouses: Data is Map, keys: ${data.keys}');
          if (data['success'] == true) {
            if (data['data'] != null) {
              final warehouses = List<Map<String, dynamic>>.from(data['data']);
              print('getWarehouses: Found ${warehouses.length} warehouses (data key)');
              return warehouses;
            } else if (data['warehouses'] != null) {
              final warehouses = List<Map<String, dynamic>>.from(data['warehouses']);
              print('getWarehouses: Found ${warehouses.length} warehouses (warehouses key)');
              return warehouses;
            }
          }
          // Try direct access to common keys
          if (data['data'] != null && data['data'] is List) {
            final warehouses = List<Map<String, dynamic>>.from(data['data']);
            print('getWarehouses: Found ${warehouses.length} warehouses (direct data access)');
            return warehouses;
          }
        }
        print('getWarehouses: Unknown data format, returning empty list');
      } else {
        print('getWarehouses: Error status ${response.statusCode}: ${response.body}');
      }

      return [];
    } catch (e) {
      print('Error getting warehouses: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get warehouse divisions
  Future<List<Map<String, dynamic>>> getWarehouseDivisions({int? warehouseId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('getWarehouseDivisions: No token available');
        return [];
      }

      // Use approval-app endpoint
      final uri = Uri.parse('$baseUrl/api/approval-app/warehouse-divisions').replace(
        queryParameters: warehouseId != null
            ? {'warehouse_id': warehouseId.toString()}
            : null,
      );

      print('getWarehouseDivisions: Fetching from $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('getWarehouseDivisions: Response status: ${response.statusCode}');
      print('getWarehouseDivisions: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('getWarehouseDivisions: Decoded data type: ${data.runtimeType}');
        
        if (data is List) {
          print('getWarehouseDivisions: Found ${data.length} divisions (List format)');
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map) {
          print('getWarehouseDivisions: Data is Map, keys: ${data.keys}');
          if (data['success'] == true) {
            if (data['data'] != null) {
              final divisions = List<Map<String, dynamic>>.from(data['data']);
              print('getWarehouseDivisions: Found ${divisions.length} divisions (data key)');
              return divisions;
            } else if (data['warehouse_divisions'] != null) {
              final divisions = List<Map<String, dynamic>>.from(data['warehouse_divisions']);
              print('getWarehouseDivisions: Found ${divisions.length} divisions (warehouse_divisions key)');
              return divisions;
            }
          }
          // Try direct access to common keys
          if (data['data'] != null && data['data'] is List) {
            final divisions = List<Map<String, dynamic>>.from(data['data']);
            print('getWarehouseDivisions: Found ${divisions.length} divisions (direct data access)');
            return divisions;
          }
        }
        print('getWarehouseDivisions: Unknown data format, returning empty list');
      } else {
        print('getWarehouseDivisions: Error status ${response.statusCode}: ${response.body}');
      }

      return [];
    } catch (e) {
      print('Error getting warehouse divisions: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get items
  Future<List<Map<String, dynamic>>> getItems() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data['success'] == true) {
          if (data['data'] != null) {
            return List<Map<String, dynamic>>.from(data['data']);
          } else if (data['items'] != null) {
            return List<Map<String, dynamic>>.from(data['items']);
          }
        }
      }

      return [];
    } catch (e) {
      print('Error getting items: $e');
      return [];
    }
  }

  // Check if within PR Foods schedule (10:00 - 15:00 is closed)
  bool isWithinPrFoodsSchedule() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final closeStart = today.add(const Duration(hours: 10)); // 10:00
    final closeEnd = today.add(const Duration(hours: 15)); // 15:00
    
    // Closed: 10:00 - 15:00
    // Open: 15:00 - 10:00 next day
    return !(now.isAfter(closeStart.subtract(const Duration(seconds: 1))) && 
             now.isBefore(closeEnd));
  }
}

