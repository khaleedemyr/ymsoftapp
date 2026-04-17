import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';

class ItemService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    int? categoryId,
    String? status,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/items').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('ItemService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/items/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('ItemService.getCreateData error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true && data['item'] != null) {
          return data;
        }
        return data;
      }
    } catch (e) {
      print('ItemService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> create(Map<String, dynamic> body) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return decoded;
      }
      return decoded;
    } catch (e) {
      print('ItemService.create error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> createWithImages(
    Map<String, dynamic> body, {
    List<XFile> images = const [],
  }) async {
    return _submitMultipart(
      method: 'POST',
      path: '/api/approval-app/items',
      body: body,
      images: images,
    );
  }

  Future<Map<String, dynamic>?> update(int id, Map<String, dynamic> body) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (resp.statusCode == 200) {
        return decoded;
      }
      return decoded;
    } catch (e) {
      print('ItemService.update error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> updateWithImages(
    int id,
    Map<String, dynamic> body, {
    List<XFile> images = const [],
    List<String> deletedImages = const [],
  }) async {
    return _submitMultipart(
      method: 'PUT',
      path: '/api/approval-app/items/$id',
      body: body,
      images: images,
      deletedImages: deletedImages,
    );
  }

  Future<Map<String, dynamic>?> _submitMultipart({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    List<XFile> images = const [],
    List<String> deletedImages = const [],
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest(
        method == 'PUT' ? 'POST' : method,
        uri,
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
        request.fields[key] = value.toString();
      }

      putField('category_id', body['category_id']);
      putField('sub_category_id', body['sub_category_id']);
      putField('warehouse_division_id', body['warehouse_division_id']);
      putField('sku', body['sku']);
      putField('type', body['type']);
      putField('name', body['name']);
      putField('description', body['description']);
      putField('specification', body['specification']);
      putField('small_unit_id', body['small_unit_id']);
      putField('medium_unit_id', body['medium_unit_id']);
      putField('large_unit_id', body['large_unit_id']);
      putField('medium_conversion_qty', body['medium_conversion_qty']);
      putField('small_conversion_qty', body['small_conversion_qty']);
      putField('min_stock', body['min_stock']);
      putField('status', body['status']);
      putField('composition_type', body['composition_type']);
      putField('modifier_enabled', body['modifier_enabled'] == true ? 1 : 0);
      putField('exp', body['exp']);

      final modifierOptionIds = body['modifier_option_ids'];
      if (modifierOptionIds is List) {
        for (var i = 0; i < modifierOptionIds.length; i++) {
          putField('modifier_option_ids[$i]', modifierOptionIds[i]);
        }
      }

      final prices = body['prices'];
      if (prices is List) {
        for (var i = 0; i < prices.length; i++) {
          final p = prices[i];
          if (p is! Map) continue;
          putField('prices[$i][price_type]', p['price_type']);
          putField('prices[$i][region_id]', p['region_id']);
          putField('prices[$i][outlet_id]', p['outlet_id']);
          putField('prices[$i][price]', p['price']);
        }
      }

      final availabilities = body['availabilities'];
      if (availabilities is List) {
        for (var i = 0; i < availabilities.length; i++) {
          final a = availabilities[i];
          if (a is! Map) continue;
          putField('availabilities[$i][region_id]', a['region_id']);
          putField('availabilities[$i][outlet_id]', a['outlet_id']);
          putField('availabilities[$i][status]', a['status'] ?? 'available');
        }
      }

      final bom = body['bom'];
      if (bom is List) {
        for (var i = 0; i < bom.length; i++) {
          final b = bom[i];
          if (b is! Map) continue;
          putField('bom[$i][item_id]', b['item_id']);
          putField('bom[$i][qty]', b['qty']);
          putField('bom[$i][unit_id]', b['unit_id']);
          putField('bom[$i][stock_cut]', b['stock_cut'] == true ? 1 : 0);
        }
      }

      for (var i = 0; i < deletedImages.length; i++) {
        putField('deleted_images[$i]', deletedImages[i]);
      }

      for (final image in images) {
        request.files.add(
          await http.MultipartFile.fromPath('images[]', image.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>?
          : null;
      return decoded;
    } catch (e) {
      print('ItemService._submitMultipart error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> toggleStatus(int id, {required String status}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/items/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>?;
    } catch (e) {
      print('ItemService.toggleStatus error: $e');
    }
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        return data?['success'] == true;
      }
    } catch (e) {
      print('ItemService.delete error: $e');
    }
    return false;
  }
}
