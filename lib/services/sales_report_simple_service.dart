import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/sales_report_simple_models.dart';

class SalesReportSimpleService {
  static const String baseUrl = AuthService.baseUrl;

  Future<Map<String, dynamic>> getReport({
    String? outlet,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'No token found'};
      }

      final query = <String, String>{
        'date_from': dateFrom,
        'date_to': dateTo,
      };
      if (outlet != null && outlet.isNotEmpty) {
        query['outlet'] = outlet;
      }

      final uri = Uri.parse('$baseUrl/api/report/sales-simple').replace(queryParameters: query);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed load report (${response.statusCode})',
        };
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return {'success': false, 'message': 'Invalid response format'};
      }

      return {
        'success': true,
        'data': SalesReportSimpleResponse.fromJson(json),
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getDpSummary({
    required String date,
    int? outletId,
    String? kodeOutlet,
  }) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'No token found'};
      }

      final query = <String, String>{'date': date};
      if (outletId != null) {
        query['outlet_id'] = '$outletId';
      } else if (kodeOutlet != null && kodeOutlet.isNotEmpty) {
        query['kode_outlet'] = kodeOutlet;
      }

      final uri = Uri.parse('$baseUrl/api/reservations/dp-summary')
          .replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed load dp summary (${response.statusCode})',
        };
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

  Future<Map<String, dynamic>> getOutletExpenses({
    required int outletId,
    required String date,
  }) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'No token found'};
      }

      final uri = Uri.parse('$baseUrl/api/outlet-expenses').replace(
        queryParameters: {
          'outlet_id': '$outletId',
          'date': date,
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed load expenses (${response.statusCode})',
        };
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
