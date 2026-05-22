import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/omnichannel_inbox_models.dart';
import 'auth_service.dart';

class OmnichannelInboxService {
  static String get _root => '${AuthService.baseUrl}/api/approval-app/omnichannel-inbox';

  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = AuthService.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
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

  /// Poll inbox (8s di web) — trigger sync IG/Messenger + refresh daftar/pesan tanpa reload penuh.
  Future<OmniInboxPollResult> fetchPoll({
    String inbox = 'all',
    String? leadStage,
    String? channel,
    int? conversationId,
  }) async {
    final q = <String, String>{'inbox': inbox};
    if (leadStage != null && leadStage.isNotEmpty) q['lead_stage'] = leadStage;
    if (channel != null && channel.isNotEmpty && channel != 'all') {
      q['channel'] = channel;
    }
    if (conversationId != null && conversationId > 0) {
      q['conversation'] = '$conversationId';
    }
    final uri = Uri.parse('$_root/poll').replace(queryParameters: q);
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal memuat inbox');
    }
    return OmniInboxPollResult.fromJson(body);
  }

  Future<OmniInboxBootstrap> fetchBootstrap({
    String inbox = 'all',
    String? leadStage,
    String? channel,
  }) async {
    final q = <String, String>{'inbox': inbox};
    if (leadStage != null && leadStage.isNotEmpty) q['lead_stage'] = leadStage;
    if (channel != null && channel.isNotEmpty && channel != 'all') {
      q['channel'] = channel;
    }
    final uri = Uri.parse('$_root/bootstrap').replace(queryParameters: q);
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat inbox');
    }
    return OmniInboxBootstrap.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<({OmniConversation conversation, List<OmniMessage> messages})> fetchMessages(int conversationId) async {
    final uri = Uri.parse('$_root/conversations/$conversationId/messages');
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal memuat pesan');
    }
    final conv = OmniConversation.fromJson(Map<String, dynamic>.from(body['conversation'] as Map));
    final msgs = (body['messages'] as List? ?? [])
        .map((e) => OmniMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (conversation: conv, messages: msgs);
  }

  Future<OmniConversation> updateConversation(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_root/conversations/$id');
    final res = await http.patch(uri, headers: await _authHeaders(), body: jsonEncode(payload));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    }
    return OmniConversation.fromJson(Map<String, dynamic>.from(body['conversation'] as Map));
  }

  Future<OmniMessage> sendMessage(
    int conversationId, {
    String? body,
    String? filePath,
    String? fileName,
  }) async {
    return _sendMultipart(
      '$_root/conversations/$conversationId/messages',
      body: body,
      filePath: filePath,
      fileName: fileName,
    );
  }

  Future<OmniMessage> sendInternalNote(
    int conversationId, {
    String? body,
    String? filePath,
    String? fileName,
  }) async {
    return _sendMultipart(
      '$_root/conversations/$conversationId/internal-notes',
      body: body,
      filePath: filePath,
      fileName: fileName,
    );
  }

  Future<OmniMessage> _sendMultipart(
    String url, {
    String? body,
    String? filePath,
    String? fileName,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(await _authHeaders(json: false));
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }
    if (filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(
        'attachment',
        filePath,
        filename: fileName ?? filePath.split(Platform.pathSeparator).last,
      ));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(decoded['message'] ?? 'Gagal mengirim');
    }
    return OmniMessage.fromJson(Map<String, dynamic>.from(decoded['message'] as Map));
  }

  /// Unduh/cache lampiran dari server (untuk pesan [Gambar] / [Lampiran] tanpa URL).
  Future<({String? url, OmniMessage? message})> fetchMessageMedia(int messageId) async {
    final uri = Uri.parse('$_root/messages/$messageId/media');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) {
      return (url: null, message: null);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    OmniMessage? updated;
    final msgRaw = body['message'];
    if (msgRaw is Map) {
      updated = OmniMessage.fromJson(Map<String, dynamic>.from(msgRaw));
    }
    final rawUrl = (body['media_url'] as String?) ?? updated?.mediaUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      return (url: null, message: updated);
    }
    return (url: resolveMediaUrl(rawUrl), message: updated);
  }

  Future<OmniConversation> pauseAutomation(int conversationId) async {
    final uri = Uri.parse('$_root/conversations/$conversationId/pause-automation');
    final res = await http.post(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal menghentikan otomasi');
    }
    return OmniConversation.fromJson(Map<String, dynamic>.from(body['conversation'] as Map));
  }
}
