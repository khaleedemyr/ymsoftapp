import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class NotificationService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/notifications'),
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
            'notifications': data is List ? data : (data['notifications'] ?? []),
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to parse response: ${e.toString()}',
          };
        }
      }

      // Handle 401 Unauthenticated
      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthenticated. Please login again.',
        };
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to fetch notifications',
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

  Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/notifications/unread-count'),
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
            'count': data['count'] ?? 0,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to parse response: ${e.toString()}',
          };
        }
      }

      // Handle 401 Unauthenticated
      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthenticated. Please login again.',
        };
      }

      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to fetch unread count',
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

  Future<Map<String, dynamic>> markAsRead(int notificationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/notifications/$notificationId/read'),
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
            'message': data['message'] ?? 'Notification marked as read',
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
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to mark notification as read',
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

  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/notifications/read-all'),
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
            'message': data['message'] ?? 'All notifications marked as read',
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
          'message': errorData['error'] ?? errorData['message'] ?? 'Failed to mark all notifications as read',
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
}

