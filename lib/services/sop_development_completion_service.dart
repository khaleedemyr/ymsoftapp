import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/sop_development_completion_models.dart';
import 'auth_service.dart';

class SopDevelopmentCompletionService {
  static String get _prefix => '${AuthService.baseUrl}/api/approval-app/sop-development-completion';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> fetchIndex({
    int page = 1,
    String? search,
    String? status,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{'page': '$page', 'per_page': '15'};
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (status != null && status.isNotEmpty && status != 'all') params['status'] = status;

      final uri = Uri.parse(_prefix).replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('SOP fetchIndex error: $e');
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
      print('SOP getDetail error: $e');
      return null;
    }
  }

  Future<List<SopUserOption>> searchApprovers(String query) async {
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
            .map((e) => SopUserOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<SopPendingApproval>> getPendingApprovals() async {
    try {
      final token = await _token();
      if (token == null) return [];

      final res = await http.get(Uri.parse('$_prefix/pending-approvals'), headers: _headers(token));
      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .map((e) => SopPendingApproval.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> save({
    required String title,
    required String dueDate,
    String? description,
    int? recordId,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final payload = {
        'title': title,
        'due_date': dueDate,
        'description': description,
      };

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

  Future<Map<String, dynamic>> submitForApproval({
    required int id,
    required String filePath,
    required List<int> approverIds,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final request = http.MultipartRequest('POST', Uri.parse('$_prefix/$id/submit-approval'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      for (var i = 0; i < approverIds.length; i++) {
        request.fields['approvers[$i]'] = approverIds[i].toString();
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
        return {
          'success': false,
          'message': decoded['message']?.toString() ?? 'Gagal mengajukan approval.',
          'errors': decoded['errors'],
        };
      }
      return {'success': false, 'message': 'Gagal mengajukan approval.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal mengajukan approval: $e'};
    }
  }

  Future<Map<String, dynamic>> approve({
    required int id,
    String? notes,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final res = await http.post(
        Uri.parse('$_prefix/$id/approve'),
        headers: _headers(token),
        body: jsonEncode({'approval_notes': notes}),
      );

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
        return {'success': false, 'message': decoded['message']?.toString() ?? 'Gagal menyetujui.'};
      }
      return {'success': false, 'message': 'Gagal menyetujui.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menyetujui: $e'};
    }
  }

  Future<Map<String, dynamic>> reject({
    required int id,
    required String notes,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final res = await http.post(
        Uri.parse('$_prefix/$id/reject'),
        headers: _headers(token),
        body: jsonEncode({'approval_notes': notes}),
      );

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
        return {'success': false, 'message': decoded['message']?.toString() ?? 'Gagal menolak.'};
      }
      return {'success': false, 'message': 'Gagal menolak.'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal menolak: $e'};
    }
  }

  Future<Uint8List?> downloadFile(int id) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$_prefix/$id/file'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
      );
      if (res.statusCode == 200) return res.bodyBytes;
      return null;
    } catch (e) {
      print('SOP downloadFile error: $e');
      return null;
    }
  }
}
