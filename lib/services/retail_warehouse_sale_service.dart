import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class RetailWarehouseSaleService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _base = '$baseUrl/api/approval-app/retail-warehouse-sale';

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
      print('RetailWarehouseSaleService getList: $e');
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
        // Normalize: some APIs wrap in data, or use different keys
        final warehouses = data['warehouses'] ?? data['data']?['warehouses'];
        final divisions = data['warehouse_divisions'] ?? data['warehouseDivisions'] ?? data['data']?['warehouse_divisions'];
        final customers = data['customers'] ?? data['data']?['customers'];
        if (warehouses != null || divisions != null || customers != null) {
          return {
            'success': true,
            'warehouses': warehouses is List ? warehouses : (data['warehouses'] ?? []),
            'warehouse_divisions': divisions is List ? divisions : (data['warehouse_divisions'] ?? data['warehouseDivisions'] ?? []),
            'customers': customers is List ? customers : (data['customers'] ?? []),
          };
        }
        return data;
      }
    } catch (e) {
      print('RetailWarehouseSaleService getCreateData: $e');
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
      print('RetailWarehouseSaleService getDetail: $e');
    }
    return null;
  }

  /// Search item by barcode
  Future<Map<String, dynamic>?> searchItemByBarcode({
    required String barcode,
    required int warehouseId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_base/search-items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'barcode': barcode,
          'warehouse_id': warehouseId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('RetailWarehouseSaleService searchItemByBarcode: $e');
    }
    return null;
  }

  /// Search items by name
  Future<List<Map<String, dynamic>>> searchItemsByName({
    required String search,
    required int warehouseId,
  }) async {
    if (search.trim().length < 2) return [];
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.post(
        Uri.parse('$_base/search-items-by-name'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'search': search.trim(),
          'warehouse_id': warehouseId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['items'] != null) {
          final list = data['items'] as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('RetailWarehouseSaleService searchItemsByName: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.post(
        Uri.parse('$_base/search-customers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'search': query}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['customers'] as List? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('RetailWarehouseSaleService searchCustomers: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> storeCustomer({
    required String code,
    required String name,
    required String type,
    String? phone,
    String? email,
    String? address,
    String? region,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_base/store-customer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': code,
          'name': name,
          'type': type,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (address != null) 'address': address,
          if (region != null) 'region': region,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('RetailWarehouseSaleService storeCustomer: $e');
    }
    return null;
  }

  Future<double?> getItemPrice(int itemId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/item-price').replace(
          queryParameters: {'item_id': itemId.toString()},
        ),
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
      print('RetailWarehouseSaleService getItemPrice: $e');
    }
    return null;
  }

  /// Submit sale. items: [{ item_id, barcode?, qty, unit, price, subtotal }]
  Future<Map<String, dynamic>> store({
    required int customerId,
    required String saleDate,
    required int warehouseId,
    int? warehouseDivisionId,
    String? notes,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Unauthorized'};
      }
      final body = {
        'customer_id': customerId,
        'sale_date': saleDate,
        'warehouse_id': warehouseId,
        if (warehouseDivisionId != null) 'warehouse_division_id': warehouseDivisionId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
        'total_amount': totalAmount,
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
      if (response.statusCode == 200) {
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
      print('RetailWarehouseSaleService delete: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
