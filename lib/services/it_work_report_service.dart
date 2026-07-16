import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// IT Work Report — mirror ERP `/it-work-reports` via `/api/approval-app/it-work-reports`.
class ItWorkReportService {
  static String get _root => '${AuthService.baseUrl}/api/approval-app/it-work-reports';

  Future<String?> _token() => AuthService().getToken();

  Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await _token();
    if (t == null) return {};
    final h = <String, String>{
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
      return {
        'success': false,
        'message': body.isNotEmpty ? body : 'HTTP $status',
      };
    }
  }

  Future<Map<String, dynamic>> getReports({
    String search = '',
    String outletId = '',
    String sourceType = 'all',
    String status = 'all',
    String dateFrom = '',
    String dateTo = '',
    String scope = '',
    int page = 1,
    int perPage = 15,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final uri = Uri.parse(_root).replace(queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (outletId.isNotEmpty) 'outlet_id': outletId,
      if (sourceType.isNotEmpty) 'source_type': sourceType,
      if (status.isNotEmpty) 'status': status,
      if (dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo.isNotEmpty) 'date_to': dateTo,
      if (scope.isNotEmpty) 'scope': scope,
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

  Future<Map<String, dynamic>> searchTickets({
    required String q,
    int? outletId,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis', 'data': []};
    final uri = Uri.parse('$_root/search-tickets').replace(queryParameters: {
      'q': q,
      if (outletId != null) 'outlet_id': '$outletId',
    });
    final res = await http.get(uri, headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final uri = Uri.parse('$_root/reverse-geocode').replace(queryParameters: {
      'lat': '$lat',
      'lng': '$lng',
    });
    final res = await http.get(uri, headers: h);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> saveReport({
    int? id,
    required Map<String, String> fields,
    required List<Map<String, dynamic>> items,
    required List<File> waScreenshots,
    required List<List<File>> itemEvidenceFiles,
    required List<List<Map<String, dynamic>>> itemEvidenceMetas,
    List<int> removeEvidenceIds = const [],
    required bool submit,
  }) async {
    final token = await _token();
    if (token == null) return {'success': false, 'message': 'Sesi habis'};

    final uri = Uri.parse(id == null ? _root : '$_root/$id');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';

    fields.forEach((k, v) {
      if (v.isNotEmpty) req.fields[k] = v;
    });
    req.fields['submit'] = submit ? '1' : '0';

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      item.forEach((k, v) {
        if (k == 'scopes' && v is List) {
          for (var s = 0; s < v.length; s++) {
            req.fields['items[$i][scopes][$s]'] = '${v[s]}';
          }
        } else if (v != null && '$v'.isNotEmpty) {
          req.fields['items[$i][$k]'] = '$v';
        }
      });
    }

    for (var i = 0; i < removeEvidenceIds.length; i++) {
      req.fields['remove_evidence_ids[$i]'] = '${removeEvidenceIds[i]}';
    }

    for (final f in waScreenshots) {
      req.files.add(await http.MultipartFile.fromPath('wa_screenshots[]', f.path));
    }

    for (var i = 0; i < itemEvidenceFiles.length; i++) {
      final files = itemEvidenceFiles[i];
      final metas = i < itemEvidenceMetas.length ? itemEvidenceMetas[i] : <Map<String, dynamic>>[];
      for (var j = 0; j < files.length; j++) {
        req.files.add(await http.MultipartFile.fromPath(
          'item_evidences[$i][]',
          files[j].path,
        ));
        if (j < metas.length) {
          final m = metas[j];
          m.forEach((k, v) {
            if (v != null && '$v'.isNotEmpty) {
              req.fields['item_evidence_meta[$i][$j][$k]'] = '$v';
            }
          });
        }
      }
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> deleteReport(int id) async {
    final h = await _headers();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.delete(Uri.parse('$_root/$id'), headers: h);
    return _decode(res.body, res.statusCode);
  }
}
