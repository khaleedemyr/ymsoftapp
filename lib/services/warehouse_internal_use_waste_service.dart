import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseInternalUseWasteService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? type,
    String? dateFrom,
    String? dateTo,
    int? warehouseId,
    String? search,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final queryParams = <String, String>{};
      if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (warehouseId != null) queryParams['warehouse_id'] = warehouseId.toString();
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/internal-use-waste').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('WarehouseInternalUseWasteService getList: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/internal-use-waste/create-data'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
      }
      return null;
    } catch (e) {
      print('WarehouseInternalUseWasteService getCreateData: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/internal-use-waste/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
      }
      return null;
    } catch (e) {
      print('WarehouseInternalUseWasteService getDetail: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getItemUnits(int itemId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/internal-use-waste/item/$itemId/units'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        final units = d is Map ? (d['units'] as List?) : null;
        if (units != null) {
          return units.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      print('WarehouseInternalUseWasteService getItemUnits: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStock({required int warehouseId, required int itemId}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/internal-use-waste/stock').replace(
        queryParameters: {'warehouse_id': warehouseId.toString(), 'item_id': itemId.toString()},
      );
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d is Map<String, dynamic>) return d;
      }
      return null;
    } catch (e) {
      print('WarehouseInternalUseWasteService getStock: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> validateSerialForIUW({
    required String serialNumber,
    required int warehouseId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'valid': false, 'message': 'Unauthorized'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/internal-use-waste/validate-serial'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'serial_number': serialNumber,
          'warehouse_id': warehouseId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'valid': false, 'message': 'Gagal validasi serial'};
      }
    } catch (e) {
      return {'valid': false, 'message': e.toString()};
    }
  }

  /// Sama payload dengan web `InternalUseWaste/Create` — dokumen + banyak baris item.
  Future<Map<String, dynamic>?> storeDocument({
    required String type,
    required String date,
    required int warehouseId,
    int? rukoId,
    String? notes,
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? serialItems,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final body = <String, dynamic>{
        'type': type,
        'date': date,
        'warehouse_id': warehouseId,
        if (items != null && items.isNotEmpty) 'items': items,
        if (serialItems != null && serialItems.isNotEmpty) 'serial_items': serialItems,
      };
      if (type == 'internal_use' && rukoId != null) body['ruko_id'] = rukoId;
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/internal-use-waste'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('WarehouseInternalUseWasteService storeDocument: $e');
      return null;
    }
  }

  /// Legacy satu baris (backend `mergeLegacySingleItemPayload`).
  Future<Map<String, dynamic>?> store({
    required String type,
    required String date,
    required int warehouseId,
    int? rukoId,
    required int itemId,
    required double qty,
    required int unitId,
    String? notes,
  }) async {
    return storeDocument(
      type: type,
      date: date,
      warehouseId: warehouseId,
      rukoId: rukoId,
      notes: notes,
      items: [
        {
          'item_id': itemId,
          'qty': qty,
          'unit_id': unitId,
        },
      ],
    );
  }

  Future<Map<String, dynamic>?> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/internal-use-waste/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('WarehouseInternalUseWasteService delete: $e');
      return null;
    }
  }
}
