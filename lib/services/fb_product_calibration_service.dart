import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FbProductCalibrationService {
  static String get _prefix => '${AuthService.baseUrl}/api/approval-app/fb-product-calibration';
  static String get _reportPrefix => '${AuthService.baseUrl}/api/approval-app/fb-product-calibration-report';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>?> getCalendar({required int year, required int month}) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final uri = Uri.parse(_prefix).replace(queryParameters: {
        'year': '$year',
        'month': '$month',
      });
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('FbCalibration getCalendar error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCompanyHolidays() async {
    try {
      final token = await _token();
      if (token == null) return [];

      final uri = Uri.parse('${AuthService.baseUrl}/api/approval-app/company-holidays');
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      print('FbCalibration fetchHolidays error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCreateData({int? recordId}) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final path = recordId != null ? '$_prefix/create-data/$recordId' : '$_prefix/create-data';
      final res = await http.get(Uri.parse(path), headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('FbCalibration getCreateData error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(Uri.parse('$_prefix/$id'), headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('FbCalibration getDetail error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getConductData(int id) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(Uri.parse('$_prefix/$id/conduct-data'), headers: _headers(token));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
        return decoded;
      }
      return null;
    } catch (e) {
      print('FbCalibration getConductData error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchConductors(String query) async {
    return _searchUsers('search-conductors', query);
  }

  Future<List<Map<String, dynamic>>> searchParticipants(String query) async {
    return _searchUsers('search-participants', query);
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String endpoint, String query) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final uri = Uri.parse('$_prefix/$endpoint').replace(queryParameters: {
        if (query.isNotEmpty) 'q': query,
      });
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['users'] is List) {
          return (decoded['users'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchProducts({
    required int outletId,
    String query = '',
    List<int> excludeIds = const [],
  }) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final params = <String, String>{'outlet_id': '$outletId'};
      if (query.isNotEmpty) params['q'] = query;
      if (excludeIds.isNotEmpty) {
        for (var i = 0; i < excludeIds.length; i++) {
          params['exclude_ids[$i]'] = '${excludeIds[i]}';
        }
      }

      final uri = Uri.parse('$_prefix/search-products').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['items'] is List) {
          return (decoded['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> saveSchedule({
    required Map<String, dynamic> payload,
    int? recordId,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

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

  Future<Map<String, dynamic>> saveConduct({
    required int recordId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis, silakan login ulang.'};
      }

      final res = await http.post(
        Uri.parse('$_prefix/$recordId/conduct'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );

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

  Future<Map<String, dynamic>?> getReportFilters() async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(Uri.parse('$_reportPrefix/filters'), headers: _headers(token));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e) {
      print('FbCalibration getReportFilters error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchReport({
    required String dateFrom,
    required String dateTo,
    int? outletId,
    String? employeeSearch,
    String? mode,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{
        'date_from': dateFrom,
        'date_to': dateTo,
      };
      if (outletId != null && outletId > 0) params['outlet_id'] = '$outletId';
      if (employeeSearch != null && employeeSearch.trim().isNotEmpty) {
        params['employee_search'] = employeeSearch.trim();
      }
      if (mode != null && mode.isNotEmpty) params['mode'] = mode;

      final uri = Uri.parse(_reportPrefix).replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('FbCalibration fetchReport error: $e');
      return null;
    }
  }

  Future<List<int>?> downloadReportExport({
    required String dateFrom,
    required String dateTo,
    int? outletId,
    String? employeeSearch,
    String? mode,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final params = <String, String>{
        'date_from': dateFrom,
        'date_to': dateTo,
      };
      if (outletId != null && outletId > 0) params['outlet_id'] = '$outletId';
      if (employeeSearch != null && employeeSearch.trim().isNotEmpty) {
        params['employee_search'] = employeeSearch.trim();
      }
      if (mode != null && mode.isNotEmpty) params['mode'] = mode;

      final uri = Uri.parse('$_reportPrefix/export').replace(queryParameters: params);
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
      );

      if (res.statusCode == 200) return res.bodyBytes;
      return null;
    } catch (e) {
      print('FbCalibration downloadReportExport error: $e');
      return null;
    }
  }
}
