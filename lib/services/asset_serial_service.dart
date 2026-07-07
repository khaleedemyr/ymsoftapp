import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AssetSerialService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    return AuthService().getToken();
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> getMeta() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/meta');
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSerials({
    String? search,
    int? ownerOutletId,
    int? warehouseOutletId,
    String? status,
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
      if (ownerOutletId != null) params['owner_outlet_id'] = ownerOutletId.toString();
      if (warehouseOutletId != null) params['warehouse_outlet_id'] = warehouseOutletId.toString();
      if (status != null && status.isNotEmpty) params['status'] = status;

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getItemsWithStock({
    required int ownerOutletId,
    int? warehouseOutletId,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{'owner_outlet_id': ownerOutletId.toString()};
      if (warehouseOutletId != null) params['warehouse_outlet_id'] = warehouseOutletId.toString();
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/items-with-stock').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> enableTracking(int inventoryItemId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/enable-tracking');
      final response = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({'inventory_item_id': inventoryItemId}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> prepareTag({
    required int inventoryItemId,
    required int ownerOutletId,
    required int warehouseOutletId,
    required String tagUid,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/prepare-tag');
      final response = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'inventory_item_id': inventoryItemId,
          'owner_outlet_id': ownerOutletId,
          'warehouse_outlet_id': warehouseOutletId,
          'tag_uid': tagUid,
        }),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> confirmTag({
    required String serialNumber,
    required String tagUid,
    required int inventoryItemId,
    required int ownerOutletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/confirm-tag');
      final response = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'serial_number': serialNumber,
          'tag_uid': tagUid,
          'inventory_item_id': inventoryItemId,
          'owner_outlet_id': ownerOutletId,
          'warehouse_outlet_id': warehouseOutletId,
        }),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> lookup({String? serialNumber, String? tagUid}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final params = <String, String>{};
      if (serialNumber != null && serialNumber.isNotEmpty) params['serial_number'] = serialNumber;
      if (tagUid != null && tagUid.isNotEmpty) params['tag_uid'] = tagUid;

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/lookup').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/$id');
      final response = await http.get(uri, headers: _headers(token));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> deleteSerial(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/asset-serials/$id');
      final response = await http.delete(uri, headers: _headers(token));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
