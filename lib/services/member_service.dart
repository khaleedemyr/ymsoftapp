import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class MemberService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Format respons tidak valid'};
    } catch (_) {
      return {'success': false, 'message': 'Gagal membaca respons (${response.statusCode})'};
    }
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _getToken();
    if (token == null) return {};
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> getMembers({
    String? search,
    String? status,
    String? pointBalance,
    String? sort,
    String? direction,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': '$page',
        'per_page': '$perPage',
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (pointBalance != null && pointBalance.isNotEmpty) query['point_balance'] = pointBalance;
      if (sort != null && sort.isNotEmpty) query['sort'] = sort;
      if (direction != null && direction.isNotEmpty) query['direction'] = direction;

      final uri = Uri.parse('$baseUrl/api/approval-app/members').replace(queryParameters: query);
      final response = await http.get(uri, headers: headers);
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getCreateData() async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/members/create-data'),
        headers: headers,
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getMember(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/members/$id'),
        headers: headers,
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createMember(Map<String, dynamic> payload) async {
    try {
      final headers = await _headers(json: true);
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/members'),
        headers: headers,
        body: jsonEncode(payload),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateMember(int id, Map<String, dynamic> payload) async {
    try {
      final headers = await _headers(json: true);
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/members/$id'),
        headers: headers,
        body: jsonEncode(payload),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteMember(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/members/$id'),
        headers: headers,
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleStatus(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/members/$id/toggle-status'),
        headers: headers,
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyEmail(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/members/$id/verify-email'),
        headers: headers,
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyAllUnverified() async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/members/verify-all-unverified'),
        headers: headers,
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required int id,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final headers = await _headers(json: true);
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/members/$id/change-password'),
        headers: headers,
        body: jsonEncode({
          'password': password,
          'password_confirmation': confirmPassword,
        }),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTransactions(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/members/$id/transactions'),
        headers: headers,
      );
      final decoded = await _decodeResponse(response);
      if (decoded['status'] == 'success') {
        return {'success': true, ...decoded};
      }
      return {'success': false, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPreferences(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/members/$id/preferences'),
        headers: headers,
      );
      final decoded = await _decodeResponse(response);
      if (decoded['status'] == 'success') {
        return {'success': true, ...decoded};
      }
      return {'success': false, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getVoucherTimeline(int id) async {
    try {
      final headers = await _headers();
      if (headers.isEmpty) return {'success': false, 'message': 'No authentication token'};
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/members/$id/voucher-timeline'),
        headers: headers,
      );
      final decoded = await _decodeResponse(response);
      if (decoded['status'] == 'success') {
        return {'success': true, ...decoded};
      }
      return {'success': false, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
