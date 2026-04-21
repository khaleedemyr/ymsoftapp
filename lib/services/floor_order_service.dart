import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FloorOrderService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getFloorOrders({
    String? search,
    String? status,
    String? startDate,
    String? endDate,
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
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/floor-orders').replace(
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
      print('Error getting floor orders: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFloorOrder(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/floor-orders/$id'),
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
      print('Error getting floor order detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createFloorOrder({
    required String tanggal,
    required String arrivalDate,
    required int warehouseOutletId,
    required String foMode,
    String inputMode = 'tab',
    int? foScheduleId,
    String? description,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'tanggal': tanggal,
        'arrival_date': arrivalDate,
        'warehouse_outlet_id': warehouseOutletId,
        'fo_mode': foMode,
        'input_mode': inputMode,
        if (foScheduleId != null) 'fo_schedule_id': foScheduleId,
        if (description != null && description.isNotEmpty) 'description': description,
        'items': items,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/floor-orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final error = jsonDecode(response.body);
      return {
        'success': false,
        'message': error['message'] ?? 'Failed to create floor order',
      };
    } catch (e) {
      print('Error creating floor order: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateFloorOrder({
    required int id,
    required String tanggal,
    required String arrivalDate,
    required int warehouseOutletId,
    required String foMode,
    String inputMode = 'tab',
    int? foScheduleId,
    String? description,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final payload = {
        'tanggal': tanggal,
        'arrival_date': arrivalDate,
        'warehouse_outlet_id': warehouseOutletId,
        'fo_mode': foMode,
        'input_mode': inputMode,
        if (foScheduleId != null) 'fo_schedule_id': foScheduleId,
        if (description != null && description.isNotEmpty) 'description': description,
        'items': items,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/floor-orders/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final error = jsonDecode(response.body);
      return {
        'success': false,
        'message': error['message'] ?? 'Failed to update floor order',
      };
    } catch (e) {
      print('Error updating floor order: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteFloorOrder(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/floor-orders/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          return {'success': true, 'message': 'Floor order deleted'};
        }
      }

      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['error'] ?? error['message'] ?? 'Failed to delete'};
    } catch (e) {
      print('Error deleting floor order: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitFloorOrder(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/floor-orders/$id/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['message'] ?? 'Failed to submit'};
    } catch (e) {
      print('Error submitting floor order: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>?> checkExists({
    required String tanggal,
    required int outletId,
    required String foMode,
    int? excludeId,
    int? warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'tanggal': tanggal,
        'id_outlet': outletId.toString(),
        'fo_mode': foMode,
      };
      if (excludeId != null) queryParams['exclude_id'] = excludeId.toString();
      if (warehouseOutletId != null) {
        queryParams['warehouse_outlet_id'] = warehouseOutletId.toString();
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/floor-orders/check-exists')
          .replace(queryParameters: queryParams);

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
      print('Error checking floor order exists: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getForecastBudget({
    required String arrivalDate,
    required int warehouseOutletId,
    required double currentInputTotal,
    int? excludeFloorOrderId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'arrival_date': arrivalDate,
        'warehouse_outlet_id': warehouseOutletId.toString(),
        'current_input_total': currentInputTotal.toString(),
      };
      if (excludeFloorOrderId != null) {
        queryParams['exclude_floor_order_id'] = excludeFloorOrderId.toString();
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/floor-orders/forecast-budget')
          .replace(queryParameters: queryParams);

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
      print('Error getting floor order forecast budget: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getWarehouseOutletsByOutlet(int outletId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/warehouse-outlets/by-outlet')
          .replace(queryParameters: {'outlet_id': outletId.toString()});

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }

      return [];
    } catch (e) {
      print('Error getting warehouse outlets: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFoSchedules({int? outletId, int? regionId}) async {
    try {
      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (regionId != null) queryParams['region_id'] = regionId.toString();
      // Region param is optional in backend; allow caller to pass via queryParams

      final uri = Uri.parse('$baseUrl/api/fo-schedules/outlet-schedules').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      return [];
    } catch (e) {
      print('Error getting FO schedules: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> checkFoSchedule({
    required String foMode,
    required String day,
    int? outletId,
    int? regionId,
  }) async {
    try {
      final queryParams = <String, String>{
        'fo_mode': foMode,
        'day': day,
      };
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (regionId != null) queryParams['region_id'] = regionId.toString();

      final uri = Uri.parse('$baseUrl/api/fo-schedules/check').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error checking FO schedule: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getItemsBySchedule({
    required int scheduleId,
    int? outletId,
    int? regionId,
    bool excludeSupplier = true,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (regionId != null) queryParams['region_id'] = regionId.toString();
      if (excludeSupplier) queryParams['exclude_supplier'] = 'true';

      final uri = Uri.parse('$baseUrl/api/items/by-fo-schedule/$scheduleId').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['items'] is List) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting items by schedule: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getItemsByFOKhusus({
    int? outletId,
    int? regionId,
    bool excludeSupplier = true,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (regionId != null) queryParams['region_id'] = regionId.toString();
      if (excludeSupplier) queryParams['exclude_supplier'] = 'true';

      final uri = Uri.parse('$baseUrl/api/items/by-fo-khusus').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['items'] is List) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting items by FO khusus: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTodayItemSchedules() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/item-schedules/today'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['schedules'] is List) {
          return List<Map<String, dynamic>>.from(data['schedules']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting today item schedules: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchItems({
    required String query,
    required int outletId,
    int? regionId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{
        'q': query,
        'outlet_id': outletId.toString(),
      };
      if (regionId != null) queryParams['region_id'] = regionId.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/items/search')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['items'] is List) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
      }

      return [];
    } catch (e) {
      print('Error searching items: $e');
      return [];
    }
  }

  Future<String?> downloadPdf(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/floor-orders/$id/export-pdf'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/floor_order_$id.pdf');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }

      return null;
    } catch (e) {
      print('Error downloading floor order PDF: $e');
      return null;
    }
  }
}
