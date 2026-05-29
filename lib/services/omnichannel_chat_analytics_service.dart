import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OmniChatAnalyticsData {
  final Map<String, dynamic> filters;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> series;
  final List<OmniAnalyticsChannelOption> channelOptions;

  OmniChatAnalyticsData({
    required this.filters,
    required this.summary,
    required this.series,
    required this.channelOptions,
  });

  factory OmniChatAnalyticsData.fromJson(Map<String, dynamic> json) {
    return OmniChatAnalyticsData(
      filters: Map<String, dynamic>.from(json['filters'] as Map? ?? {}),
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      series: Map<String, dynamic>.from(json['series'] as Map? ?? {}),
      channelOptions: (json['channel_options'] as List? ?? [])
          .map((e) => OmniAnalyticsChannelOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class OmniAnalyticsChannelOption {
  final String value;
  final String label;

  OmniAnalyticsChannelOption({required this.value, required this.label});

  factory OmniAnalyticsChannelOption.fromJson(Map<String, dynamic> json) {
    return OmniAnalyticsChannelOption(
      value: (json['value'] ?? 'all') as String,
      label: (json['label'] ?? '') as String,
    );
  }
}

class OmnichannelChatAnalyticsService {
  static String get _root => '${AuthService.baseUrl}/api/approval-app/omnichannel-chat-analytics';

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
    };
  }

  Future<OmniChatAnalyticsData> fetch({
    String? dateFrom,
    String? dateTo,
    String? channel,
  }) async {
    final q = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) q['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) q['date_to'] = dateTo;
    if (channel != null && channel.isNotEmpty && channel != 'all') {
      q['channel'] = channel;
    }
    final uri = Uri.parse(_root).replace(queryParameters: q.isEmpty ? null : q);
    final res = await http.get(uri, headers: await _authHeaders());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat analisis chat');
    }
    return OmniChatAnalyticsData.fromJson(body);
  }
}
