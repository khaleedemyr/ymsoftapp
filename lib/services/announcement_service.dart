import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AnnouncementService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return authService.getToken();
  }

  Future<Map<String, dynamic>> _decodeMap(http.Response response) async {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Format respons tidak valid'};
    } catch (_) {
      return {'success': false, 'message': 'Gagal membaca respons (${response.statusCode})'};
    }
  }

  Future<Map<String, dynamic>> getAnnouncements({
    String? search,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (startDate != null && startDate.isNotEmpty) query['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) query['endDate'] = endDate;

      final uri = Uri.parse('$baseUrl/api/approval-app/announcements').replace(queryParameters: query);
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/announcements/create-data'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getAnnouncement(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/announcements/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<void> _attachMultipartFiles(
    http.MultipartRequest request, {
    PlatformFile? image,
    List<PlatformFile>? files,
  }) async {
    if (image != null && image.path != null && image.path!.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path!));
    }
    for (final f in (files ?? <PlatformFile>[])) {
      if (f.path != null && f.path!.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('files[]', f.path!));
      }
    }
  }

  void _attachTargets(http.MultipartRequest request, List<Map<String, dynamic>> targets) {
    for (var i = 0; i < targets.length; i++) {
      request.fields['targets[$i][type]'] = targets[i]['type']?.toString() ?? '';
      request.fields['targets[$i][id]'] = targets[i]['id']?.toString() ?? '';
    }
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    required List<Map<String, dynamic>> targets,
    PlatformFile? image,
    List<PlatformFile>? files,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/announcements'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['title'] = title;
      request.fields['content'] = content;
      _attachTargets(request, targets);
      await _attachMultipartFiles(request, image: image, files: files);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateAnnouncement({
    required int id,
    required String title,
    required String content,
    required List<Map<String, dynamic>> targets,
    PlatformFile? image,
    List<PlatformFile>? files,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/announcements/$id'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['_method'] = 'PUT';
      request.fields['title'] = title;
      request.fields['content'] = content;
      _attachTargets(request, targets);
      await _attachMultipartFiles(request, image: image, files: files);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteAnnouncement(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/announcements/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> publishAnnouncement(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/announcements/$id/publish'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}

