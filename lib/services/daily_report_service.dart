import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Daily Report — mirror ERP `/daily-report` via `/api/approval-app/daily-report`.
class DailyReportService {
  static String get _root => '${AuthService.baseUrl}/api/approval-app/daily-report';

  Future<String?> _token() => AuthService().getToken();

  Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await _token();
    if (t == null) return {};
    final h = {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    };
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  Map<String, dynamic> _decode(String body, int status) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Invalid response'};
    } catch (_) {
      return {'success': false, 'message': body.isNotEmpty ? body : 'HTTP $status'};
    }
  }

  Future<Map<String, dynamic>> getReports({
    String search = '',
    String creator = '',
    String status = 'all',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
    int perPage = 15,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final uri = Uri.parse(_root).replace(queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (creator.isNotEmpty) 'creator': creator,
      if (status.isNotEmpty) 'status': status,
      if (dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo.isNotEmpty) 'date_to': dateTo,
      'page': '$page',
      'per_page': '$perPage',
    });
    final res = await http.get(uri, headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getCreateData() async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/create-data'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getReport(int id) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$id'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getInspectData(int id) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$id/inspect'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getPostInspectionData(int id) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$id/post-inspection'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> createReport({
    required int outletId,
    required String inspectionTime,
    required int departmentId,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(
      Uri.parse(_root),
      headers: h,
      body: jsonEncode({
        'outlet_id': outletId,
        'inspection_time': inspectionTime,
        'department_id': departmentId,
      }),
    );
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> deleteReport(int id) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.delete(Uri.parse('$_root/$id'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> autoSave(int reportId, Map<String, dynamic> payload) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/auto-save'), headers: h, body: jsonEncode(payload));
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> saveArea(int reportId, Map<String, dynamic> payload) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/save-area'), headers: h, body: jsonEncode(payload));
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> skipArea(int reportId, int areaId) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(
      Uri.parse('$_root/$reportId/skip-area'),
      headers: h,
      body: jsonEncode({'area_id': areaId}),
    );
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> completeInspection(int reportId) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/complete'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> forceComplete(int reportId) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/force-complete'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> uploadDocumentation(File file) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};
    final req = http.MultipartRequest('POST', Uri.parse('$_root/upload-documentation'));
    req.headers['Authorization'] = 'Bearer $t';
    req.headers['Accept'] = 'application/json';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    return _decode(body, streamed.statusCode);
  }

  Future<Map<String, dynamic>> saveBriefing(int reportId, Map<String, dynamic> payload) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/save-briefing'), headers: h, body: jsonEncode(payload));
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> saveProductivity(int reportId, Map<String, dynamic> payload) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/save-productivity'), headers: h, body: jsonEncode(payload));
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> saveVisitTable(int reportId, Map<String, dynamic> payload) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/save-visit-table'), headers: h, body: jsonEncode(payload));
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> saveSummary(int reportId, Map<String, dynamic> payload) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(Uri.parse('$_root/$reportId/save-summary'), headers: h, body: jsonEncode(payload));
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getComments(int reportId) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$reportId/comments'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> addComment(int reportId, String comment, {int? parentId}) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(
      Uri.parse('$_root/$reportId/comments'),
      headers: h,
      body: jsonEncode({
        'comment': comment,
        if (parentId != null) 'parent_id': parentId,
      }),
    );
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> updateComment(int commentId, String comment) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.put(
      Uri.parse('$_root/comments/$commentId'),
      headers: h,
      body: jsonEncode({'comment': comment}),
    );
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.delete(Uri.parse('$_root/comments/$commentId'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getSummaryRating({
    required String startDate,
    required String endDate,
    String? region,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final uri = Uri.parse('$_root/summary-rating').replace(queryParameters: {
      'startDate': startDate,
      'endDate': endDate,
      if (region != null && region.isNotEmpty) 'region': region,
    });
    final res = await http.get(uri, headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getRegions() async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/regions'), headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getDepartmentRatings({
    required int outletId,
    required String startDate,
    required String endDate,
    String? region,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final uri = Uri.parse('$_root/department-ratings').replace(queryParameters: {
      'outletId': '$outletId',
      'startDate': startDate,
      'endDate': endDate,
      if (region != null && region.isNotEmpty) 'region': region,
    });
    final res = await http.get(uri, headers: h);
    return _decode(res.body, res.statusCode);
  }

  static String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${AuthService.storageUrl}$path';
    return '${AuthService.storageUrl}/$path';
  }
}
