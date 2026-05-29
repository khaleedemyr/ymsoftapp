import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Delivery Order — mirror web `/delivery-order` + `/api/packing-list/...` (approval-app bearer).
class DeliveryOrderService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _base = '$baseUrl/api/approval-app/delivery-orders';

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse(_base).replace(queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      });
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/create-data'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getStruk(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_base/$id/struk'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// [packingListId] numeric id or `gr_<good_receive_id>` (same as web Form).
  Future<Map<String, dynamic>?> getPackingListItems(String packingListId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final enc = Uri.encodeComponent(packingListId);
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/packing-list/$enc/items'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Auto-detect barcode vs nomor seri (selaras web `/api/delivery-order/resolve-scan`).
  Future<Map<String, dynamic>> resolveScan({
    required String code,
    required String packingListId,
    required int warehouseId,
    required List<int> itemIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'type': 'unknown', 'message': 'Unauthorized'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/delivery-order/resolve-scan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': code,
          'packing_list_id': packingListId,
          'warehouse_id': warehouseId,
          'item_ids': itemIds,
        }),
      );
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'type': 'unknown', 'message': 'Invalid response'};
    } catch (e) {
      return {'type': 'unknown', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> validateSerial({
    required String serialNumber,
    required String packingListId,
    required int warehouseId,
    required List<int> itemIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'valid': false, 'message': 'Unauthorized'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/delivery-order/validate-serial'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'serial_number': serialNumber,
          'packing_list_id': packingListId,
          'warehouse_id': warehouseId,
          'item_ids': itemIds,
        }),
      );
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'valid': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'valid': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> store({
    required String packingListId,
    required String scanMode,
    int? outletId,
    int? warehouseOutletId,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> scannedSerials = const [],
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Unauthorized'};
      }
      final body = {
        'packing_list_id': packingListId,
        'scan_mode': scanMode,
        'outlet_id': outletId,
        'warehouse_outlet_id': warehouseOutletId,
        'scanned_serials': scannedSerials,
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
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': false, 'message': response.body};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> destroy(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Unauthorized'};
      }
      final response = await http.delete(
        Uri.parse('$_base/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'success': response.statusCode >= 200 && response.statusCode < 300};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': response.statusCode >= 200 && response.statusCode < 300};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
