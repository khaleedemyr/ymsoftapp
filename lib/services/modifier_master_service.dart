import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ModifierMasterService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return auth.getToken();
  }

  Future<Map<String, dynamic>> _decodeMap(http.Response response) async {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Format respons tidak valid'};
    } catch (_) {
      return {'success': false, 'message': 'Gagal membaca respons (${response.statusCode})'};
    }
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
      };

  // MENU TYPES
  Future<Map<String, dynamic>> getMenuTypes({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri = Uri.parse('$baseUrl/api/approval-app/menu-types').replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createMenuType({
    required String type,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/menu-types'),
        headers: _headers(token, json: true),
        body: jsonEncode({'type': type, 'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateMenuType({
    required int id,
    required String type,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/menu-types/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({'type': type, 'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleMenuTypeStatus({
    required int id,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/menu-types/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode({'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteMenuType(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/menu-types/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // MODIFIERS
  Future<Map<String, dynamic>> getModifiers({
    String? search,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;

      final uri = Uri.parse('$baseUrl/api/approval-app/modifiers').replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createModifier(String name) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/modifiers'),
        headers: _headers(token, json: true),
        body: jsonEncode({'name': name}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateModifier(int id, String name) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/modifiers/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({'name': name}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteModifier(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/modifiers/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // MODIFIER OPTIONS
  Future<Map<String, dynamic>> getModifierOptions({
    String? search,
    int? modifierId,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (modifierId != null) query['modifier_id'] = modifierId.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/modifier-options').replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getModifierOptionCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/modifier-options/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getItemsForModifierBom() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/items/for-modifier-bom'),
        headers: _headers(token),
      );
      final decoded = await _decodeMap(response);

      dynamic rawItems = decoded;
      if (decoded['items'] is List) {
        rawItems = decoded['items'];
      } else if (decoded['data'] is List) {
        rawItems = decoded['data'];
      } else if (decoded['success'] == true && decoded['items'] is! List) {
        rawItems = const [];
      }

      final rows = (rawItems as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      return rows.map((item) {
        final id = item['id'] is int
            ? item['id'] as int
            : int.tryParse(item['id']?.toString() ?? '') ?? 0;
        final name = (item['name'] ?? item['nama'] ?? '').toString().trim();
        return {
          ...item,
          'id': id,
          'name': name.isEmpty ? (id > 0 ? 'Item $id' : '-') : name,
        };
      }).where((e) => (e['id'] as int) > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getItemUnitsForModifierBom(int itemId) async {
    try {
      final token = await _getToken();
      if (token == null || itemId <= 0) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/items/$itemId/detail'),
        headers: _headers(token),
      );
      final decoded = await _decodeMap(response);
      final item = decoded['item'] is Map<String, dynamic>
          ? decoded['item'] as Map<String, dynamic>
          : <String, dynamic>{};
      final units = (item['units'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      return units.map((unit) {
        final id = unit['id'] is int
            ? unit['id'] as int
            : int.tryParse(unit['id']?.toString() ?? '') ?? 0;
        final name = (unit['name'] ?? unit['unit_name'] ?? '').toString().trim();
        final type = (unit['type'] ?? '').toString().trim();
        return {
          ...unit,
          'id': id,
          'name': name.isEmpty ? (id > 0 ? 'Unit $id' : '-') : name,
          'type': type,
        };
      }).where((e) => (e['id'] as int) > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createModifierOption({
    required int modifierId,
    required String name,
    String? modifierBomJson,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/modifier-options'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'modifier_id': modifierId,
          'name': name,
          'modifier_bom_json': (modifierBomJson ?? '').trim().isEmpty ? null : modifierBomJson,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateModifierOption({
    required int id,
    required int modifierId,
    required String name,
    String? modifierBomJson,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/modifier-options/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'modifier_id': modifierId,
          'name': name,
          'modifier_bom_json': (modifierBomJson ?? '').trim().isEmpty ? null : modifierBomJson,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteModifierOption(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/modifier-options/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}

