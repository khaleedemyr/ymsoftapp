/// Parse nilai API Meta (ID sering int di JSON, bukan string).
String _jsonStr(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int _jsonInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

/// Hasil poll ringan (daftar + pesan chat terbuka) — sama endpoint web `/poll`.
class IgCommentsBootstrap {
  final List<IgCommentAccount> instagramAccounts;
  final List<IgCommentAccount> facebookPages;

  IgCommentsBootstrap({
    required this.instagramAccounts,
    required this.facebookPages,
  });

  factory IgCommentsBootstrap.fromJson(Map<String, dynamic> json) {
    List<IgCommentAccount> mapAccounts(List? raw, String platform) {
      return (raw ?? [])
          .map((e) {
            if (e is! Map) return null;
            return IgCommentAccount.fromJson(Map<String, dynamic>.from(e), platform);
          })
          .whereType<IgCommentAccount>()
          .toList();
    }

    return IgCommentsBootstrap(
      instagramAccounts: mapAccounts(json['instagram_accounts'], 'instagram'),
      facebookPages: mapAccounts(json['facebook_pages'], 'facebook'),
    );
  }
}

class IgCommentAccount {
  final String id;
  final String label;
  final String platform;

  IgCommentAccount({
    required this.id,
    required this.label,
    required this.platform,
  });

  factory IgCommentAccount.fromJson(Map<String, dynamic> json, String platform) {
    final id = platform == 'facebook'
        ? _jsonStr(json['page_id'] ?? json['ig_id'])
        : _jsonStr(json['ig_id'] ?? json['page_id']);
    return IgCommentAccount(
      id: id,
      label: _jsonStr(json['label'], id),
      platform: platform,
    );
  }
}

class IgCommentPost {
  final String id;
  final String caption;
  final String mediaType;
  final String? thumbnailUrl;
  final String? permalink;
  final int commentsCount;
  final DateTime? timestamp;

  IgCommentPost({
    required this.id,
    required this.caption,
    required this.mediaType,
    this.thumbnailUrl,
    this.permalink,
    this.commentsCount = 0,
    this.timestamp,
  });

  factory IgCommentPost.fromJson(Map<String, dynamic> json) {
    final thumb = json['thumbnail_url'];
    final link = json['permalink'] ?? json['permalink_url'];

    return IgCommentPost(
      id: _jsonStr(json['id']),
      caption: _jsonStr(json['caption']),
      mediaType: _jsonStr(json['media_type']),
      thumbnailUrl: thumb == null || thumb.toString().isEmpty ? null : thumb.toString(),
      permalink: link == null || link.toString().isEmpty ? null : link.toString(),
      commentsCount: _jsonInt(json['comments_count']),
      timestamp: _parseDate(json['timestamp'] ?? json['created_time']),
    );
  }
}

class IgCommentItem {
  final String id;
  final String text;
  final String username;
  final DateTime? timestamp;
  final List<IgCommentItem> replies;

  IgCommentItem({
    required this.id,
    required this.text,
    required this.username,
    this.timestamp,
    this.replies = const [],
  });

  factory IgCommentItem.fromJson(Map<String, dynamic> json) {
    final repliesRaw = json['replies'];
    List<IgCommentItem> replies = [];
    if (repliesRaw is List) {
      replies = repliesRaw
          .whereType<Map>()
          .map((e) => IgCommentItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (repliesRaw is Map) {
      final data = repliesRaw['data'];
      if (data is List) {
        replies = data
            .whereType<Map>()
            .map((e) => IgCommentItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    var username = _jsonStr(json['username']);
    if (username.isEmpty) {
      final from = json['from'];
      if (from is Map) {
        username = _jsonStr(from['username']);
      }
    }

    return IgCommentItem(
      id: _jsonStr(json['id']),
      text: _jsonStr(json['text']),
      username: username,
      timestamp: _parseDate(json['timestamp']),
      replies: replies,
    );
  }
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null || raw.toString().isEmpty) return null;
  try {
    return DateTime.parse(raw.toString()).toLocal();
  } catch (_) {
    return null;
  }
}
