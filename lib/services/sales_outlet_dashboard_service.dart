import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_outlet_dashboard_model.dart';
import 'auth_service.dart';

class SalesOutletDashboardService {
  static String get baseUrl => '${AuthService.baseUrl}/api/approval-app';

  Future<Map<String, dynamic>> getDashboard({
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final queryParams = <String, String>{};
      if (dateFrom != null && dateFrom.isNotEmpty) {
        queryParams['date_from'] = dateFrom;
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        queryParams['date_to'] = dateTo;
      }

      final uri = Uri.parse('$baseUrl/sales-outlet-dashboard')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': SalesOutletDashboardData.fromJson(data['data']),
            'filters': data['filters'],
          };
        } else {
          throw Exception(data['error'] ?? 'Failed to load dashboard');
        }
      } else {
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching sales outlet dashboard: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getHolidays({
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/sales-outlet-dashboard/holidays')
          .replace(queryParameters: {
        'date_from': dateFrom,
        'date_to': dateTo,
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        throw Exception('Failed to load holidays: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching holidays: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getOutletDetailsByDate({
    required String date,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/sales-outlet-dashboard/outlet-details')
          .replace(queryParameters: {
        'date': date,
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to load outlet details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching outlet details by date: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getOutletDailyRevenue({
    required String outletCode,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final uri = Uri.parse('$baseUrl/sales-outlet-dashboard/outlet-daily-revenue')
          .replace(queryParameters: {
        'outlet_code': outletCode,
        'date_from': dateFrom,
        'date_to': dateTo,
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to load outlet daily revenue: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching outlet daily revenue: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

