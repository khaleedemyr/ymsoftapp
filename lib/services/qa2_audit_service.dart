import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

/// QA2 Audits — mirror ERP `/qa2-audits` via `/api/approval-app/qa2-audits`.
class Qa2AuditService {
  static const String baseUrl = AuthService.baseUrl;
  static String get _root => '$baseUrl/api/approval-app/qa2-audits';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _jsonHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic>? _decode(http.Response r) {
    if (r.body.isEmpty) return null;
    try {
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  static String basename(String path) {
    final s = path.replaceAll('\\', '/');
    final i = s.lastIndexOf('/');
    return i < 0 ? s : s.substring(i + 1);
  }

  Future<Map<String, dynamic>> fetchIndex({
    String? search,
    String? status,
    String? outletId,
    int page = 1,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final q = <String, String>{'page': '$page'};
      if (search != null && search.isNotEmpty) q['search'] = search;
      if (status != null && status.isNotEmpty) q['status'] = status;
      if (outletId != null && outletId.isNotEmpty) q['outlet_id'] = outletId;
      final uri = Uri.parse(_root).replace(queryParameters: q);
      final res = await http.get(uri, headers: _jsonHeaders(token));
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchCreateData() async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.get(
        Uri.parse('$_root/create-data'),
        headers: _jsonHeaders(token),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchReportSummary({
    int? outletId,
    String? fromMonth,
    String? toMonth,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final q = <String, String>{};
      if (outletId != null && outletId > 0) q['outlet_id'] = '$outletId';
      if (fromMonth != null && fromMonth.isNotEmpty) q['from_month'] = fromMonth;
      if (toMonth != null && toMonth.isNotEmpty) q['to_month'] = toMonth;
      final uri = Uri.parse('$_root/report-summary').replace(queryParameters: q);
      final res = await http.get(uri, headers: _jsonHeaders(token));
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchDetail(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.get(
        Uri.parse('$_root/$id'),
        headers: _jsonHeaders(token),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createDraft(Map<String, dynamic> payload) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse(_root),
        headers: _jsonHeaders(token),
        body: jsonEncode(payload),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> saveDraft(int id, Map<String, dynamic> payload) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse('$_root/$id/save-draft'),
        headers: _jsonHeaders(token),
        body: jsonEncode(payload),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitAudit(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse('$_root/$id/submit'),
        headers: _jsonHeaders(token),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> generateShareLink(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse('$_root/$id/share-link'),
        headers: _jsonHeaders(token),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> saveCap(int id, Map<String, dynamic> payload) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse('$_root/$id/save-cap'),
        headers: _jsonHeaders(token),
        body: jsonEncode(payload),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteAudit(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.delete(
        Uri.parse('$_root/$id'),
        headers: _jsonHeaders(token),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadItemMedia(int auditId, int itemId, List<XFile> files) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final req = http.MultipartRequest('POST', Uri.parse('$_root/$auditId/items/$itemId/media'));
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';
      for (final f in files) {
        req.files.add(await http.MultipartFile.fromPath('files[]', f.path, filename: basename(f.path)));
      }
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      return _decode(resp) ?? {'success': false, 'message': 'HTTP ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteItemMedia(int auditId, int itemId, int mediaId) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.delete(
        Uri.parse('$_root/$auditId/items/$itemId/media/$mediaId'),
        headers: _jsonHeaders(token),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadCapMedia(int auditId, int capId, List<XFile> files) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final req = http.MultipartRequest('POST', Uri.parse('$_root/$auditId/caps/$capId/media'));
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';
      for (final f in files) {
        req.files.add(await http.MultipartFile.fromPath('files[]', f.path, filename: basename(f.path)));
      }
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      return _decode(resp) ?? {'success': false, 'message': 'HTTP ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitCapForApproval(int id, {
    required List<int> approverIds,
    List<Map<String, dynamic>>? caps,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.post(
        Uri.parse('$_root/$id/submit-cap'),
        headers: _jsonHeaders(token),
        body: jsonEncode({
          'approvers': approverIds,
          if (caps != null) 'caps': caps,
        }),
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
