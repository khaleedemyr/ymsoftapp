import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class KasbonReportService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    return AuthService().getToken();
  }

  Future<Map<String, dynamic>?> fetchReport({
    required String status,
    String? divisionId,
    String? outletId,
    String? dateFrom,
    String? dateTo,
    String? search,
    int perPage = 15,
    int page = 1,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return null;

      final q = <String, String>{
        'status': status,
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      if (divisionId != null && divisionId.isNotEmpty) q['division_id'] = divisionId;
      if (outletId != null && outletId.isNotEmpty) q['outlet_id'] = outletId;
      if (dateFrom != null && dateFrom.isNotEmpty) q['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) q['date_to'] = dateTo;
      if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();

      final uri = Uri.parse('$baseUrl/api/approval-app/report-kasbon').replace(queryParameters: q);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>?> downloadExport({
    required String status,
    String? divisionId,
    String? outletId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return null;

      final q = <String, String>{'status': status};
      if (divisionId != null && divisionId.isNotEmpty) q['division_id'] = divisionId;
      if (outletId != null && outletId.isNotEmpty) q['outlet_id'] = outletId;
      if (dateFrom != null && dateFrom.isNotEmpty) q['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) q['date_to'] = dateTo;
      if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();

      final uri = Uri.parse('$baseUrl/api/approval-app/report-kasbon/export').replace(queryParameters: q);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> postInstallment(
    int id, {
    required String paidAt,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Belum login'};
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/report-kasbon/$id/installment');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paid_at': paidAt,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      );

      final bodyRaw = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      final body = bodyRaw is Map<String, dynamic>
          ? bodyRaw
          : (bodyRaw is Map ? Map<String, dynamic>.from(bodyRaw) : <String, dynamic>{});

      if (body['success'] == true) {
        return {'success': true, 'message': body['message']?.toString() ?? ''};
      }
      if (body['success'] == false && body['message'] != null) {
        return {'success': false, 'message': body['message'].toString()};
      }
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message']?.toString() ?? ''};
      }
      return {'success': false, 'message': _extractErrorMessage(body)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> postReverseInstallment(int id, {String? notes}) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Belum login'};
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/report-kasbon/$id/installment/reverse');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      );

      final bodyRaw = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      final body = bodyRaw is Map<String, dynamic>
          ? bodyRaw
          : (bodyRaw is Map ? Map<String, dynamic>.from(bodyRaw) : <String, dynamic>{});

      if (body['success'] == true) {
        return {'success': true, 'message': body['message']?.toString() ?? ''};
      }
      if (body['success'] == false && body['message'] != null) {
        return {'success': false, 'message': body['message'].toString()};
      }
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message']?.toString() ?? ''};
      }
      return {'success': false, 'message': _extractErrorMessage(body)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  String _extractErrorMessage(Map<String, dynamic> body) {
    final m = body['message'];
    if (m != null && m.toString().isNotEmpty) return m.toString();
    final err = body['errors'];
    if (err is Map) {
      for (final v in err.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v != null) return v.toString();
      }
    }
    return 'Permintaan ditolak';
  }
}