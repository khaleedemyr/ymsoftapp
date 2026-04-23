import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../models/shared_document_models.dart';
import 'auth_service.dart';

class SharedDocumentService {
  static final SharedDocumentService _instance =
      SharedDocumentService._internal();
  factory SharedDocumentService() => _instance;
  SharedDocumentService._internal();

  final AuthService _authService = AuthService();
  static String get baseUrl => '${AuthService.baseUrl}/api/approval-app';

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<SharedDocumentListResponse> getDocuments({
    int? folderId,
    String? search,
  }) async {
    final headers = await _headers();
    final query = <String, String>{};

    if (folderId != null) {
      query['folder_id'] = folderId.toString();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse('$baseUrl/shared-documents').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal memuat dokumen bersama');
    }

    return SharedDocumentListResponse.fromJson(
      jsonBody['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<SharedDocumentItem> getDocumentDetail(int documentId) async {
    final headers = await _headers();
    final uri = Uri.parse('$baseUrl/shared-documents/$documentId');

    final response = await http.get(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal memuat detail dokumen');
    }

    return SharedDocumentItem.fromJson(
      jsonBody['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<Uint8List> downloadDocumentBytes(
    int documentId, {
    bool preview = false,
  }) async {
    final headers = await _headers();
    final endpoint = preview ? 'preview' : 'download';
    final uri = Uri.parse('$baseUrl/shared-documents/$documentId/$endpoint');

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      String message = 'Gagal mengunduh dokumen';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message']?.toString() ?? message;
      } catch (_) {
        // Keep fallback message when response is binary/non-JSON.
      }
      throw Exception(message);
    }

    return response.bodyBytes;
  }

  Future<String> deleteDocument(int documentId) async {
    final headers = await _headers();
    final uri = Uri.parse('$baseUrl/shared-documents/$documentId');

    final response = await http.delete(uri, headers: headers);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal menghapus dokumen');
    }

    return jsonBody['message']?.toString() ?? 'Dokumen berhasil dihapus';
  }

  Future<String> moveDocument({
    required int documentId,
    int? targetFolderId,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    final uri = Uri.parse('$baseUrl/shared-documents/$documentId/move');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'target_folder_id': targetFolderId}),
    );

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal memindahkan dokumen');
    }

    return jsonBody['message']?.toString() ?? 'Dokumen berhasil dipindahkan';
  }

  Future<String> createFolder({
    required String name,
    int? parentId,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    final uri = Uri.parse('$baseUrl/shared-documents/folders');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'parent_id': parentId,
      }),
    );

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal membuat folder');
    }

    return jsonBody['message']?.toString() ?? 'Folder berhasil dibuat';
  }

  Future<String> uploadDocument({
    required String filePath,
    required String title,
    String? description,
    int? folderId,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/shared-documents'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['title'] = title;
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }
    if (folderId != null) {
      request.fields['folder_id'] = folderId.toString();
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    Map<String, dynamic> jsonBody = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode != 200 || jsonBody['success'] != true) {
      throw Exception(jsonBody['message'] ?? 'Gagal upload dokumen');
    }

    return jsonBody['message']?.toString() ?? 'Dokumen berhasil diupload';
  }
}
