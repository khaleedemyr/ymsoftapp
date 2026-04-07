import 'dart:convert';

class ActivityLog {
  final int id;
  final int? userId;
  final String? userName;
  final String activityType;
  final String? module;
  final String? description;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String createdAt;

  ActivityLog({
    required this.id,
    this.userId,
    this.userName,
    required this.activityType,
    this.module,
    this.description,
    this.ipAddress,
    this.userAgent,
    this.oldData,
    this.newData,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse JSON string or Map
    Map<String, dynamic>? parseJsonField(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
          return null;
        } catch (e) {
          print('Error parsing JSON field: $e');
          return null;
        }
      }
      return null;
    }

    // Safely parse created_at
    String parseCreatedAt(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is DateTime) return value.toIso8601String();
      return value.toString();
    }

    return ActivityLog(
      id: json['id'] is int ? json['id'] : (json['id'] is num ? (json['id'] as num).toInt() : 0),
      userId: json['user_id'] is int ? json['user_id'] : (json['user_id'] is num ? (json['user_id'] as num).toInt() : null),
      userName: json['user_name']?.toString(),
      activityType: json['activity_type']?.toString() ?? '',
      module: json['module']?.toString(),
      description: json['description']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      oldData: parseJsonField(json['old_data']),
      newData: parseJsonField(json['new_data']),
      createdAt: parseCreatedAt(json['created_at']),
    );
  }
}

class ActivityLogPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;
  final String? nextPageUrl;
  final String? prevPageUrl;
  final List<ActivityLog> data;

  ActivityLogPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
    this.nextPageUrl,
    this.prevPageUrl,
    required this.data,
  });

  factory ActivityLogPagination.fromJson(Map<String, dynamic> json) {
    return ActivityLogPagination(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 25,
      total: json['total'] ?? 0,
      from: json['from'] ?? 0,
      to: json['to'] ?? 0,
      nextPageUrl: json['next_page_url'],
      prevPageUrl: json['prev_page_url'],
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => ActivityLog.fromJson(item))
              .toList() ??
          [],
    );
  }
}

