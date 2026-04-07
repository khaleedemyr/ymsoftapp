import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk Kelola Return Outlet (Head Office) - list & approve/reject return dari outlet.
class HeadOfficeReturnService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// List returns (Head Office only) dengan filter.
  Future<Map<String, dynamic>?> getList({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? status,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final q = <String, String>{};
      if (search != null && search.isNotEmpty) q['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) q['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) q['date_to'] = dateTo;
      if (status != null && status.isNotEmpty) q['status'] = status;
      if (page != null) q['page'] = page.toString();
      if (perPage != null) q['per_page'] = perPage.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/head-office-return').replace(queryParameters: q.isNotEmpty ? q : null);
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      if (response.statusCode == 200) return decoded;
      if (response.statusCode == 403)
        return {'success': false, 'message': decoded?['message'] ?? 'Akses ditolak. Menu ini hanya untuk Head Office.'};
      return null;
    } catch (e) {
      print('HeadOfficeReturnService getList: $e');
      return null;
    }
  }

  /// Detail satu return.
  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/head-office-return/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      print('HeadOfficeReturnService getDetail: $e');
      return null;
    }
  }

  /// Approve return.
  Future<Map<String, dynamic>> approve(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/head-office-return/$id/approve'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      final data = response.statusCode == 200 ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      if (response.statusCode == 200 && data != null) return data;
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      return {'success': false, 'message': decoded?['message'] ?? 'Gagal approve'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Reject return (wajib isi alasan).
  Future<Map<String, dynamic>> reject(int id, String rejectionReason) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Unauthorized'};
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/head-office-return/$id/reject'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'rejection_reason': rejectionReason}),
      );
      final data = response.statusCode == 200 ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      if (response.statusCode == 200 && data != null) return data;
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      return {'success': false, 'message': decoded?['message'] ?? 'Gagal reject'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
