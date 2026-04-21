import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// API mirror web `OutletRevenueTargetController` (approval-app prefix).
class OutletRevenueTargetService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _token() async {
    final auth = AuthService();
    return auth.getToken();
  }

  Future<Map<String, dynamic>?> fetchIndex({
    required int outletId,
    required String monthYm,
  }) async {
    final t = await _token();
    if (t == null) return null;
    final uri = Uri.parse('$baseUrl/api/approval-app/outlet-revenue-targets').replace(
      queryParameters: {
        'outlet_id': '$outletId',
        'month': monthYm,
      },
    );
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  Future<Map<String, dynamic>?> save({
    required int outletId,
    required String monthYm,
    required double monthlyTarget,
    required List<Map<String, dynamic>> forecasts,
  }) async {
    final t = await _token();
    if (t == null) return null;
    final uri = Uri.parse('$baseUrl/api/approval-app/outlet-revenue-targets');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'outlet_id': outletId,
        'month': monthYm,
        'monthly_target': monthlyTarget,
        'forecasts': forecasts,
      }),
    );
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {'success': false, 'message': 'HTTP ${resp.statusCode}'};
  }

  Future<Map<String, dynamic>?> suggest({
    required int outletId,
    required String monthYm,
    required double monthlyTarget,
  }) async {
    final t = await _token();
    if (t == null) return null;
    final uri = Uri.parse('$baseUrl/api/approval-app/outlet-revenue-targets/suggest');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'outlet_id': outletId,
        'month': monthYm,
        'monthly_target': monthlyTarget,
      }),
    );
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> generateHistorical({
    required int outletId,
    required String endMonthYm,
    required int monthsBack,
  }) async {
    final t = await _token();
    if (t == null) return null;
    final uri = Uri.parse('$baseUrl/api/approval-app/outlet-revenue-targets/generate-historical');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $t',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'outlet_id': outletId,
        'end_month': endMonthYm,
        'months_back': monthsBack,
      }),
    );
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> historicalMonthDetail({
    required int outletId,
    required String monthYm,
  }) async {
    final t = await _token();
    if (t == null) return null;
    final uri = Uri.parse('$baseUrl/api/approval-app/outlet-revenue-targets/historical-month-detail').replace(
      queryParameters: {
        'outlet_id': '$outletId',
        'month': monthYm,
      },
    );
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCompanyHolidays() async {
    final t = await _token();
    if (t == null) return [];
    final uri = Uri.parse('$baseUrl/api/approval-app/company-holidays');
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }
}
