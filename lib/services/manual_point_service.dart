import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ManualPointService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>> _decodeMap(http.Response response) async {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {
        'success': false,
        'message': 'Format respons tidak valid',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Gagal membaca respons (${response.statusCode})',
      };
    }
  }

  Future<Map<String, dynamic>> getList({
    String? search,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/approval-app/manual-point').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/manual-point/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> searchMembers(String query) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/manual-point/search-members').replace(
        queryParameters: {'search': query},
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> create({
    required int memberId,
    required String paidNumber,
    required int outletId,
    required double transactionAmount,
    required String transactionDate,
    required String channel,
    required bool isGiftVoucherPayment,
    required bool isEcommerceOrder,
    required String description,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/manual-point'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'member_id': memberId,
          'paid_number': paidNumber,
          'outlet_id': outletId,
          'transaction_amount': transactionAmount,
          'transaction_date': transactionDate,
          'channel': channel,
          'is_gift_voucher_payment': isGiftVoucherPayment,
          'is_ecommerce_order': isEcommerceOrder,
          'description': description,
        }),
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/manual-point/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteManualPoint(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/manual-point/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
