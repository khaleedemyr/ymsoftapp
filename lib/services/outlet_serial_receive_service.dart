import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OutletSerialReceiveService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  Map<String, String> _headersJson(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>?> getList({
    String? outletId,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{};
      if (outletId != null && outletId.isNotEmpty) qp['outlet_id'] = outletId;
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
      if (page != null) qp['page'] = page.toString();
      if (perPage != null) qp['per_page'] = perPage.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-serial-receive').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('OutletSerialReceiveService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-serial-receive/$id');
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('OutletSerialReceiveService.getDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> validateSerial(String serialNumber) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-serial-receive/validate-serial');
      final resp = await http.post(
        uri,
        headers: _headersJson(token),
        body: jsonEncode({'serial_number': serialNumber}),
      );
      return jsonDecode(resp.body);
    } catch (e) {
      print('OutletSerialReceiveService.validateSerial error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> store({
    required List<Map<String, dynamic>> serials,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-serial-receive');
      final serialPayload = serials.map((s) =>
        <String, dynamic>{'serial_id': s['id'], 'serial_number': s['serial_number']}
      ).toList();
      final resp = await http.post(
        uri,
        headers: _headersJson(token),
        body: jsonEncode({
          'serials': serialPayload,
          'notes': notes,
        }),
      );
      return jsonDecode(resp.body);
    } catch (e) {
      print('OutletSerialReceiveService.store error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/outlet-serial-receive/$id');
      final resp = await http.delete(uri, headers: _headers(token));
      return jsonDecode(resp.body);
    } catch (e) {
      print('OutletSerialReceiveService.delete error: $e');
    }
    return null;
  }
}
