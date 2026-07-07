import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/npd_plan_report_models.dart';
import 'auth_service.dart';

class NpdPlanReportService {
  static String get _prefix => '${AuthService.baseUrl}/api/approval-app/npd-plan-report';
  static String get _reportPrefix => '${AuthService.baseUrl}/api/approval-app/npd-plan-report-report';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> fetchIndex({
    int page = 1,
    String? search,
    String? month,
    int? outletId,
    String? status,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{'page': '$page', 'per_page': '15'};
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (month != null && month.isNotEmpty) params['month'] = month;
      if (outletId != null && outletId > 0) params['outlet_id'] = '$outletId';
      if (status != null && status.isNotEmpty) params['status'] = status;

      final uri = Uri.parse(_prefix).replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('NpdPlanReport fetchIndex error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCreateData({int? recordId}) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final path = recordId != null ? '$_prefix/create-data/$recordId' : '$_prefix/create-data';
      final res = await http.get(Uri.parse(path), headers: _headers(token));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('NpdPlanReport getCreateData error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(Uri.parse('$_prefix/$id'), headers: _headers(token));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('NpdPlanReport getDetail error: $e');
      return null;
    }
  }

  Future<List<NpdUserOption>> searchApprovers(String query) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final uri = Uri.parse('$_prefix/search-approvers').replace(queryParameters: {
        if (query.isNotEmpty) 'search': query,
      });
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['users'] is List) {
        return (decoded['users'] as List)
            .map((e) => NpdUserOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<NpdPendingApproval>> getPendingApprovals() async {
    try {
      final token = await _token();
      if (token == null) return [];

      final res = await http.get(Uri.parse('$_prefix/pending-approvals'), headers: _headers(token));
      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .map((e) => NpdPendingApproval.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (e) {
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

      final uri = recordId != null ? Uri.parse('$_prefix/$recordId') : Uri.parse(_prefix);
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

  Future<Map<String, dynamic>> approve({
    required int id,
    required String action,
    String? comments,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final res = await http.post(
        Uri.parse('$_prefix/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({
          'action': action,
          'comments': comments ?? '',
        }),
      );

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
        return {
          'success': false,
          'message': decoded['message']?.toString() ?? 'Gagal memproses approval.',
        };
      }
      return {'success': false, 'message': 'Gagal memproses approval.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal memproses approval: $e'};
    }
  }

  Future<Map<String, dynamic>?> getReportFilters() async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(Uri.parse('$_reportPrefix/filters'), headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('NpdPlanReport getReportFilters error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchReport({
    required String monthFrom,
    required String monthTo,
    int? outletId,
    String? status,
    String? purpose,
    String? search,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{
        'month_from': monthFrom,
        'month_to': monthTo,
      };
      if (outletId != null && outletId > 0) params['outlet_id'] = '$outletId';
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (purpose != null && purpose.isNotEmpty) params['purpose'] = purpose;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final uri = Uri.parse(_reportPrefix).replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('NpdPlanReport fetchReport error: $e');
      return null;
    }
  }

  Future<List<int>?> downloadReportExport({
    required String monthFrom,
    required String monthTo,
    int? outletId,
    String? status,
    String? purpose,
    String? search,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{
        'month_from': monthFrom,
        'month_to': monthTo,
      };
      if (outletId != null && outletId > 0) params['outlet_id'] = '$outletId';
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (purpose != null && purpose.isNotEmpty) params['purpose'] = purpose;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final uri = Uri.parse('$_reportPrefix/export').replace(queryParameters: params);
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
      );

      if (res.statusCode == 200) return res.bodyBytes;
      return null;
    } catch (e) {
      print('NpdPlanReport downloadReportExport error: $e');
      return null;
    }
  }
}
