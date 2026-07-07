import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EmployeeCoachingService {
  static String get _prefix => '${AuthService.baseUrl}/api/approval-app/employee-coaching';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> getList({
    String? search,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
      };
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse(_prefix).replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('EmployeeCoaching getList error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData({int? recordId}) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final path = recordId != null ? '$_prefix/create-data/$recordId' : '$_prefix/create-data';
      final res = await http.get(Uri.parse(path), headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('EmployeeCoaching getCreateData error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(Uri.parse('$_prefix/$id'), headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('EmployeeCoaching getDetail error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchEmployees(String query) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final uri = Uri.parse('$_prefix/search-employees').replace(queryParameters: {
        if (query.isNotEmpty) 'q': query,
      });
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['employees'] is List) {
          return (decoded['employees'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('EmployeeCoaching searchEmployees error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> payload,
    int? recordId,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final uri = recordId != null
          ? Uri.parse('$_prefix/$recordId')
          : Uri.parse(_prefix);
      final res = recordId != null
          ? await http.put(uri, headers: _headers(token), body: jsonEncode(payload))
          : await http.post(uri, headers: _headers(token), body: jsonEncode(payload));

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
        return {
          'success': false,
          'message': decoded['message']?.toString() ?? 'Gagal menyimpan.',
          'errors': decoded['errors'],
        };
      }
      return {'success': false, 'message': 'Gagal menyimpan.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menyimpan: $e'};
    }
  }

  Future<Map<String, dynamic>> delete(int id) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final res = await http.delete(Uri.parse('$_prefix/$id'), headers: _headers(token));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Gagal menghapus.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghapus: $e'};
    }
  }
}
