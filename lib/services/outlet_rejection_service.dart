import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk Outlet Rejection (penolakan barang dari outlet ke gudang).
/// Endpoint: api/approval-app/outlet-rejections
class OutletRejectionService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _base = '$baseUrl/api/approval-app/outlet-rejections';

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    int? outletId,
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    int? page,
    int perPage = 15,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final q = <String, String>{
        'per_page': perPage.toString(),
        if (page != null) 'page': page.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (outletId != null) 'outlet_id': outletId.toString(),
        if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      };
      final uri = Uri.parse(_base).replace(queryParameters: q);
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('OutletRejectionService getList: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('OutletRejectionService getCreateData: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getDeliveryOrders({
    required int outletId,
    required int warehouseId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$_base/delivery-orders').replace(queryParameters: {
        'outlet_id': outletId.toString(),
        'warehouse_id': warehouseId.toString(),
      });
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('OutletRejectionService getDeliveryOrders: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getDeliveryOrderItems(int deliveryOrderId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$_base/delivery-order-items').replace(queryParameters: {
        'delivery_order_id': deliveryOrderId.toString(),
      });
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('OutletRejectionService getDeliveryOrderItems: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getItems({String search = ''}) async {
    if (search.trim().length < 1) return [];
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$_base/items').replace(queryParameters: {'search': search.trim()});
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('OutletRejectionService getItems: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('OutletRejectionService getDetail: $e');
    }
    return null;
  }

  /// items: [{ item_id, unit_id, qty_rejected, rejection_reason?, item_condition, condition_notes? }]
  /// item_condition: good | damaged | expired | other
  Future<Map<String, dynamic>> store({
    required String rejectionDate,
    required int outletId,
    required int warehouseId,
    int? deliveryOrderId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final body = {
        'rejection_date': rejectionDate,
        'outlet_id': outletId,
        'warehouse_id': warehouseId,
        if (deliveryOrderId != null) 'delivery_order_id': deliveryOrderId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      };
      final response = await http.post(
        Uri.parse(_base),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      return {'success': false, 'message': data['message']?.toString() ?? 'Gagal menyimpan'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String rejectionDate,
    required int outletId,
    required int warehouseId,
    int? deliveryOrderId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final body = {
        'rejection_date': rejectionDate,
        'outlet_id': outletId,
        'warehouse_id': warehouseId,
        if (deliveryOrderId != null) 'delivery_order_id': deliveryOrderId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      };
      final response = await http.put(
        Uri.parse('$_base/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message']?.toString() ?? 'Gagal update'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.delete(
        Uri.parse('$_base/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message']?.toString() ?? 'Gagal menghapus'};
    } catch (e) {
      print('OutletRejectionService delete: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> cancel(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_base/$id/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message']?.toString() ?? 'Gagal batalkan'};
    } catch (e) {
      print('OutletRejectionService cancel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Submit draft → status submitted (untuk approval).
  Future<Map<String, dynamic>> submit(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final response = await http.post(
        Uri.parse('$_base/$id/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      return {'success': false, 'message': data['message']?.toString() ?? 'Gagal submit'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
