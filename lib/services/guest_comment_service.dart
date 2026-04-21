import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Guest Comment (OCR) — mirror ERP `/guest-comment-forms` via approval-app API.
class GuestCommentService {
  static String get _root =>
      '${AuthService.baseUrl}/api/approval-app/guest-comment-forms';

  Future<String?> _token() => AuthService().getToken();

  Future<Map<String, String>> _bearer() async {
    final t = await _token();
    if (t == null) return {};
    return {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, String>> _headersJson() async {
    final h = await _bearer();
    if (h.isEmpty) return {};
    return {...h, 'Content-Type': 'application/json'};
  }

  Map<String, dynamic> _decodeMap(String body, int status) {
    try {
      final m = jsonDecode(body);
      if (m is Map<String, dynamic>) return m;
      return {'success': false, 'message': 'Format respons tidak valid'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Gagal memparse respons ($status)',
      };
    }
  }

  Future<Map<String, dynamic>> getMeta() async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/meta'), headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    String? idOutlet,
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
    int perPage = 15,
  }) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (search.isNotEmpty) q['search'] = search;
    if (status.isNotEmpty) q['status'] = status;
    if (idOutlet != null && idOutlet.isNotEmpty) q['id_outlet'] = idOutlet;
    if (dateFrom.isNotEmpty) q['date_from'] = dateFrom;
    if (dateTo.isNotEmpty) q['date_to'] = dateTo;
    final uri = Uri.parse(_root).replace(queryParameters: q);
    final res = await http.get(uri, headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getForm(int id) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$id'), headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getGsiDashboard({
    String? month,
    String? idOutlet,
  }) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final q = <String, String>{};
    if (month != null && month.isNotEmpty) q['month'] = month;
    if (idOutlet != null && idOutlet.isNotEmpty) q['id_outlet'] = idOutlet;
    final uri = Uri.parse('$_root/gsi-dashboard').replace(queryParameters: q);
    final res = await http.get(uri, headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};
    final req = http.MultipartRequest('POST', Uri.parse(_root));
    req.headers['Authorization'] = 'Bearer $t';
    req.headers['Accept'] = 'application/json';
    req.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    return _decodeMap(body, streamed.statusCode);
  }

  Future<Map<String, dynamic>> updateForm({
    required int id,
    required Map<String, dynamic> fields,
  }) async {
    final h = await _headersJson();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.put(
      Uri.parse('$_root/$id'),
      headers: h,
      body: jsonEncode(fields),
    );
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> deleteForm(int id) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.delete(
      Uri.parse('$_root/$id'),
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
      },
    );
    return _decodeMap(res.body, res.statusCode);
  }
}
