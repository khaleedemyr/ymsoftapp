class NotificationModel {
  final int id;
  final int? taskId;
  final String type;
  final String title;
  final String message;
  final String? url;
  final bool isRead;
  final String createdAt;
  final String time; // diffForHumans format

  NotificationModel({
    required this.id,
    this.taskId,
    required this.type,
    required this.title,
    required this.message,
    this.url,
    required this.isRead,
    required this.createdAt,
    required this.time,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Handle is_read in various formats: bool, int (0/1), string ("true"/"false"/"1"/"0")
    bool parseIsRead(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return false;
    }
    
    return NotificationModel(
      id: json['id'] ?? 0,
      taskId: json['task_id'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      url: json['url'],
      isRead: parseIsRead(json['is_read']),
      createdAt: json['created_at']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'type': type,
      'title': title,
      'message': message,
      'url': url,
      'is_read': isRead,
      'created_at': createdAt,
      'time': time,
    };
  }
}

