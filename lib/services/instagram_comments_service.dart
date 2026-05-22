import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/instagram_comments_models.dart';
import 'auth_service.dart';

class InstagramCommentsService {
  static String get _root => '${AuthService.baseUrl}/api/approval-app/instagram-comments';

  static String _extractError(Map<String, dynamic> body, String fallback) {
    final msg = body['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    return fallback;
  }

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await AuthService().getToken();
    final h = <String, String>{
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
    };
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  Future<IgCommentsBootstrap> fetchBootstrap() async {
    final uri = Uri.parse('$_root/bootstrap');
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(_extractError(body, 'Gagal memuat akun komentar'));
    }
    if (body['success'] != true) {
      throw Exception(_extractError(body, 'Gagal memuat akun komentar'));
    }
    final data = body['data'];
    if (data is! Map) {
      throw Exception('Format data akun komentar tidak valid');
    }
    return IgCommentsBootstrap.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<IgCommentPost>> fetchPosts({
    required String platform,
    required String accountId,
    int limit = 25,
  }) async {
    final Uri uri;
    if (platform == 'facebook') {
      uri = Uri.parse('$_root/facebook/$accountId/posts').replace(
        queryParameters: {'limit': '$limit'},
      );
    } else {
      uri = Uri.parse('$_root/$accountId/media').replace(
        queryParameters: {'limit': '$limit'},
      );
    }

    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal memuat post');
    }

    final media = body['media'] as List? ?? [];
    return media
        .map((e) => IgCommentPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<IgCommentItem>> fetchComments({
    required String platform,
    required String accountId,
    required String postId,
    int limit = 50,
  }) async {
    final Uri uri;
    if (platform == 'facebook') {
      uri = Uri.parse('$_root/facebook/$accountId/posts/$postId/comments').replace(
        queryParameters: {'limit': '$limit'},
      );
    } else {
      uri = Uri.parse('$_root/$accountId/media/$postId/comments').replace(
        queryParameters: {'limit': '$limit'},
      );
    }

    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal memuat komentar');
    }

    final comments = body['comments'] as List? ?? [];
    return comments
        .map((e) => IgCommentItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> replyToComment({
    required String platform,
    required String accountId,
    required String commentId,
    required String message,
  }) async {
    final Uri uri;
    if (platform == 'facebook') {
      uri = Uri.parse('$_root/facebook/$accountId/comments/$commentId/reply');
    } else {
      uri = Uri.parse('$_root/$accountId/comments/$commentId/reply');
    }

    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'message': message}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal membalas komentar');
    }
  }
}
