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
  Future<OmniConversationsMoreResult> fetchConversationsMore({
    String inbox = 'all',
    String? leadStage,
    String? channel,
    required int beforeId,
  }) async {
    final q = <String, String>{
      'inbox': inbox,
      'before_id': '$beforeId',
    };
    if (leadStage != null && leadStage.isNotEmpty) q['lead_stage'] = leadStage;
    if (channel != null && channel.isNotEmpty && channel != 'all') {
      q['channel'] = channel;
    }
    final uri = Uri.parse('$_root/conversations-more').replace(queryParameters: q);
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal memuat chat lebih lama');
    }
    return OmniConversationsMoreResult.fromJson(body);
  }

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

  Future<OmniMessagesPageResult> fetchMessages(
    int conversationId, {
    int limit = 40,
    int? beforeId,
    bool noEnrich = false,
  }) async {
    final q = <String, String>{
      'limit': '$limit',
      if (beforeId != null) 'before_id': '$beforeId',
      if (noEnrich) 'no_enrich': '1',
    };
    final uri = Uri.parse('$_root/conversations/$conversationId/messages').replace(queryParameters: q);
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Gagal memuat pesan');
    }
    final conv = OmniConversation.fromJson(Map<String, dynamic>.from(body['conversation'] as Map));
    final msgs = (body['messages'] as List? ?? [])
        .map((e) => OmniMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return OmniMessagesPageResult(
      conversation: conv,
      messages: msgs,
      hasMoreOlder: body['has_more_older'] == true,
      oldestMessageId: (body['oldest_message_id'] as num?)?.toInt(),
    );
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

  static const int maxAttachments = 10;

  Future<OmniConversation?> escalateToCustomerVoice(int conversationId) async {
    final uri = Uri.parse('$_root/conversations/$conversationId/escalate-to-voice');
    final res = await http.post(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal eskalasi ke Customer Voice');
    }
    final convRaw = body['conversation'];
    if (convRaw is Map) {
      return OmniConversation.fromJson(Map<String, dynamic>.from(convRaw));
    }
    return null;
  }

  Future<List<OmniMessage>> sendMessage(
    int conversationId, {
    String? body,
    List<String> filePaths = const [],
    List<String>? fileNames,
  }) async {
    return _sendMultipart(
      '$_root/conversations/$conversationId/messages',
      body: body,
      filePaths: filePaths,
      fileNames: fileNames,
    );
  }

  Future<OmniInternalNoteResult> sendInternalNote(
    int conversationId, {
    String? body,
    List<String> filePaths = const [],
    List<String>? fileNames,
    List<int> mentionedUserIds = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_root/conversations/$conversationId/internal-notes'),
    );
    request.headers.addAll(await _authHeaders(json: false));
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }
    for (final id in mentionedUserIds) {
      request.fields['mentioned_user_ids[]'] = '$id';
    }
    await _attachFiles(request, filePaths, fileNames);
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(decoded['message'] ?? 'Gagal mengirim');
    }
    final messages = _parseMessagesFromResponse(decoded);
    OmniConversation? conv;
    final convRaw = decoded['conversation'];
    if (convRaw is Map) {
      conv = OmniConversation.fromJson(Map<String, dynamic>.from(convRaw));
    }
    return OmniInternalNoteResult(
      messages: messages,
      message: messages.isNotEmpty ? messages.last : throw Exception('Gagal mengirim'),
      conversation: conv,
    );
  }

  /// Perbaiki ejaan / grammar via AI (sama endpoint web `ai-assist`).
  Future<String> aiAssistGrammar(String text) async {
    final uri = Uri.parse('$_root/ai-assist');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'action': 'grammar', 'text': text}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memperbaiki ejaan (HTTP ${res.statusCode})');
    }
    final corrected = body['text'];
    if (corrected is! String || corrected.trim().isEmpty) {
      throw Exception('AI tidak mengembalikan teks perbaikan.');
    }
    return corrected.trim();
  }

  Future<List<OmniMessage>> _sendMultipart(
    String url, {
    String? body,
    List<String> filePaths = const [],
    List<String>? fileNames,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(await _authHeaders(json: false));
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }
    await _attachFiles(request, filePaths, fileNames);
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(decoded['message'] ?? 'Gagal mengirim');
    }
    return _parseMessagesFromResponse(decoded);
  }

  Future<void> _attachFiles(
    http.MultipartRequest request,
    List<String> filePaths,
    List<String>? fileNames,
  ) async {
    final paths = filePaths.where((p) => p.isNotEmpty).take(maxAttachments).toList();
    if (paths.isEmpty) return;

    if (paths.length == 1) {
      final path = paths.first;
      request.files.add(await http.MultipartFile.fromPath(
        'attachment',
        path,
        filename: _fileNameAt(fileNames, 0, path),
      ));
      return;
    }

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      request.files.add(await http.MultipartFile.fromPath(
        'attachments[]',
        path,
        filename: _fileNameAt(fileNames, i, path),
      ));
    }
  }

  String _fileNameAt(List<String>? fileNames, int index, String path) {
    if (fileNames != null && index < fileNames.length && fileNames[index].isNotEmpty) {
      return fileNames[index];
    }
    return path.split(Platform.pathSeparator).last;
  }

  List<OmniMessage> _parseMessagesFromResponse(Map<String, dynamic> decoded) {
    final rawList = decoded['messages'];
    if (rawList is List && rawList.isNotEmpty) {
      return rawList
          .whereType<Map>()
          .map((e) => OmniMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final single = decoded['message'];
    if (single is Map) {
      return [OmniMessage.fromJson(Map<String, dynamic>.from(single))];
    }
    throw Exception('Gagal mengirim');
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
