import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ItemEngineeringService {
  static const String baseUrl = AuthService.baseUrl;

  Future<Map<String, dynamic>> getReport({
    String? outletCode,
    int? regionId,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'No token found'};
      }

      final query = <String, String>{};
      if (outletCode != null && outletCode.isNotEmpty) query['outlet'] = outletCode;
      if (regionId != null && regionId > 0) query['region'] = '$regionId';
      if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/approval-app/report/item-engineering')
          .replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Failed load report (${response.statusCode})'};
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return {'success': false, 'message': 'Invalid response format'};
      }

      return {'success': true, 'data': json};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}

