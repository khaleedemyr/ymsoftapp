import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk Penjualan Antar Gudang (Warehouse Sales).
/// Endpoint: api/approval-app/warehouse-sales
class WarehouseSaleService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _base = '$baseUrl/api/approval-app/warehouse-sales';

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? from,
    String? to,
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
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
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
      print('WarehouseSaleService getList: $e');
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
      print('WarehouseSaleService getCreateData: $e');
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
      print('WarehouseSaleService getDetail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchItems(String query) async {
    if (query.trim().length < 1) return [];
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$_base/search-items').replace(queryParameters: {'q': query.trim()}),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['items'] as List? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('WarehouseSaleService searchItems: $e');
    }
    return [];
  }

  Future<double?> getItemPrice({required int itemId, int? warehouseId}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{'item_id': itemId.toString()};
      if (warehouseId != null) params['warehouse_id'] = warehouseId.toString();
      final response = await http.get(
        Uri.parse('$_base/item-price').replace(queryParameters: params),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final p = data['price'];
        if (p is num) return p.toDouble();
        if (p != null) return double.tryParse(p.toString());
      }
    } catch (e) {
      print('WarehouseSaleService getItemPrice: $e');
    }
    return null;
  }

  /// Submit penjualan antar gudang.
  /// items: [{ item_id, qty, selected_unit, price, note? }]
  Future<Map<String, dynamic>> store({
    required int sourceWarehouseId,
    required int targetWarehouseId,
    required String date,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final body = {
        'source_warehouse_id': sourceWarehouseId,
        'target_warehouse_id': targetWarehouseId,
        'date': date,
        if (note != null && note.isNotEmpty) 'note': note,
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
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Gagal menyimpan',
      };
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
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Gagal menghapus',
      };
    } catch (e) {
      print('WarehouseSaleService delete: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
