import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

/// Mirror web `MarketingVisitChecklistController` — approval-app JSON + multipart foto per baris.
class MarketingVisitChecklistService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _token() async => AuthService().getToken();

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

  Future<Map<String, dynamic>> fetchIndex({String? outletId, String? visitDate}) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final q = <String, String>{};
      if (outletId != null && outletId.isNotEmpty) q['outlet_id'] = outletId;
      if (visitDate != null && visitDate.isNotEmpty) q['visit_date'] = visitDate;
      final uri = Uri.parse('$baseUrl/api/approval-app/marketing-visit-checklist').replace(queryParameters: q.isEmpty ? null : q);
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
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
        Uri.parse('$baseUrl/api/approval-app/marketing-visit-checklist/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
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
        Uri.parse('$baseUrl/api/approval-app/marketing-visit-checklist/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitMultipart({
    required bool isEdit,
    int? checklistId,
    required int outletId,
    required String visitDateYmd,
    required List<Map<String, dynamic>> itemsPayload,
    required List<List<XFile>> photosPerIndex,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final uri = Uri.parse(
        isEdit
            ? '$baseUrl/api/approval-app/marketing-visit-checklist/$checklistId/update'
            : '$baseUrl/api/approval-app/marketing-visit-checklist',
      );
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      req.fields['outlet_id'] = '$outletId';
      req.fields['visit_date'] = visitDateYmd;

      for (var i = 0; i < itemsPayload.length; i++) {
        final it = itemsPayload[i];
        final sid = it['id'];
        if (sid != null) req.fields['items[$i][id]'] = '$sid';
        req.fields['items[$i][no]'] = '${it['no']}';
        req.fields['items[$i][category]'] = '${it['category']}';
        req.fields['items[$i][checklist_point]'] = '${it['checklist_point']}';
        req.fields['items[$i][checked]'] = it['checked'] == true ? '1' : '0';
        req.fields['items[$i][actual_condition]'] = '${it['actual_condition'] ?? ''}';
        req.fields['items[$i][action]'] = '${it['action'] ?? ''}';
        req.fields['items[$i][remarks]'] = '${it['remarks'] ?? ''}';

        final pics = i < photosPerIndex.length ? photosPerIndex[i] : const <XFile>[];
        for (final x in pics) {
          req.files.add(await http.MultipartFile.fromPath(
            'items[$i][photos][]',
            x.path,
            filename: basename(x.path),
          ));
        }
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final decoded = _decode(resp);
      if (decoded != null) return decoded;
      return {'success': false, 'message': 'HTTP ${resp.statusCode}', 'body': resp.body};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> delete(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/marketing-visit-checklist/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return _decode(res) ?? {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
