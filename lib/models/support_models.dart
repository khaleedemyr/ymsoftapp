import 'dart:convert';

class SupportConversation {
  final int id;
  final String subject;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderName;
  final String? lastSenderType;
  final int unreadCount;
  final String? customerName;
  final String? customerEmail;
  final String? customerOutlet;
  final String? customerDivisi;
  final String? customerJabatan;

  SupportConversation({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderName,
    this.lastSenderType,
    this.unreadCount = 0,
    this.customerName,
    this.customerEmail,
    this.customerOutlet,
    this.customerDivisi,
    this.customerJabatan,
  });

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['id'] as int,
      subject: json['subject'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastSenderName: json['last_sender_name'] as String?,
      lastSenderType: json['last_sender_type'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      customerOutlet: json['customer_outlet'] as String?,
      customerDivisi: json['customer_divisi'] as String?,
      customerJabatan: json['customer_jabatan'] as String?,
    );
  }
}

class SupportMessage {
  final int id;
  final String message;
  final String messageType;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String senderType;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

  SupportMessage({
    required this.id,
    required this.message,
    required this.messageType,
    this.filePath,
    this.fileName,
    this.fileSize,
    required this.senderType,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as int,
      message: json['message'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      filePath: json['file_path'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      senderType: json['sender_type'] as String? ?? 'user',
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }

  List<Map<String, dynamic>> getFileAttachments() {
    if (filePath == null) return [];
    
    try {
      final parsed = jsonDecode(filePath!);
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(parsed);
      } else if (parsed is Map) {
        return [Map<String, dynamic>.from(parsed)];
      }
    } catch (e) {
      // Fallback for old single file format
      return [{
        'original_name': fileName ?? 'attachment',
        'file_path': filePath,
        'file_size': fileSize ?? 0,
        'mime_type': 'application/octet-stream'
      }];
    }
    
    return [];
  }
}

class SupportPagination {
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final int from;
  final int to;

  SupportPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.from,
    required this.to,
  });

  factory SupportPagination.fromJson(Map<String, dynamic> json) {
    return SupportPagination(
      currentPage: json['current_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 15,
      total: json['total'] as int? ?? 0,
      lastPage: json['last_page'] as int? ?? 1,
      from: json['from'] as int? ?? 0,
      to: json['to'] as int? ?? 0,
    );
  }
}

