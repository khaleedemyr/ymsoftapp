import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletCategoryCostService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    int? outletId,
    int? warehouseOutletId,
    String? search,
    int? page,
    int? perPage,
    String? type,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (warehouseOutletId != null) queryParams['warehouse_outlet_id'] = warehouseOutletId.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      print('OutletCategoryCostService.getList -> ${uri.toString()} (status: ${resp.statusCode})');
      final bodyPreview = resp.body != null && resp.body.length > 1000 ? resp.body.substring(0, 1000) + '...(truncated)' : resp.body;
      print('Response body preview: $bodyPreview');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        print('Decoded response type: ${decoded.runtimeType}');
        if (decoded is Map<String, dynamic>) return decoded;
        // some endpoints may return a plain list instead of a paginated map
        if (decoded is List) return {'data': decoded};
      }

      // If we get a 404 on the approval-app path, try some common alternate paths
      if (resp.statusCode == 404) {
        final altPaths = [
          '/api/internal-use-waste',
          '/internal-use-waste',
          '/api/outlet-internal-use-waste',
        ];

        for (final p in altPaths) {
          try {
            final altUri = Uri.parse('$baseUrl$p').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
            print('Trying alternate endpoint: $altUri');
            final altResp = await http.get(altUri, headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            });
            print('Alt response ${altUri}: ${altResp.statusCode}');
            if (altResp.statusCode == 200) {
              final decoded = jsonDecode(altResp.body);
              if (decoded is Map<String, dynamic>) return decoded;
              if (decoded is List) return {'data': decoded};
            }
          } catch (e) {
            print('Alternate request failed for $p: $e');
          }
        }
      }
    } catch (e) {
      print('Error getting category cost list: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/$id');

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('Error getting category cost detail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error getting outlets for category cost: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getWarehouseOutlets({int? outletId}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-inventory/warehouse-outlets').replace(
        queryParameters: outletId != null ? {'outlet_id': outletId.toString()} : null,
      );

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error getting warehouse outlets for category cost: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchItems({String? search, int? limit}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/items').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error searching category cost items: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> save(Map<String, dynamic> payload) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste');
      final resp = await http.post(uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload));

      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return {
          'success': false,
          'message': 'Gagal menyimpan data (${resp.statusCode})'
        };
      }
    } catch (e) {
      print('Error saving category cost: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> storeAndSubmit(Map<String, dynamic> payload) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/store-and-submit');
      final resp = await http.post(uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload));

      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return {
          'success': false,
          'message': 'Gagal submit data (${resp.statusCode})'
        };
      }
    } catch (e) {
      print('Error storeAndSubmit category cost: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getStock({
    required int itemId,
    required int outletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/stock').replace(
        queryParameters: {
          'item_id': itemId.toString(),
          'outlet_id': outletId.toString(),
          'warehouse_outlet_id': warehouseOutletId.toString(),
        },
      );

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return {
          'success': false,
          'message': 'Stok tidak tersedia (${resp.statusCode})'
        };
      }
    } catch (e) {
      print('Error getting stock: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> submit(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/$id/submit');
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('Error submitting category cost: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getItemUnits(int itemId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/get-item-units/$itemId');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['units'] is List) {
          return (decoded['units'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error getting item units: $e');
    }
    return [];
  }
}
