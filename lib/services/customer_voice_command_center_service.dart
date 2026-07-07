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
    bool showAll = false,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    String? followUpStatus,
  }) async {
    final headers = await _headers();
    final query = <String, String>{
      'page': '$page',
      // Kurangi query DB & ukuran JSON: app hanya menampilkan daftar case.
      'cases_only': '1',
    };

    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (followUpStatus != null && followUpStatus.isNotEmpty && followUpStatus != 'all') {
      query['follow_up_status'] = followUpStatus;
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
    if (showAll) {
      query['show_all'] = '1';
    }
    final df = dateFrom?.trim();
    final dt = dateTo?.trim();
    if (df != null && df.isNotEmpty) {
      query['date_from'] = df;
    }
    if (dt != null && dt.isNotEmpty) {
      query['date_to'] = dt;
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

  /// Route web `customer-voice-command-center/export-pdf` (sama query dengan halaman ERP).
  /// Membuka browser; unduhan PDF memerlukan sesi login web di perangkat.
  Uri buildExportPdfWebUri({
    String? status,
    String? severity,
    String? sourceType,
    int? outletId,
    String? search,
    bool overdueOnly = false,
    bool showAll = false,
    required String dateFrom,
    required String dateTo,
  }) {
    final query = <String, String>{
      'date_from': dateFrom,
      'date_to': dateTo,
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
    if (showAll) {
      query['show_all'] = '1';
    }
    return Uri.parse(
      '${AuthService.baseUrl}/customer-voice-command-center/export-pdf',
    ).replace(queryParameters: query);
  }

  /// Unduhan CAPA per case — route web (perlu sesi login browser).
  Uri buildCapaExportPdfWebUri(int caseId) {
    return Uri.parse(
      '${AuthService.baseUrl}/customer-voice-command-center/cases/$caseId/capa/export-pdf',
    );
  }

  /// Export Excel CAPA per case — route web (perlu sesi login browser).
  Uri buildCapaExportExcelWebUri(int caseId) {
    return Uri.parse(
      '${AuthService.baseUrl}/customer-voice-command-center/cases/$caseId/capa/export-excel',
    );
  }

  /// Arsip: Done & positif — sama query dengan modal web `archive-cases`.
  Future<CustomerVoiceArchiveResult> fetchArchiveCases({
    int page = 1,
    int perPage = 20,
    String? q,
    String? status,
    String? severity,
    String? sourceType,
    int? outletId,
    String? topic,
    int? assignedTo,
    bool overdueOnly = false,
    String? dateFrom,
    String? dateTo,
  }) async {
    final headers = await _headers();
    final query = <String, String>{
      'page': '$page',
      'per_page': '${perPage.clamp(10, 50)}',
    };

    final trimmedQ = q?.trim();
    if (trimmedQ != null && trimmedQ.isNotEmpty) {
      query['q'] = trimmedQ;
    }
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
    if (topic != null && topic.isNotEmpty && topic != 'all') {
      query['topic'] = topic;
    }
    if (assignedTo != null) {
      query['assigned_to'] = '$assignedTo';
    }
    if (overdueOnly) {
      query['overdue_only'] = '1';
    }
    final df = dateFrom?.trim();
    final dt = dateTo?.trim();
    if (df != null && df.isNotEmpty) {
      query['date_from'] = df;
    }
    if (dt != null && dt.isNotEmpty) {
      query['date_to'] = dt;
    }

    final uri = Uri.parse('$baseUrl/customer-voice-command-center/archive-cases')
        .replace(queryParameters: query);
    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(
        jsonBody['message']?.toString() ?? 'Gagal memuat arsip case',
      );
    }

    return CustomerVoiceArchiveResult.fromJson(jsonBody);
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
    List<int>? regionalUserIds,
    List<int>? notifyFollowerUserIds,
    String? followUpStatus,
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
        'follow_up_status': followUpStatus ?? 'new',
        'assigned_to': assignedTo,
        // Selaras web Index.vue: kosongkan follower lama di meta.
        'notify_follower_user_ids': notifyFollowerUserIds ?? <int>[],
        'regional_user_ids': regionalUserIds ?? <int>[],
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

  Future<List<PendingCapaVerificationItem>> getPendingCapaVerifications() async {
    final headers = await _headers();
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/pending-capa-verifications',
    );
    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(
        jsonBody['message']?.toString() ?? 'Gagal memuat verifikasi CAPA',
      );
    }

    final items = jsonBody['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .whereType<Map>()
        .map((e) => PendingCapaVerificationItem.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  /// Same shape as web `caseBriefJson` → `data.case` is `presentVoiceCaseRow`.
  Future<Map<String, dynamic>> getCaseBrief(int caseId) async {
    final headers = await _headers();
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/brief',
    );
    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(
        jsonBody['message']?.toString() ?? 'Gagal memuat ringkas case',
      );
    }

    final c = jsonBody['case'];
    if (c is! Map<String, dynamic>) {
      throw Exception('Format ringkas case tidak valid.');
    }
    return Map<String, dynamic>.from(c);
  }

  Future<String> saveCapa({
    required int caseId,
    required Map<String, dynamic> capa,
    String? capaDivision,
    List<int>? approvers,
  }) async {
    final headers = await _headers(withJsonBody: true);
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/capa',
    );

    final body = <String, dynamic>{
      'capa': capa,
      if (capaDivision != null && capaDivision.isNotEmpty)
        'capa_division': capaDivision,
      if (approvers != null && approvers.isNotEmpty) 'approvers': approvers,
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal menyimpan CAPA');
    }

    return jsonBody['message']?.toString() ?? 'Form CAPA tersimpan';
  }

  Future<List<Map<String, dynamic>>> searchCapaApprovers(String search) async {
    final headers = await _headers();
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/capa/approvers',
    ).replace(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });

    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(
        jsonBody['message']?.toString() ?? 'Gagal mencari approver',
      );
    }

    final users = jsonBody['users'];
    if (users is! List) return [];

    return users
        .whereType<Map>()
        .map((u) => u.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<Map<String, dynamic>> approveCapaDivision({
    required int caseId,
    required String division,
    required bool approved,
    String? comments,
  }) async {
    final headers = await _headers(withJsonBody: true);
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/capa/approve',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'division': division,
        'approved': approved,
        if (comments != null && comments.trim().isNotEmpty)
          'comments': comments.trim(),
      }),
    );
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal memproses approval');
    }

    final summary = jsonBody['summary'];
    if (summary is Map<String, dynamic>) {
      return summary;
    }
    if (summary is Map) {
      return summary.map((k, v) => MapEntry(k.toString(), v));
    }
    return {
      'state': 'none',
      'flows': <dynamic>[],
      'next_approver_id': null,
      'can_submit': true,
      'can_resubmit': false,
    };
  }

  Future<Map<String, dynamic>> uploadCapaEvidence({
    required int caseId,
    required String filePath,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/capa/evidence',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal mengunggah lampiran');
    }

    final item = jsonBody['item'];
    if (item is Map<String, dynamic>) {
      return Map<String, dynamic>.from(item);
    }
    if (item is Map) {
      return item.map((k, v) => MapEntry(k.toString(), v));
    }
    throw Exception('Respons lampiran tidak valid');
  }

  Future<void> deleteCapaEvidence({
    required int caseId,
    required String evidenceId,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse(
      '$baseUrl/customer-voice-command-center/cases/$caseId/capa/evidence/$evidenceId',
    );
    final response = await http.delete(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal menghapus lampiran');
    }
  }

}