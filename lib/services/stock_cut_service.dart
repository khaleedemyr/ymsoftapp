import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StockCutService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// GET daftar outlet (fallback untuk admin ketika form-data outlets kosong)
  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$baseUrl/api/approval-app/outlets');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) {
            final m = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
            return {
              'id': m['id_outlet'] ?? m['id'],
              'name': m['nama_outlet'] ?? m['name'] ?? '',
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getOutlets stock cut: $e');
      return [];
    }
  }

  /// GET form data (outlets + user) untuk form stock cut
  Future<Map<String, dynamic>?> getFormData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/form-data');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error getFormData stock cut: $e');
      return null;
    }
  }

  /// GET list log stock cut dengan pagination
  Future<Map<String, dynamic>?> getLogs({int page = 1, int perPage = 15}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/logs')
          .replace(queryParameters: {'page': page.toString(), 'per_page': perPage.toString()});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error getLogs stock cut: $e');
      return null;
    }
  }

  /// POST cek status stock cut (tanggal, id_outlet, type)
  Future<Map<String, dynamic>?> checkStatus({
    required String tanggal,
    required int idOutlet,
    String? type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/check-status');
      final body = <String, dynamic>{
        'tanggal': tanggal,
        'id_outlet': idOutlet,
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error checkStatus stock cut: $e');
      return null;
    }
  }

  /// POST cek kebutuhan stock (untuk tampilkan laporan kebutuhan vs stock)
  Future<Map<String, dynamic>?> cekKebutuhan({
    required String tanggal,
    required int idOutlet,
    String? type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/cek-kebutuhan');
      final body = <String, dynamic>{
        'tanggal': tanggal,
        'id_outlet': idOutlet,
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error cekKebutuhan stock cut: $e');
      return null;
    }
  }

  /// POST dispatch / potong stock
  Future<Map<String, dynamic>?> dispatch({
    required String tanggal,
    required int idOutlet,
    String? type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/dispatch');
      final body = <String, dynamic>{
        'tanggal': tanggal,
        'id_outlet': idOutlet,
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final decoded = response.statusCode == 200 || response.statusCode == 409 || response.statusCode == 422
          ? jsonDecode(response.body)
          : null;
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('Error dispatch stock cut: $e');
      return null;
    }
  }

  /// POST engineering - rekap item/modifier terjual (untuk form stock cut)
  Future<Map<String, dynamic>?> getEngineering({
    required String tanggal,
    required int idOutlet,
    String? type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/engineering');
      final body = <String, dynamic>{
        'tanggal': tanggal,
        'id_outlet': idOutlet,
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error getEngineering stock cut: $e');
      return null;
    }
  }

  /// GET menu cost - report cost per menu (outlet, tanggal, type)
  Future<Map<String, dynamic>?> getMenuCost({
    required int outletId,
    required String tanggal,
    String? type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final queryParams = <String, String>{
        'id_outlet': outletId.toString(),
        'tanggal': tanggal,
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/menu-cost').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('Error getMenuCost stock cut: $e');
      return null;
    }
  }

  /// DELETE rollback log stock cut
  Future<Map<String, dynamic>?> rollback(int logId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/stock-cut/$logId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      if (response.statusCode == 404) {
        return {'error': 'Log tidak ditemukan'};
      }
      return null;
    } catch (e) {
      print('Error rollback stock cut: $e');
      return null;
    }
  }
}
