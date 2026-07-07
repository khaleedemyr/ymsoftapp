import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/asset_disposal_models.dart';

class AssetDisposalService {
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

  Future<Map<String, dynamic>?> getDisposals({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? status,
    String? type,
    int? outletId,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final params = <String, String>{'page': page.toString(), 'per_page': perPage.toString()};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (type != null && type.isNotEmpty) params['type'] = type;
      if (outletId != null) params['outlet_id'] = outletId.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-disposals').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getDisposals: $e');
      return null;
    }
  }

  Future<AssetDisposal?> getDisposal(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-disposals/$id'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        return AssetDisposal.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getDisposal: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/asset-disposals/create-data'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getCreateData: $e');
      return null;
    }
  }

  Future<List<dynamic>> searchItems(
    String query, {
    required int ownerOutletId,
    required int warehouseOutletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/items/search-for-asset-transfer')
          .replace(queryParameters: {
        'q': query,
        'owner_outlet_id': ownerOutletId.toString(),
        'warehouse_outlet_id': warehouseOutletId.toString(),
      });
      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error searchItems: $e');
      return [];
    }
  }

  Future<List<dynamic>> searchApprovers(String query) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/api/approval-app/asset-disposal/approvers')
          .replace(queryParameters: {'search': query});
      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['users'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error searchApprovers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> uploadPhoto(File file) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/asset-disposals/upload-photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('photo', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error uploadPhoto: $e');
      return null;
    }
  }

  Future<bool> deletePhoto(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-disposals/photo/$id'),
        headers: _headers(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deletePhoto: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> createDisposal(Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-disposals'),
        headers: _headers(token),
        body: jsonEncode(data),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error createDisposal: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> approve(int id, String action, {String? comments}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/asset-disposals/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({'action': action, 'comments': comments ?? ''}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error approve: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> destroy(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/asset-disposals/$id'),
        headers: _headers(token),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error destroy: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
