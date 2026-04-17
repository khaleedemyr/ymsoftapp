import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class GoogleReviewService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return authService.getToken();
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

  Future<Map<String, dynamic>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/google-review/outlets'),
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

  Future<Map<String, dynamic>> fetchApifyReviews({
    required String placeId,
    required int maxReviews,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/google-review/fetch-apify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'place_id': placeId,
          'max_reviews': maxReviews,
          'date_from': dateFrom,
          'date_to': dateTo,
        }),
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getApifyItems({
    required String datasetId,
    int page = 1,
    int perPage = 20,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'dataset_id': datasetId,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/approval-app/google-review/apify/items').replace(
        queryParameters: query,
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

  Future<Map<String, dynamic>> createAiReport({
    required String source,
    String? datasetId,
    String? placeId,
    int? outletId,
    String? outletName,
    Map<String, dynamic>? place,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final body = <String, dynamic>{
        'source': source,
        'dataset_id': datasetId,
        'place_id': placeId,
        'id_outlet': outletId,
        'nama_outlet': outletName,
        'place': place,
        'date_from': dateFrom,
        'date_to': dateTo,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/google-review/ai/reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getAiReports({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/google-review/ai/reports').replace(
        queryParameters: {
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
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

  Future<Map<String, dynamic>> getAiReportDetail(
    int id, {
    String? severity,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (severity != null && severity.isNotEmpty) {
        query['severity'] = severity;
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/google-review/ai/reports/$id').replace(
        queryParameters: query,
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

  Future<Map<String, dynamic>> getAiReportStatus(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/google-review/ai/reports/$id/status'),
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

