import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class RetailWarehouseFoodService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _base = '$baseUrl/api/approval-app/retail-warehouse-food';

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? paymentMethod,
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
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
      };
      final uri = Uri.parse(_base).replace(queryParameters: q);
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
    } catch (e) {
      print('RetailWarehouseFoodService getList: $e');
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final warehouses = data['warehouses'] ?? data['data']?['warehouses'];
        final divisions = data['warehouse_divisions'] ?? data['warehouseDivisions'] ?? data['data']?['warehouse_divisions'];
        final suppliers = data['suppliers'] ?? data['data']?['suppliers'];
        return {
          'success': true,
          'warehouses': warehouses is List ? warehouses : (data['warehouses'] ?? []),
          'warehouse_divisions': divisions is List ? divisions : (data['warehouse_divisions'] ?? data['warehouseDivisions'] ?? []),
          'suppliers': suppliers is List ? suppliers : (data['suppliers'] ?? []),
        };
      }
    } catch (e) {
      print('RetailWarehouseFoodService getCreateData: $e');
    }
    return null;
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
      print('RetailWarehouseFoodService getDetail: $e');
    }
    return null;
  }

  /// Search items for RWF form (same as web: search-for-outlet-transfer).
  Future<List<Map<String, dynamic>>> searchItems(String q, {required int warehouseId}) async {
    if (q.trim().length < 2) return [];
    try {
      final token = await _getToken();
      if (token == null) return [];
      final url = '$baseUrl/api/items/search-for-outlet-transfer?q=${Uri.encodeComponent(q.trim())}&warehouse_id=$warehouseId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return _parseItemSearchResponse(response.body);
      }
    } catch (e) {
      print('RetailWarehouseFoodService searchItems: $e');
    }
    return [];
  }

  List<Map<String, dynamic>> _parseItemSearchResponse(String body) {
    try {
      final data = jsonDecode(body);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map && data['data'] is List) {
        raw = data['data'] as List;
      } else if (data is Map && data['items'] is List) {
        raw = data['items'] as List;
      }
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }

  /// Get item units for selected item (payment_method affects default unit/price for contra_bon).
  Future<Map<String, dynamic>?> getItemUnits(int itemId, {String paymentMethod = 'cash'}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$_base/get-item-units/$itemId').replace(
        queryParameters: {'payment_method': paymentMethod},
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
    } catch (e) {
      print('RetailWarehouseFoodService getItemUnits: $e');
    }
    return null;
  }

  /// Store RWF. items: [{ item_name, qty, unit, unit_id, price }]
  Future<Map<String, dynamic>> store({
    required int warehouseId,
    int? warehouseDivisionId,
    required String transactionDate,
    required String paymentMethod,
    int? supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Unauthorized'};
      }
      final body = {
        'warehouse_id': warehouseId,
        if (warehouseDivisionId != null) 'warehouse_division_id': warehouseDivisionId,
        'transaction_date': transactionDate,
        'payment_method': paymentMethod,
        if (supplierId != null) 'supplier_id': supplierId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items.map((i) {
          return {
            'item_name': i['item_name'],
            'qty': i['qty'],
            'unit': i['unit']?.toString() ?? '',
            'unit_id': i['unit_id'],
            if (i['item_id'] != null) 'item_id': i['item_id'],
            'price': i['price'],
          };
        }).toList(),
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
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Berhasil disimpan',
          'data': data['data'],
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? data['error']?.toString() ?? 'Gagal menyimpan',
        'errors': data['errors'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Serial summary per baris (mirror web `/api/retail-warehouse-food/{id}/serial-summary`).
  Future<List<Map<String, dynamic>>> getSerialSummaryForRwf(int retailWarehouseFoodId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-warehouse-food/$retailWarehouseFoodId/serial-summary'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSerialUnitsForRwfItem(int retailWarehouseFoodItemId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-warehouse-food-items/$retailWarehouseFoodItemId/serial-units'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> generateSerialsForRwfItem(
    int retailWarehouseFoodItemId, {
    required int unitId,
    int? repackUnitId,
    double? repackQty,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};
      final body = <String, dynamic>{'unit_id': unitId};
      if (repackUnitId != null && repackQty != null && repackQty > 0) {
        body['repack_unit_id'] = repackUnitId;
        body['repack_qty'] = repackQty;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/retail-warehouse-food-items/$retailWarehouseFoodItemId/generate-serials'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final msg = decoded is Map<String, dynamic> ? decoded['message']?.toString() : null;
        return {'success': true, 'message': msg ?? 'Serial berhasil dibuat'};
      }
      if (decoded is Map<String, dynamic>) {
        return {'success': false, 'message': decoded['message']?.toString() ?? 'Gagal generate serial'};
      }
      return {'success': false, 'message': response.body};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getSerialsForRwfItem(int retailWarehouseFoodItemId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-warehouse-food-items/$retailWarehouseFoodItemId/serials'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> rollbackSerialsForRwfItem(int retailWarehouseFoodItemId, {int? unitId}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};
      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/retail-warehouse-food-items/$retailWarehouseFoodItemId/serials'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: unitId != null ? jsonEncode({'unit_id': unitId}) : jsonEncode({}),
      );
      if (response.body.isEmpty) {
        return {'success': response.statusCode >= 200 && response.statusCode < 300};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final ok = response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] != false;
        return {
          'success': ok,
          'message': decoded['message']?.toString(),
        };
      }
      return {'success': response.statusCode >= 200 && response.statusCode < 300};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
