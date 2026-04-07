import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/packing_list_models.dart';
import 'auth_service.dart';

class PackingListService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Get list packing list dengan filter dan pagination
  Future<Map<String, dynamic>> getPackingLists({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? loadData,
    int? perPage,
    int? page,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (page != null) queryParams['page'] = page.toString();

      final uri = Uri.parse('$baseUrl/api/packing-list')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseData = data is Map && data.containsKey('props') 
            ? data['props'] 
            : data;
        
        // Parse packing lists
        List<PackingList> packingLists = [];
        if (responseData['packingLists'] != null) {
          final packingListsData = responseData['packingLists']['data'] as List<dynamic>?;
          if (packingListsData != null) {
            packingLists = packingListsData.map((pl) {
              final plMap = pl is Map<String, dynamic> ? pl : Map<String, dynamic>.from(pl);
              return PackingList.fromJson(plMap);
            }).toList();
          }
        }

        // Parse pagination
        Map<String, dynamic> pagination = {};
        if (responseData['packingLists'] != null) {
          final plData = responseData['packingLists'];
          pagination = {
            'current_page': plData['current_page'] ?? 1,
            'last_page': plData['last_page'] ?? 1,
            'per_page': plData['per_page'] ?? 15,
            'total': plData['total'] ?? 0,
            'from': plData['from'],
            'to': plData['to'],
            'links': plData['links'] ?? [],
          };
        }

        return {
          'success': true,
          'data': packingLists,
          'pagination': pagination,
        };
      } else {
        String errorMessage = 'Failed to load packing lists: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            errorMessage = errorData['message'] ?? 
                          errorData['error'] ?? 
                          errorData['errors']?.toString() ?? 
                          errorMessage;
          }
        } catch (e) {
          // Jika response body bukan JSON, gunakan body sebagai error message
          if (response.body.isNotEmpty) {
            errorMessage = 'Server error: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching packing lists: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get floor orders untuk create packing list
  Future<Map<String, dynamic>> getFloorOrders({
    String? arrivalDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final queryParams = <String, String>{};
      if (arrivalDate != null && arrivalDate.isNotEmpty) {
        queryParams['arrival_date'] = arrivalDate;
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/create')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseData = data is Map && data.containsKey('props') 
            ? data['props'] 
            : data;
        
        // Parse floor orders
        List<FloorOrder> floorOrders = [];
        if (responseData['floorOrders'] != null) {
          final floorOrdersData = responseData['floorOrders'] as List<dynamic>;
          floorOrders = floorOrdersData.map((fo) {
            final foMap = fo is Map<String, dynamic> ? fo : Map<String, dynamic>.from(fo);
            return FloorOrder.fromJson(foMap);
          }).toList();
        }

        // Parse warehouse divisions
        List<WarehouseDivision> warehouseDivisions = [];
        if (responseData['warehouseDivisions'] != null) {
          final divisionsData = responseData['warehouseDivisions'] as List<dynamic>;
          warehouseDivisions = divisionsData.map((d) {
            final dMap = d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d);
            return WarehouseDivision.fromJson(dMap);
          }).toList();
        }

        return {
          'success': true,
          'floorOrders': floorOrders,
          'warehouseDivisions': warehouseDivisions,
        };
      } else {
        String errorMessage = 'Failed to load floor orders: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            errorMessage = errorData['message'] ?? 
                          errorData['error'] ?? 
                          errorData['errors']?.toString() ?? 
                          errorMessage;
            // Tambahkan detail error jika ada
            if (errorData['file'] != null && errorData['line'] != null) {
              errorMessage += '\nFile: ${errorData['file']} (Line: ${errorData['line']})';
            }
          }
        } catch (e) {
          // Jika response body bukan JSON, gunakan body sebagai error message
          if (response.body.isNotEmpty) {
            errorMessage = 'Server error: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
          }
        }
        print('Error response body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching floor orders: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get available items untuk packing
  Future<Map<String, dynamic>> getAvailableItems({
    required int foId,
    required int divisionId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/available-items')
          .replace(queryParameters: {
        'fo_id': foId.toString(),
        'division_id': divisionId.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final itemsData = data['items'] as List<dynamic>? ?? [];
        
        List<AvailableItem> items = itemsData.map((item) {
          final itemMap = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
          return AvailableItem.fromJson(itemMap);
        }).toList();

        return {
          'success': true,
          'items': items,
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to load available items');
        } catch (e) {
          throw Exception('Failed to load available items: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching available items: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Create packing list
  Future<Map<String, dynamic>> createPackingList({
    required int foodFloorOrderId,
    required int warehouseDivisionId,
    required List<Map<String, dynamic>> items,
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final body = {
        'food_floor_order_id': foodFloorOrderId,
        'warehouse_division_id': warehouseDivisionId,
        'items': items,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      };

      final uri = Uri.parse('$baseUrl/api/packing-list');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Packing List berhasil dibuat.',
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to create packing list');
        } catch (e) {
          throw Exception('Failed to create packing list: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error creating packing list: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get detail packing list
  Future<Map<String, dynamic>> getPackingListDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/$id');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseData = data is Map && data.containsKey('props') 
            ? data['props'] 
            : data;
        
        final packingList = PackingList.fromJson(responseData['packingList']);

        return {
          'success': true,
          'data': packingList,
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to load packing list detail');
        } catch (e) {
          throw Exception('Failed to load packing list detail: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching packing list detail: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete packing list
  Future<Map<String, dynamic>> deletePackingList(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/$id');

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Packing List berhasil dihapus.',
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to delete packing list');
        } catch (e) {
          throw Exception('Failed to delete packing list: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error deleting packing list: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get summary packing list
  Future<Map<String, dynamic>> getSummary(String tanggal) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/summary')
          .replace(queryParameters: {'tanggal': tanggal});

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['divisions'] ?? [],
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to load summary');
        } catch (e) {
          throw Exception('Failed to load summary: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching summary: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get unpicked floor orders
  Future<Map<String, dynamic>> getUnpickedFloorOrders(String tanggal) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/unpicked-floor-orders')
          .replace(queryParameters: {'tanggal': tanggal});

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['outlets'] ?? [],
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to load unpicked floor orders');
        } catch (e) {
          throw Exception('Failed to load unpicked floor orders: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching unpicked floor orders: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get warehouse divisions
  Future<Map<String, dynamic>> getWarehouseDivisions() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/api/packing-list/warehouse-divisions');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<WarehouseDivision> divisions = [];
        if (data is List) {
          divisions = data.map((d) {
            final dMap = d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d);
            return WarehouseDivision.fromJson(dMap);
          }).toList();
        }

        return {
          'success': true,
          'data': divisions,
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to load warehouse divisions');
        } catch (e) {
          throw Exception('Failed to load warehouse divisions: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching warehouse divisions: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

