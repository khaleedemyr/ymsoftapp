import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_tutorial_model.dart';
import 'auth_service.dart';

class VideoTutorialService {
  static String get baseUrl => '${AuthService.baseUrl}/api/approval-app';

  Future<Map<String, dynamic>> getGallery({
    String? search,
    int? groupId,
    String? sort,
    int page = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (groupId != null) {
        queryParams['group_id'] = groupId.toString();
      }
      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final uri = Uri.parse('$baseUrl/video-tutorials/gallery')
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
        return {
          'success': true,
          'videos': (data['videos']['data'] as List)
              .map((v) => VideoTutorial.fromJson(v))
              .toList(),
          'pagination': {
            'current_page': data['videos']['current_page'],
            'last_page': data['videos']['last_page'],
            'per_page': data['videos']['per_page'],
            'total': data['videos']['total'],
            'links': data['videos']['links'],
          },
          'groups': (data['groups'] as List)
              .map((g) => VideoTutorialGroup.fromJson(g))
              .toList(),
          'stats': data['stats'],
        };
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching video tutorials: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

