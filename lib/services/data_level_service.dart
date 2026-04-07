import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DataLevelService {
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
      final uri = Uri.parse('$baseUrl/api/approval-app/data-levels').replace(
        queryParameters: q.isNotEmpty ? q : null,
      );
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('DataLevelService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/approval-app/data-levels/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('DataLevelService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> create({
    required String namaLevel,
    required String nilaiLevel,
    required int nilaiPublicHoliday,
    required int nilaiDasarPotonganBpjs,
    required int nilaiPoint,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final body = {
        'nama_level': namaLevel,
        'nilai_level': nilaiLevel,
        'nilai_public_holiday': nilaiPublicHoliday,
        'nilai_dasar_potongan_bpjs': nilaiDasarPotonganBpjs,
        'nilai_point': nilaiPoint,
      };
      final resp = await http.post(
        Uri.parse('$baseUrl/api/approval-app/data-levels'),
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
      print('DataLevelService.create error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> update(
    int id, {
    required String namaLevel,
    required String nilaiLevel,
    required int nilaiPublicHoliday,
    required int nilaiDasarPotonganBpjs,
    required int nilaiPoint,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final body = {
        'nama_level': namaLevel,
        'nilai_level': nilaiLevel,
        'nilai_public_holiday': nilaiPublicHoliday,
        'nilai_dasar_potongan_bpjs': nilaiDasarPotonganBpjs,
        'nilai_point': nilaiPoint,
      };
      final resp = await http.put(
        Uri.parse('$baseUrl/api/approval-app/data-levels/$id'),
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
      print('DataLevelService.update error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleStatus(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final resp = await http.patch(
        Uri.parse('$baseUrl/api/approval-app/data-levels/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('DataLevelService.toggleStatus error: $e');
    }
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final resp = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/data-levels/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      return resp.statusCode == 200;
    } catch (e) {
      print('DataLevelService.delete error: $e');
    }
    return false;
  }
}
