import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WfhRequestService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _prefix = '$baseUrl/api/approval-app/wfh-requests';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token, {bool jsonBody = false}) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (jsonBody) 'Content-Type': 'application/json',
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
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse(_prefix).replace(queryParameters: params);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(resp.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      print('WfhRequestService.getList error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateMeta() async {
    try {
      final token = await _token();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$_prefix/create-meta'),
        headers: _headers(token),
      );
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      print('WfhRequestService.getCreateMeta error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final resp = await http.get(
        Uri.parse('$_prefix/$id/approval-details'),
        headers: _headers(token),
      );
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      print('WfhRequestService.getDetail error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> checkShift(String wfhDate) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      final uri = Uri.parse('$_prefix/check-shift').replace(
        queryParameters: {'wfh_date': wfhDate},
      );
      final resp = await http.get(uri, headers: _headers(token));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Response tidak valid'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> searchApprovers({String search = ''}) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final uri = Uri.parse('$_prefix/approvers').replace(
        queryParameters: search.trim().length >= 2 ? {'search': search.trim()} : null,
      );
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode != 200) return [];
      final decoded = jsonDecode(resp.body);
      final list = decoded is Map ? decoded['approvers'] : null;
      if (list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print('WfhRequestService.searchApprovers error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> store({
    required String wfhDate,
    required String reason,
    required List<Map<String, dynamic>> tasks,
    required List<int> approvers,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      final resp = await http.post(
        Uri.parse(_prefix),
        headers: _headers(token, jsonBody: true),
        body: jsonEncode({
          'wfh_date': wfhDate,
          'reason': reason,
          'tasks': tasks,
          'approvers': approvers,
        }),
      );

      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return {...decoded, 'success': decoded['success'] ?? true};
        }
        return {
          'success': false,
          'message': decoded['message']?.toString() ??
              _firstValidationError(decoded) ??
              'Gagal menyimpan',
        };
      }
      return {'success': false, 'message': 'Response tidak valid'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> destroy(int id) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      final resp = await http.delete(
        Uri.parse('$_prefix/$id'),
        headers: _headers(token),
      );
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          'success': decoded['success'] == true ||
              (resp.statusCode >= 200 && resp.statusCode < 300),
        };
      }
      return {'success': false, 'message': 'Response tidak valid'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  String? _firstValidationError(Map<String, dynamic> decoded) {
    final errors = decoded['errors'];
    if (errors is! Map) return null;
    for (final entry in errors.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value != null) return value.toString();
    }
    return null;
  }
}
