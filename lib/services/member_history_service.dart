import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member_history_models.dart';
import 'auth_service.dart';

class MemberHistoryService {
  // Get member info by member_id or phone number
  Future<Map<String, dynamic>> getMemberInfo(String search) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
            '${AuthService.baseUrl}/api/approval-app/member-history/info?search=$search'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'member': MemberHistoryModels.fromJson(data['data']),
          };
        } else {
          throw Exception(data['message'] ?? 'Gagal mendapatkan data member');
        }
      } else if (response.statusCode == 404) {
        throw Exception(data['message'] ?? 'Member tidak ditemukan');
      } else {
        throw Exception(data['message'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get member transaction history
  Future<Map<String, dynamic>> getMemberHistory({
    required String memberId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
            '${AuthService.baseUrl}/api/approval-app/member-history/transactions?member_id=$memberId&limit=$limit&offset=$offset'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          final ordersData = data['data'];
          return {
            'success': true,
            'orders': (ordersData['orders'] as List<dynamic>)
                .map((order) => OrderHistoryModel.fromJson(order))
                .toList(),
            'total_count': ordersData['total_count'] ?? 0,
            'total_spending': ordersData['total_spending'] ?? 0.0,
            'total_spending_formatted':
                ordersData['total_spending_formatted'] ?? 'Rp 0',
            'limit': ordersData['limit'] ?? limit,
            'offset': ordersData['offset'] ?? offset,
          };
        } else {
          throw Exception(
              data['message'] ?? 'Gagal mendapatkan history transaksi');
        }
      } else if (response.statusCode == 404) {
        throw Exception(data['message'] ?? 'Member tidak ditemukan');
      } else {
        throw Exception(data['message'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get order detail
  Future<Map<String, dynamic>> getOrderDetail(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
            '${AuthService.baseUrl}/api/approval-app/member-history/order/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'order': OrderDetailModel.fromJson(data['data']),
          };
        } else {
          throw Exception(data['message'] ?? 'Gagal mendapatkan detail order');
        }
      } else if (response.statusCode == 404) {
        throw Exception(data['message'] ?? 'Order tidak ditemukan');
      } else {
        throw Exception(data['message'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get member preferences (favorite items and outlet)
  Future<Map<String, dynamic>> getMemberPreferences({
    required String memberId,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
            '${AuthService.baseUrl}/api/approval-app/member-history/preferences?member_id=$memberId&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'preferences': MemberPreferencesModel.fromJson(data['data']),
          };
        } else {
          throw Exception(
              data['message'] ?? 'Gagal mendapatkan data preferensi member');
        }
      } else if (response.statusCode == 404) {
        throw Exception(data['message'] ?? 'Member tidak ditemukan');
      } else {
        throw Exception(data['message'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get member vouchers
  Future<Map<String, dynamic>> getMemberVouchers({
    required String memberId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
            '${AuthService.baseUrl}/api/approval-app/member-history/vouchers?search=$memberId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'vouchers': data['vouchers'] ?? [],
          };
        } else {
          throw Exception(
              data['message'] ?? 'Gagal mendapatkan data voucher');
        }
      } else if (response.statusCode == 404) {
        throw Exception(data['message'] ?? 'Member tidak ditemukan');
      } else {
        throw Exception(data['message'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get member challenges
  Future<Map<String, dynamic>> getMemberChallenges({
    required String memberId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
            '${AuthService.baseUrl}/api/approval-app/member-history/challenges?search=$memberId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'challenges': data['challenges'] ?? [],
          };
        } else {
          throw Exception(
              data['message'] ?? 'Gagal mendapatkan data challenge');
        }
      } else if (response.statusCode == 404) {
        throw Exception(data['message'] ?? 'Member tidak ditemukan');
      } else {
        throw Exception(data['message'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
