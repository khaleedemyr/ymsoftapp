import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SerialTrackingService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _base = '$baseUrl/api/approval-app/serial-tracking';

  Future<String?> _getToken() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Future<Map<String, dynamic>?> getMeta() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final resp = await http.get(Uri.parse('$_base/meta'), headers: _headers(token));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SerialTrackingService.getMeta error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPendingOutletReceive({
    String? outletId,
    int? warehouseOutletId,
    String? doNumber,
    String? serialNumber,
    String? search,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (outletId != null && outletId.isNotEmpty) qp['outlet_id'] = outletId;
      if (warehouseOutletId != null) qp['warehouse_outlet_id'] = warehouseOutletId.toString();
      if (doNumber != null && doNumber.isNotEmpty) qp['do_number'] = doNumber;
      if (serialNumber != null && serialNumber.isNotEmpty) qp['serial_number'] = serialNumber;
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;

      final uri = Uri.parse('$_base/pending-outlet-receive').replace(queryParameters: qp);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SerialTrackingService.getPendingOutletReceive error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchDocuments({
    required String sourceType,
    String? search,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{
        'source_type': sourceType,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;

      final uri = Uri.parse('$_base/documents').replace(queryParameters: qp);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SerialTrackingService.searchDocuments error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDocumentSerials({
    required String sourceType,
    required int sourceId,
    String? search,
    int perPage = 100,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{
        'source_type': sourceType,
        'source_id': sourceId.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) qp['search'] = search;

      final uri = Uri.parse('$_base/document-serials').replace(queryParameters: qp);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SerialTrackingService.getDocumentSerials error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> lookupSerial(String serialNumber) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$_base/lookup').replace(
        queryParameters: {'serial_number': serialNumber.trim()},
      );
      final resp = await http.get(uri, headers: _headers(token));
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        return {...body, '_status': resp.statusCode};
      }
    } catch (e) {
      print('SerialTrackingService.lookupSerial error: $e');
    }
    return null;
  }
}
