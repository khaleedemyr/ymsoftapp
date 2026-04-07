import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class JabatanService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final q = <String, String>{};
      if (search != null && search.isNotEmpty) q['search'] = search;
      if (status != null && status.isNotEmpty) q['status'] = status;
      if (page != null) q['page'] = page.toString();
      if (perPage != null) q['per_page'] = perPage.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/jabatans').replace(
        queryParameters: q.isNotEmpty ? q : null,
      );
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('JabatanService.getList error: $e');
    }
    return null;
  }

  /// Dropdown data for create/edit: jabatans, divisis, subDivisis, levels.
  /// Returns map with success/error info so UI can show message or retry.
  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }
      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/jabatans/create-data'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      Map<String, dynamic>? decoded;
      if (resp.body.isNotEmpty) {
        try {
          decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
        } catch (_) {}
      }
      if (resp.statusCode == 200 && decoded != null) {
        return decoded;
      }
      return {
        'success': false,
        'message': decoded?['message'] ?? 'Gagal memuat data (${resp.statusCode})',
      };
    } catch (e) {
      print('JabatanService.getCreateData error: $e');
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/jabatans/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('JabatanService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> create({
    required String namaJabatan,
    int? idAtasan,
    required int idDivisi,
    required int idSubDivisi,
    required int idLevel,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final body = <String, dynamic>{
        'nama_jabatan': namaJabatan,
        'id_divisi': idDivisi,
        'id_sub_divisi': idSubDivisi,
        'id_level': idLevel,
      };
      if (idAtasan != null) body['id_atasan'] = idAtasan;
      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/jabatans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(resp.body);
      return {'success': false, 'errors': err};
    } catch (e) {
      print('JabatanService.create error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> update(
    int id, {
    required String namaJabatan,
    int? idAtasan,
    required int idDivisi,
    required int idSubDivisi,
    required int idLevel,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final body = <String, dynamic>{
        'nama_jabatan': namaJabatan,
        'id_divisi': idDivisi,
        'id_sub_divisi': idSubDivisi,
        'id_level': idLevel,
      };
      if (idAtasan != null) body['id_atasan'] = idAtasan; else body['id_atasan'] = null;
      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/jabatans/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      final err = jsonDecode(resp.body);
      return {'success': false, 'errors': err};
    } catch (e) {
      print('JabatanService.update error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleStatus(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/jabatans/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('JabatanService.toggleStatus error: $e');
    }
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/jabatans/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      return resp.statusCode == 200;
    } catch (e) {
      print('JabatanService.delete error: $e');
    }
    return false;
  }
}
