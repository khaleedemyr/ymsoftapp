import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/just_academy_models.dart';
import 'auth_service.dart';

class JustAcademyService {
  static String get _prefix => '${AuthService.baseUrl}/api/approval-app/just-academy';
  static const Duration _timeout = Duration(seconds: 30);

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<http.Response> _get(Uri uri, Map<String, String> headers) {
    return http.get(uri, headers: headers).timeout(_timeout);
  }

  Future<http.Response> _post(Uri uri, Map<String, String> headers, {Object? body}) {
    return http.post(uri, headers: headers, body: body).timeout(_timeout);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<List<JaHomeSchedule>> fetchHomeSchedules() async {
    try {
      final token = await _token();
      if (token == null) return [];

      final res = await _get(Uri.parse('$_prefix/home-schedules'), _headers(token));
      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != true) return [];

      final data = decoded['data'];
      if (data is! Map) return [];

      final participant = data['participant'];
      if (participant is! List) return [];

      return participant
          .map((e) => JaHomeSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('JA fetchHomeSchedules error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchMySchedules({
    String tab = 'upcoming',
    int page = 1,
  }) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final uri = Uri.parse('$_prefix/my-schedules').replace(queryParameters: {
        'tab': tab,
        'page': '$page',
      });
      final res = await _get(uri, _headers(token));
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      print('JA fetchMySchedules error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchScheduleDetail(int scheduleId) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await _get(
        Uri.parse('$_prefix/schedules/$scheduleId'),
        _headers(token),
      );
      if (res.statusCode != 200) {
        debugPrint('JA scheduleDetail status=${res.statusCode} body=${res.body}');
        return null;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return _asMap(decoded['data']);
      }
      return null;
    } catch (e) {
      print('JA fetchScheduleDetail error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchMaterials(int scheduleId) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await _get(
        Uri.parse('$_prefix/schedules/$scheduleId/materials'),
        _headers(token),
      );
      if (res.statusCode != 200) {
        debugPrint('JA materials status=${res.statusCode} body=${res.body}');
        return null;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return decoded;
      }
      return null;
    } catch (e) {
      print('JA fetchMaterials error: $e');
      return null;
    }
  }

  Future<bool> completeMaterial(int scheduleId, int materialId) async {
    try {
      final token = await _token();
      if (token == null) return false;

      final res = await _post(
        Uri.parse('$_prefix/schedules/$scheduleId/materials/$materialId/complete'),
        _headers(token),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('JA completeMaterial error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> startQuiz(int scheduleId, int quizId) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await _post(
        Uri.parse('$_prefix/schedules/$scheduleId/quizzes/$quizId/start'),
        _headers(token),
      );
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return decoded['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('JA startQuiz error: $e');
      return null;
    }
  }

  Future<bool> syncQuizProgress(int scheduleId, int quizId, int currentIndex) async {
    try {
      final token = await _token();
      if (token == null) return false;

      final res = await _post(
        Uri.parse('$_prefix/schedules/$scheduleId/quizzes/$quizId/progress'),
        _headers(token),
        body: jsonEncode({'current_index': currentIndex}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('JA syncQuizProgress error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> submitQuiz(
    int scheduleId,
    int quizId,
    Map<String, dynamic> answers,
  ) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await _post(
        Uri.parse('$_prefix/schedules/$scheduleId/quizzes/$quizId/submit'),
        _headers(token),
        body: jsonEncode({'answers': answers}),
      );
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return decoded['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('JA submitQuiz error: $e');
      return null;
    }
  }

  Future<bool> checkIn(int scheduleId, String qrToken) async {
    try {
      final token = await _token();
      if (token == null) return false;

      final res = await _post(
        Uri.parse('$_prefix/check-in'),
        _headers(token),
        body: jsonEncode({
          'schedule_id': scheduleId,
          'qr_token': qrToken,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('JA checkIn error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchFeedback(int scheduleId) async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await _get(
        Uri.parse('$_prefix/schedules/$scheduleId/feedback'),
        _headers(token),
      );
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return _asMap(decoded['data']);
      }
      return null;
    } catch (e) {
      print('JA fetchFeedback error: $e');
      return null;
    }
  }

  Future<bool> submitFeedback({
    required int scheduleId,
    required int rating,
    String? comment,
    int? trainerId,
  }) async {
    try {
      final token = await _token();
      if (token == null) return false;

      final body = <String, dynamic>{
        'rating': rating,
        'comment': comment,
      };
      if (trainerId != null) body['trainer_id'] = trainerId;

      final res = await _post(
        Uri.parse('$_prefix/schedules/$scheduleId/feedback'),
        _headers(token),
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('JA submitFeedback error: $e');
      return false;
    }
  }
}
