import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

/// Mirror web `LogbookDriverController` — approval-app JSON + multipart foto per baris.
class LogbookDriverService {
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

  Future<Map<String, dynamic>> fetchIndex({
    String? search,
    String? outletId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final q = <String, String>{'page': '$page', 'per_page': '20'};
      if (search != null && search.isNotEmpty) q['search'] = search;
      if (outletId != null && outletId.isNotEmpty) q['outlet_id'] = outletId;
      if (dateFrom != null && dateFrom.isNotEmpty) q['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) q['date_to'] = dateTo;
      final uri = Uri.parse('$baseUrl/api/approval-app/logbook-drivers')
          .replace(queryParameters: q);
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
        Uri.parse('$baseUrl/api/approval-app/logbook-drivers/create-data'),
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
        Uri.parse('$baseUrl/api/approval-app/logbook-drivers/$id'),
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
    int? recordId,
    required int outletId,
    String? notes,
    required List<Map<String, dynamic>> items,
    required List<XFile?> photos,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};

      final url = isEdit
          ? '$baseUrl/api/approval-app/logbook-drivers/$recordId'
          : '$baseUrl/api/approval-app/logbook-drivers';
      final req = http.MultipartRequest('POST', Uri.parse(url));
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';

      req.fields['outlet_id'] = '$outletId';
      if (notes != null && notes.isNotEmpty) req.fields['notes'] = notes;

      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        if (it['id'] != null) req.fields['items[$i][id]'] = '${it['id']}';
        final t = it['log_time']?.toString() ?? '';
        if (t.isNotEmpty) req.fields['items[$i][log_time]'] = t;
        req.fields['items[$i][description]'] = '${it['description'] ?? ''}';
        req.fields['items[$i][keep_photo]'] =
            (it['keep_photo'] == true) ? '1' : '0';

        final photo = i < photos.length ? photos[i] : null;
        if (photo != null) {
          req.files.add(await http.MultipartFile.fromPath(
            'items[$i][photo]',
            photo.path,
            filename: basename(photo.path),
          ));
        }
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      return _decode(resp) ??
          {'success': false, 'message': 'HTTP ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> delete(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'No token'};
      final res = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/logbook-drivers/$id'),
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
