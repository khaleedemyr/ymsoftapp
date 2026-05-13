import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetInventoryReportService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> getStockPosition({
    String? search,
    int? outletId,
    int? warehouseOutletId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (outletId != null) params['outlet_id'] = outletId.toString();
      if (warehouseOutletId != null) params['warehouse_outlet_id'] = warehouseOutletId.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-inventory-report/stock-position')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getStockPosition: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStockCardDetail({
    required int inventoryItemId,
    required int warehouseOutletId,
    String? from,
    String? to,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final params = <String, String>{
        'inventory_item_id': inventoryItemId.toString(),
        'warehouse_outlet_id': warehouseOutletId.toString(),
      };
      if (from != null && from.isNotEmpty) params['from'] = from;
      if (to != null && to.isNotEmpty) params['to'] = to;

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-inventory-report/stock-card/detail')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getStockCardDetail: $e');
      return null;
    }
  }
}
