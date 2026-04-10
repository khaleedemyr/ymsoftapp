import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Ticketing — mirror ERP `/tickets` via `/api/approval-app/tickets`.
class TicketService {
  static String get _root => '${AuthService.baseUrl}/api/approval-app/tickets';

  Future<String?> _token() async {
    return AuthService().getToken();
  }

  Future<Map<String, String>> _bearer() async {
    final t = await _token();
    if (t == null) return {};
    return {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    };
  }

  /// Form options: categories, priorities, statuses, divisions, outlets, assignable_users.
  Future<Map<String, dynamic>> getFormOptions() async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/form-options'), headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getTickets({
    String search = '',
    String status = 'all',
    String priority = 'all',
    String category = 'all',
    String division = 'all',
    String outlet = 'all',
    String paymentStatus = 'all',
    String issueType = 'all',
    int page = 1,
    int perPage = 15,
  }) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final uri = Uri.parse(_root).replace(queryParameters: {
      'search': search,
      'status': status,
      'priority': priority == 'all' ? 'all' : priority,
      'category': category == 'all' ? 'all' : category,
      'division': division == 'all' ? 'all' : division,
      'outlet': outlet == 'all' ? 'all' : outlet,
      'payment_status': paymentStatus,
      'issue_type': issueType,
      'page': '$page',
      'per_page': '$perPage',
    });
    final res = await http.get(uri, headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getTicket(int id) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$id'), headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
    required int categoryId,
    required int priorityId,
    required int divisiId,
    required int outletId,
    List<File>? attachmentFiles,
  }) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};

    if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
      final req = http.MultipartRequest('POST', Uri.parse(_root));
      req.headers['Authorization'] = 'Bearer $t';
      req.headers['Accept'] = 'application/json';
      req.fields['title'] = title;
      req.fields['description'] = description;
      req.fields['category_id'] = '$categoryId';
      req.fields['priority_id'] = '$priorityId';
      req.fields['divisi_id'] = '$divisiId';
      req.fields['outlet_id'] = '$outletId';
      for (final f in attachmentFiles) {
        req.files.add(await http.MultipartFile.fromPath('attachments[]', f.path));
      }
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      return _decodeMap(body, streamed.statusCode);
    }

    final res = await http.post(
      Uri.parse(_root),
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'category_id': categoryId,
        'priority_id': priorityId,
        'divisi_id': divisiId,
        'outlet_id': outletId,
      }),
    );
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> updateTicket({
    required int id,
    required String title,
    required String description,
    required int categoryId,
    required int priorityId,
    required int statusId,
    required int divisiId,
    required int outletId,
  }) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.put(
      Uri.parse('$_root/$id'),
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'category_id': categoryId,
        'priority_id': priorityId,
        'status_id': statusId,
        'divisi_id': divisiId,
        'outlet_id': outletId,
      }),
    );
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> updateStatus(int ticketId, int statusId) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.patch(
      Uri.parse('$_root/$ticketId/status'),
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status_id': statusId}),
    );
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> deleteTicket(int id) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.delete(Uri.parse('$_root/$id'), headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> assignTeam(
    int ticketId, {
    required List<int> userIds,
    int? primaryUserId,
  }) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.post(
      Uri.parse('$_root/$ticketId/assign-team'),
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_ids': userIds,
        if (primaryUserId != null) 'primary_user_id': primaryUserId,
      }),
    );
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> getComments(int ticketId) async {
    final h = await _bearer();
    if (h.isEmpty) return {'success': false, 'message': 'Sesi habis'};
    final res = await http.get(Uri.parse('$_root/$ticketId/comments'), headers: h);
    return _decodeMap(res.body, res.statusCode);
  }

  Future<Map<String, dynamic>> addComment(
    int ticketId, {
    String? comment,
    List<File>? files,
  }) async {
    final t = await _token();
    if (t == null) return {'success': false, 'message': 'Sesi habis'};

    final hasFiles = files != null && files.isNotEmpty;
    final text = comment?.trim() ?? '';
    if (text.isEmpty && !hasFiles) {
      return {'success': false, 'message': 'Isi komentar atau lampirkan file'};
    }

    if (hasFiles) {
      final req = http.MultipartRequest('POST', Uri.parse('$_root/$ticketId/comments'));
      req.headers['Authorization'] = 'Bearer $t';
      req.headers['Accept'] = 'application/json';
      if (text.isNotEmpty) req.fields['comment'] = text;
      for (final f in files) {
        req.files.add(await http.MultipartFile.fromPath('attachments[]', f.path));
      }
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      return _decodeMap(body, streamed.statusCode);
    }

    final res = await http.post(
      Uri.parse('$_root/$ticketId/comments'),
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'comment': text}),
    );
    return _decodeMap(res.body, res.statusCode);
  }

  static Map<String, dynamic> _decodeMap(String body, int status) {
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) return d;
      return {'success': false, 'message': 'Format respons tidak valid'};
    } catch (_) {
      return {'success': false, 'message': 'Gagal memparse respons ($status)'};
    }
  }

  static String attachmentUrl(String filePath) {
    final p = filePath.replaceFirst(RegExp(r'^/storage/'), '');
    return '${AuthService.storageUrl}/storage/$p';
  }
}
