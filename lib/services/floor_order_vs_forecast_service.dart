import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Mirror web `FloorOrderVsForecastReportController` + `GET .../api/approval-app/floor-order-vs-forecast`.
class FloorOrderVsForecastService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _token() async {
    final auth = AuthService();
    return auth.getToken();
  }

  Future<Map<String, dynamic>?> fetchReport({
    required int outletId,
    required String monthYm,
  }) async {
    final t = await _token();
    if (t == null) return null;
    final uri = Uri.parse('$baseUrl/api/approval-app/floor-order-vs-forecast').replace(
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
}
