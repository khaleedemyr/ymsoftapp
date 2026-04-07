import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../models/support_models.dart';

class SupportService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Admin: Get all conversations
  Future<Map<String, dynamic>> getAllConversations({
    String status = 'all',
    String priority = 'all',
    String search = '',
    String? dateFrom,
    String? dateTo,
    int perPage = 15,
    int page = 1,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final queryParams = <String, String>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };

      if (status != 'all') queryParams['status'] = status;
      if (priority != 'all') queryParams['priority'] = priority;
      if (search.isNotEmpty) queryParams['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/approval-app/support/admin/conversations')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'data': data,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to parse response: ${e.toString()}',
          };
        }
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to fetch conversations',
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // User: Get user's conversations
  Future<List<SupportConversation>> getUserConversations() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/support/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => SupportConversation.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching user conversations: $e');
      return [];
    }
  }

  // User: Get unread conversations count
  Future<int> getUnreadConversationsCount() async {
    try {
      final conversations = await getUserConversations();
      int total = 0;
      for (var conv in conversations) {
        if (conv.unreadCount > 0 && conv.status != 'closed' && conv.status != 'resolved') {
          total += conv.unreadCount;
        }
      }
      return total;
    } catch (e) {
      print('Error fetching unread count: $e');
      return 0;
    }
  }

  // User: Create new conversation
  Future<Map<String, dynamic>> createConversation({
    required String subject,
    String? message,
    String priority = 'medium',
    List<File>? files,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/support/conversations'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['subject'] = subject;
      if (message != null && message.isNotEmpty) {
        request.fields['message'] = message;
      }
      request.fields['priority'] = priority;

      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileExtension = file.path.split('.').last;
          final mimeType = _getMimeType(fileExtension);
          
          request.files.add(
            await http.MultipartFile.fromPath(
              'files[$i]',
              file.path,
              filename: file.path.split('/').last,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'conversation': SupportConversation.fromJson(data),
        };
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Failed to create conversation',
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // User: Send message to conversation
  Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    String? message,
    List<File>? files,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/support/conversations/$conversationId/messages'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (message != null && message.isNotEmpty) {
        request.fields['message'] = message;
      }

      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileExtension = file.path.split('.').last;
          final mimeType = _getMimeType(fileExtension);
          
          request.files.add(
            await http.MultipartFile.fromPath(
              'files[$i]',
              file.path,
              filename: file.path.split('/').last,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': SupportMessage.fromJson(data),
        };
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Failed to send message',
          'conversation_closed': errorData['conversation_closed'] ?? false,
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // User: Mark messages as read
  Future<Map<String, dynamic>> markMessagesAsRead(int conversationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/support/conversations/$conversationId/mark-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Failed to mark messages as read',
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get conversation messages
  Future<List<SupportMessage>> getConversationMessages(int conversationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/support/conversations/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => SupportMessage.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  // Admin: Reply to conversation
  Future<Map<String, dynamic>> adminReply(
    int conversationId,
    String message, {
    List<File>? files,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/support/admin/conversations/$conversationId/reply'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['message'] = message;

      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileExtension = file.path.split('.').last;
          final mimeType = _getMimeType(fileExtension);
          
          request.files.add(
            await http.MultipartFile.fromPath(
              'files[$i]',
              file.path,
              filename: file.path.split('/').last,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': SupportMessage.fromJson(data),
        };
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['error'] ?? 'Failed to send reply',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Admin: Update conversation status
  Future<Map<String, dynamic>> updateConversationStatus(
    int conversationId,
    String status, {
    String? priority,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final body = <String, dynamic>{
        'status': status,
      };
      if (priority != null) {
        body['priority'] = priority;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/support/admin/conversations/$conversationId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['error'] ?? 'Failed to update status',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get attachment URL
  String getAttachmentUrl(int conversationId, int messageId, int fileIndex) {
    return '$baseUrl/api/approval-app/support/conversations/$conversationId/messages/$messageId/files/$fileIndex';
  }

  String _getMimeType(String extension) {
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'xls': 'application/vnd.ms-excel',
    };
    return mimeTypes[extension.toLowerCase()] ?? 'application/octet-stream';
  }
}

