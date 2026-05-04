import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

import 'auth_service.dart';

class GoogleReviewService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _prefix = '$baseUrl/api/approval-app/google-review';

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

  Future<Map<String, dynamic>> _authorizedGet(Uri uri) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'No authentication token'};
    }
    try {
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

  Future<Map<String, dynamic>> _authorizedPostJson(Uri uri, Map<String, dynamic> body) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'No authentication token'};
    }
    try {
      final response = await http.post(
        uri,
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

  Future<Map<String, dynamic>> _authorizedPutJson(Uri uri, Map<String, dynamic> body) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'No authentication token'};
    }
    try {
      final response = await http.put(
        uri,
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

  Future<Map<String, dynamic>> _authorizedDelete(Uri uri) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'No authentication token'};
    }
    try {
      final response = await http.delete(
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

  Future<Map<String, dynamic>> getWorkspace() async {
    return _authorizedGet(Uri.parse('$_prefix/workspace'));
  }

  Future<Map<String, dynamic>> getOutlets() async {
    return _authorizedGet(Uri.parse('$_prefix/outlets'));
  }

  Future<Map<String, dynamic>> fetchPlacesReviews({required String placeId}) async {
    return _authorizedPostJson(Uri.parse('$_prefix/fetch'), {'place_id': placeId});
  }

  Future<Map<String, dynamic>> fetchApifyReviews({
    required String placeId,
    required int maxReviews,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _authorizedPostJson(Uri.parse('$_prefix/fetch-apify'), {
      'place_id': placeId,
      'max_reviews': maxReviews,
      'date_from': dateFrom,
      'date_to': dateTo,
    });
  }

  Future<Map<String, dynamic>> getApifyItems({
    required String datasetId,
    int page = 1,
    int perPage = 20,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, String>{
      'dataset_id': datasetId,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;

    final uri = Uri.parse('$_prefix/apify/items').replace(queryParameters: query);
    return _authorizedGet(uri);
  }

  Future<Map<String, dynamic>> getScrapedReviews() async {
    return _authorizedGet(Uri.parse('$_prefix/scraped-reviews'));
  }

  Future<Map<String, dynamic>> dashboardDrilldown({
    required String channel,
    required String metric,
    required String key,
    int days = 30,
    int limit = 120,
    int page = 1,
    String q = '',
    String sort = 'date_desc',
  }) async {
    final query = <String, String>{
      'channel': channel,
      'metric': metric,
      'key': key,
      'days': days.toString(),
      'limit': limit.toString(),
      'page': page.toString(),
      'sort': sort,
    };
    if (q.isNotEmpty) query['q'] = q;
    final uri = Uri.parse('$_prefix/dashboard/drilldown').replace(queryParameters: query);
    return _authorizedGet(uri);
  }

  Future<Map<String, dynamic>> downloadBinaryGet(Uri uri, {required String filename}) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'error': 'No authentication token'};
    }
    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
      );
      if (response.statusCode >= 400) {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
        };
      }
      final safeName = filename.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${Directory.systemTemp.path}/ym_${stamp}_$safeName');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
      return {'success': true, 'path': file.path};
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> exportApifyCsv({
    required String datasetId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, String>{'dataset_id': datasetId};
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    final uri = Uri.parse('$_prefix/apify/export').replace(queryParameters: query);
    return downloadBinaryGet(uri, filename: 'google-reviews.csv');
  }

  Future<Map<String, dynamic>> exportDashboardDrilldownCsv({
    required String channel,
    required String metric,
    required String key,
    int days = 30,
    String q = '',
    String sort = 'date_desc',
  }) async {
    final query = <String, String>{
      'channel': channel,
      'metric': metric,
      'key': key,
      'days': days.toString(),
      'sort': sort,
    };
    if (q.isNotEmpty) query['q'] = q;
    final uri = Uri.parse('$_prefix/dashboard/drilldown/export').replace(queryParameters: query);
    return downloadBinaryGet(uri, filename: 'dashboard-drilldown-$channel-$metric.csv');
  }

  Future<Map<String, dynamic>> exportAiReportExcel(int reportId) async {
    final uri = Uri.parse('$_prefix/ai/reports/$reportId/export');
    return downloadBinaryGet(uri, filename: 'google-review-ai-$reportId.xlsx');
  }

  Future<Map<String, dynamic>> getManualReviews({
    int page = 1,
    int perPage = 20,
    int? idOutlet,
    String? q,
    int? isActive,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (idOutlet != null) query['id_outlet'] = idOutlet.toString();
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (isActive != null) query['is_active'] = isActive.toString();
    final uri = Uri.parse('$_prefix/manual').replace(queryParameters: query);
    return _authorizedGet(uri);
  }

  Future<Map<String, dynamic>> createManualReview(Map<String, dynamic> payload) async {
    return _authorizedPostJson(Uri.parse('$_prefix/manual'), payload);
  }

  Future<Map<String, dynamic>> updateManualReview(int id, Map<String, dynamic> payload) async {
    return _authorizedPutJson(Uri.parse('$_prefix/manual/$id'), payload);
  }

  Future<Map<String, dynamic>> deleteManualReview(int id) async {
    return _authorizedDelete(Uri.parse('$_prefix/manual/$id'));
  }

  Future<Map<String, dynamic>> instagramStats() async {
    return _authorizedGet(Uri.parse('$_prefix/instagram/stats'));
  }

  Future<Map<String, dynamic>> instagramRecentPosts({int limit = 30}) async {
    final uri = Uri.parse('$_prefix/instagram/recent-posts').replace(
      queryParameters: {'limit': limit.toString()},
    );
    return _authorizedGet(uri);
  }

  Future<Map<String, dynamic>> instagramSyncPosts({
    required List<String> profileKeys,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _authorizedPostJson(Uri.parse('$_prefix/instagram/sync-posts'), {
      'profile_keys': profileKeys,
      'date_from': dateFrom,
      'date_to': dateTo,
    });
  }

  Future<Map<String, dynamic>> instagramSyncComments({
    required List<String> profileKeys,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _authorizedPostJson(Uri.parse('$_prefix/instagram/sync-comments'), {
      'profile_keys': profileKeys,
      'date_from': dateFrom,
      'date_to': dateTo,
    });
  }

  Future<Map<String, dynamic>> instagramProgress(String operationId) async {
    final uri = Uri.parse('$_prefix/instagram/progress').replace(
      queryParameters: {'operation_id': operationId},
    );
    return _authorizedGet(uri);
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
    List<Map<String, dynamic>>? reviews,
    List<int>? manualReviewIds,
    List<String>? profileKeys,
  }) async {
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
    if (reviews != null) body['reviews'] = reviews;
    if (manualReviewIds != null) body['manual_review_ids'] = manualReviewIds;
    if (profileKeys != null) body['profile_keys'] = profileKeys;

    return _authorizedPostJson(Uri.parse('$_prefix/ai/reports'), body);
  }

  Future<Map<String, dynamic>> getAiReports({
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = Uri.parse('$_prefix/ai/reports').replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );
    return _authorizedGet(uri);
  }

  Future<Map<String, dynamic>> getAiReportDetail(
    int id, {
    String? severity,
    int page = 1,
    int perPage = 50,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (severity != null && severity.isNotEmpty) {
      query['severity'] = severity;
    }

    final uri = Uri.parse('$_prefix/ai/reports/$id').replace(queryParameters: query);
    return _authorizedGet(uri);
  }

  Future<Map<String, dynamic>> getAiReportStatus(int id) async {
    return _authorizedGet(Uri.parse('$_prefix/ai/reports/$id/status'));
  }
}
