import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/customer_voice_command_center_models.dart';
import 'auth_service.dart';

class CustomerVoiceCommandCenterService {
  static final CustomerVoiceCommandCenterService _instance =
      CustomerVoiceCommandCenterService._internal();
  factory CustomerVoiceCommandCenterService() => _instance;
  CustomerVoiceCommandCenterService._internal();

  final AuthService _authService = AuthService();
  static String get baseUrl => '${AuthService.baseUrl}/api/approval-app';

  Future<Map<String, String>> _headers({bool withJsonBody = false}) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (withJsonBody) 'Content-Type': 'application/json',
    };
  }

  Future<CustomerVoiceDashboard> getDashboard({
    String? status,
    String? severity,
    String? sourceType,
    int? outletId,
    String? search,
    bool overdueOnly = false,
    int page = 1,
  }) async {
    final headers = await _headers();
    final query = <String, String>{
      'page': '$page',
    };

    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (severity != null && severity.isNotEmpty && severity != 'all') {
      query['severity'] = severity;
    }
    if (sourceType != null && sourceType.isNotEmpty && sourceType != 'all') {
      query['source_type'] = sourceType;
    }
    if (outletId != null) {
      query['id_outlet'] = '$outletId';
    }
    if (search != null && search.trim().isNotEmpty) {
      query['q'] = search.trim();
    }
    if (overdueOnly) {
      query['overdue_only'] = '1';
    }

    final uri = Uri.parse('$baseUrl/customer-voice-command-center').replace(
      queryParameters: query,
    );
    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(
        jsonBody['message'] ?? 'Gagal memuat Customer Voice Command Center',
      );
    }

    return CustomerVoiceDashboard.fromJson(
      jsonBody['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<String> syncData() async {
    final headers = await _headers(withJsonBody: true);
    final uri = Uri.parse('$baseUrl/customer-voice-command-center/sync');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal sinkronisasi data');
    }

    return jsonBody['message']?.toString() ?? 'Sinkronisasi selesai';
  }

  Future<String> updateCase({
    required int caseId,
    required String status,
    int? assignedTo,
  }) async {
    final headers = await _headers(withJsonBody: true);
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/update',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'status': status,
        'assigned_to': assignedTo,
      }),
    );
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal memperbarui case');
    }

    return jsonBody['message']?.toString() ?? 'Case diperbarui';
  }

  Future<String> addNote({
    required int caseId,
    required String note,
  }) async {
    final headers = await _headers(withJsonBody: true);
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/note',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'note': note.trim(),
      }),
    );
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal menyimpan catatan');
    }

    return jsonBody['message']?.toString() ?? 'Catatan tersimpan';
  }
}