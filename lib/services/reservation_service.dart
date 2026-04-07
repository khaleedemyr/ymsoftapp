import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ReservationService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/approval-app/reservations').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting reservation list: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/reservations/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting reservation create data: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/reservations/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting reservation detail: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> store({
    required String name,
    required String phone,
    String? email,
    required int outletId,
    required String reservationDate,
    required String reservationTime,
    required int numberOfGuests,
    String? smokingPreference,
    String? specialRequests,
    double? dp,
    bool fromSales = false,
    int? salesUserId,
    String? menu,
    required String status,
    File? menuFile,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Tidak ada token'};
      }

      if (menuFile != null) {
        return _storeMultipart(
          token: token,
          name: name,
          phone: phone,
          email: email,
          outletId: outletId,
          reservationDate: reservationDate,
          reservationTime: reservationTime,
          numberOfGuests: numberOfGuests,
          smokingPreference: smokingPreference,
          specialRequests: specialRequests,
          dp: dp,
          fromSales: fromSales,
          salesUserId: salesUserId,
          menu: menu,
          status: status,
          menuFile: menuFile,
        );
      }

      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'outlet_id': outletId,
        'reservation_date': reservationDate,
        'reservation_time': reservationTime,
        'number_of_guests': numberOfGuests,
        'from_sales': fromSales,
        'status': status,
      };
      if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
      if (smokingPreference != null && smokingPreference.trim().isNotEmpty) body['smoking_preference'] = smokingPreference.trim();
      if (specialRequests != null && specialRequests.trim().isNotEmpty) body['special_requests'] = specialRequests.trim();
      if (dp != null && dp > 0) body['dp'] = dp;
      if (fromSales && salesUserId != null) body['sales_user_id'] = salesUserId;
      if (menu != null && menu.trim().isNotEmpty) body['menu'] = menu.trim();

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/reservations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...?data};
      }

      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = error['message']?.toString() ?? (error['errors'] != null ? 'Periksa data yang diisi' : 'Gagal menyimpan');
        return {'success': false, 'message': msg};
      } catch (_) {
        return {'success': false, 'message': 'Gagal menyimpan (${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> _storeMultipart({
    required String token,
    required String name,
    required String phone,
    String? email,
    required int outletId,
    required String reservationDate,
    required String reservationTime,
    required int numberOfGuests,
    String? smokingPreference,
    String? specialRequests,
    double? dp,
    required bool fromSales,
    int? salesUserId,
    String? menu,
    required String status,
    required File menuFile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/approval-app/reservations');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['name'] = name;
    request.fields['phone'] = phone;
    request.fields['outlet_id'] = outletId.toString();
    request.fields['reservation_date'] = reservationDate;
    request.fields['reservation_time'] = reservationTime;
    request.fields['number_of_guests'] = numberOfGuests.toString();
    request.fields['from_sales'] = fromSales ? '1' : '0';
    request.fields['status'] = status;
    if (email != null && email.trim().isNotEmpty) request.fields['email'] = email.trim();
    if (smokingPreference != null && smokingPreference.trim().isNotEmpty) request.fields['smoking_preference'] = smokingPreference;
    if (specialRequests != null && specialRequests.trim().isNotEmpty) request.fields['special_requests'] = specialRequests;
    if (dp != null && dp > 0) request.fields['dp'] = dp.toString();
    if (fromSales && salesUserId != null) request.fields['sales_user_id'] = salesUserId.toString();
    if (menu != null && menu.trim().isNotEmpty) request.fields['menu'] = menu.trim();
    final bytes = await menuFile.readAsBytes();
    final filename = menuFile.path.split(RegExp(r'[/\\]')).last;
    request.files.add(http.MultipartFile.fromBytes('menu_file', bytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, ...?data};
    }
    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = error['message']?.toString() ?? (error['errors'] != null ? 'Periksa data yang diisi' : 'Gagal menyimpan');
      return {'success': false, 'message': msg};
    } catch (_) {
      return {'success': false, 'message': 'Gagal menyimpan (${response.statusCode})'};
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String name,
    required String phone,
    String? email,
    required int outletId,
    required String reservationDate,
    required String reservationTime,
    required int numberOfGuests,
    String? smokingPreference,
    String? specialRequests,
    double? dp,
    bool fromSales = false,
    int? salesUserId,
    String? menu,
    required String status,
    File? menuFile,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Tidak ada token'};
      }

      if (menuFile != null) {
        return _updateMultipart(
          id: id,
          token: token,
          name: name,
          phone: phone,
          email: email,
          outletId: outletId,
          reservationDate: reservationDate,
          reservationTime: reservationTime,
          numberOfGuests: numberOfGuests,
          smokingPreference: smokingPreference,
          specialRequests: specialRequests,
          dp: dp,
          fromSales: fromSales,
          salesUserId: salesUserId,
          menu: menu,
          status: status,
          menuFile: menuFile,
        );
      }

      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'outlet_id': outletId,
        'reservation_date': reservationDate,
        'reservation_time': reservationTime,
        'number_of_guests': numberOfGuests,
        'from_sales': fromSales,
        'status': status,
      };
      if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
      if (smokingPreference != null && smokingPreference.trim().isNotEmpty) body['smoking_preference'] = smokingPreference.trim();
      if (specialRequests != null && specialRequests.trim().isNotEmpty) body['special_requests'] = specialRequests.trim();
      if (dp != null && dp > 0) body['dp'] = dp;
      if (fromSales && salesUserId != null) body['sales_user_id'] = salesUserId;
      if (menu != null && menu.trim().isNotEmpty) body['menu'] = menu.trim();

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/reservations/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...?data};
      }

      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = error['message']?.toString() ?? (error['errors'] != null ? 'Periksa data yang diisi' : 'Gagal mengupdate');
        return {'success': false, 'message': msg};
      } catch (_) {
        return {'success': false, 'message': 'Gagal mengupdate (${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> _updateMultipart({
    required int id,
    required String token,
    required String name,
    required String phone,
    String? email,
    required int outletId,
    required String reservationDate,
    required String reservationTime,
    required int numberOfGuests,
    String? smokingPreference,
    String? specialRequests,
    double? dp,
    required bool fromSales,
    int? salesUserId,
    String? menu,
    required String status,
    required File menuFile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/approval-app/reservations/$id');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['name'] = name;
    request.fields['phone'] = phone;
    request.fields['outlet_id'] = outletId.toString();
    request.fields['reservation_date'] = reservationDate;
    request.fields['reservation_time'] = reservationTime;
    request.fields['number_of_guests'] = numberOfGuests.toString();
    request.fields['from_sales'] = fromSales ? '1' : '0';
    request.fields['status'] = status;
    if (email != null && email.trim().isNotEmpty) request.fields['email'] = email.trim();
    if (smokingPreference != null && smokingPreference.trim().isNotEmpty) request.fields['smoking_preference'] = smokingPreference;
    if (specialRequests != null && specialRequests.trim().isNotEmpty) request.fields['special_requests'] = specialRequests;
    if (dp != null && dp > 0) request.fields['dp'] = dp.toString();
    if (fromSales && salesUserId != null) request.fields['sales_user_id'] = salesUserId.toString();
    if (menu != null && menu.trim().isNotEmpty) request.fields['menu'] = menu.trim();
    final bytes = await menuFile.readAsBytes();
    final filename = menuFile.path.split(RegExp(r'[/\\]')).last;
    request.files.add(http.MultipartFile.fromBytes('menu_file', bytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, ...?data};
    }
    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = error['message']?.toString() ?? (error['errors'] != null ? 'Periksa data yang diisi' : 'Gagal mengupdate');
      return {'success': false, 'message': msg};
    } catch (_) {
      return {'success': false, 'message': 'Gagal mengupdate (${response.statusCode})'};
    }
  }
}
