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
      final totalAmount = items.fold<double>(0, (sum, i) {
        final q = (i['qty'] is num) ? (i['qty'] as num).toDouble() : double.tryParse(i['qty']?.toString() ?? '0') ?? 0;
        final p = (i['price'] is num) ? (i['price'] as num).toDouble() : double.tryParse(i['price']?.toString() ?? '0') ?? 0;
        return sum + q * p;
      });
      final body = {
        'warehouse_id': warehouseId,
        if (warehouseDivisionId != null) 'warehouse_division_id': warehouseDivisionId,
        'transaction_date': transactionDate,
        'payment_method': paymentMethod,
        if (supplierId != null) 'supplier_id': supplierId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items.map((i) => {
          'item_name': i['item_name'],
          'qty': i['qty'],
          'unit': i['unit']?.toString() ?? '',
          'unit_id': i['unit_id'],
          'price': i['price'],
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
}
