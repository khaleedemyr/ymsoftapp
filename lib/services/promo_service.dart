import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';

class PromoService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return auth.getToken();
  }

  Future<Map<String, dynamic>?> _decode(http.Response response) async {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body) as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> getList({
    String? search,
    String? type,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (type != null && type.isNotEmpty) query['type'] = type;
      if (status != null && status.isNotEmpty) query['status'] = status;
      final uri = Uri.parse('$baseUrl/api/approval-app/promos')
          .replace(queryParameters: query);
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/promos/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.get(
        Uri.parse('$baseUrl/api/approval-app/promos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse('$baseUrl/api/approval-app/promos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createMultipart(
    Map<String, dynamic> payload, {
    XFile? banner,
  }) async {
    return _submitMultipart(
      method: 'POST',
      path: '/api/approval-app/promos',
      payload: payload,
      banner: banner,
    );
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> payload) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.put(
        Uri.parse('$baseUrl/api/approval-app/promos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateMultipart(
    int id,
    Map<String, dynamic> payload, {
    XFile? banner,
  }) async {
    return _submitMultipart(
      method: 'PUT',
      path: '/api/approval-app/promos/$id',
      payload: payload,
      banner: banner,
    );
  }

  Future<Map<String, dynamic>> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/promos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleStatus(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/promos/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      return await _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> _submitMultipart({
    required String method,
    required String path,
    required Map<String, dynamic> payload,
    XFile? banner,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final request = http.MultipartRequest(
        method == 'PUT' ? 'POST' : method,
        Uri.parse('$baseUrl$path'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (method == 'PUT') {
        request.fields['_method'] = 'PUT';
      }

      void putField(String key, dynamic value) {
        if (value == null) return;
        if (value is List || value is Map) {
          request.fields[key] = jsonEncode(value);
          return;
        }
        request.fields[key] = value.toString();
      }

      putField('name', payload['name']);
      putField('type', payload['type']);
      putField('value', payload['value']);
      putField('max_discount', payload['max_discount']);
      putField('is_multiple', payload['is_multiple']);
      putField('min_transaction', payload['min_transaction']);
      putField('max_transaction', payload['max_transaction']);
      putField('start_date', payload['start_date']);
      putField('end_date', payload['end_date']);
      putField('start_time', payload['start_time']);
      putField('end_time', payload['end_time']);
      putField('description', payload['description']);
      putField('terms', payload['terms']);
      putField('need_member', payload['need_member']);
      putField('all_tiers', payload['all_tiers'] == true ? 1 : 0);
      putField('remove_banner', payload['remove_banner'] == true ? 1 : 0);
      putField('status', payload['status']);
      putField('by_type', payload['by_type']);
      putField('outlet_type', payload['outlet_type']);

      final days = payload['days'];
      if (days is List) {
        for (var i = 0; i < days.length; i++) {
          putField('days[$i]', days[i]);
        }
      }
      final tiers = payload['tiers'];
      if (tiers is List) {
        for (var i = 0; i < tiers.length; i++) {
          putField('tiers[$i]', tiers[i]);
        }
      }
      final categories = payload['categories'];
      if (categories is List) {
        for (var i = 0; i < categories.length; i++) {
          putField('categories[$i]', categories[i]);
        }
      }
      final items = payload['items'];
      if (items is List) {
        for (var i = 0; i < items.length; i++) {
          putField('items[$i]', items[i]);
        }
      }
      final outlets = payload['outlets'];
      if (outlets is List) {
        for (var i = 0; i < outlets.length; i++) {
          putField('outlets[$i]', outlets[i]);
        }
      }
      final regions = payload['regions'];
      if (regions is List) {
        for (var i = 0; i < regions.length; i++) {
          putField('regions[$i]', regions[i]);
        }
      }
      final buyItems = payload['buy_items'];
      if (buyItems is List) {
        for (var i = 0; i < buyItems.length; i++) {
          putField('buy_items[$i]', buyItems[i]);
        }
      }
      final getItems = payload['get_items'];
      if (getItems is List) {
        for (var i = 0; i < getItems.length; i++) {
          putField('get_items[$i]', getItems[i]);
        }
      }

      if (banner != null) {
        request.files.add(await http.MultipartFile.fromPath('banner', banner.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return await _decode(response) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
