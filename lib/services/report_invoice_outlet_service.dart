import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ReportInvoiceOutletService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// GET report invoice outlet dengan filter. Minimal satu filter harus diisi.
  Future<Map<String, dynamic>?> getReport({
    String? search,
    String? from,
    String? to,
    int? outletId,
    String? foMode,
    String? transactionType,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (from != null && from.isNotEmpty) queryParams['from'] = from;
      if (to != null && to.isNotEmpty) queryParams['to'] = to;
      if (outletId != null && outletId > 0) queryParams['outlet_id'] = outletId.toString();
      if (foMode != null && foMode.isNotEmpty) queryParams['fo_mode'] = foMode;
      if (transactionType != null && transactionType.isNotEmpty) queryParams['transaction_type'] = transactionType;

      final uri = Uri.parse('$baseUrl/api/approval-app/report-invoice-outlet').replace(queryParameters: queryParams);

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
      print('Error getReport report invoice outlet: $e');
      return null;
    }
  }
}
