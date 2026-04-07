import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';

class RetailNonFoodService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? dateFrom,
    String? dateTo,
    int? outletId,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/retail-non-food').replace(
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
      print('Error getting retail non food list: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-non-food/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting retail non food create data: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-non-food/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting retail non food detail: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> store({
    required int outletId,
    required String transactionDate,
    required int categoryBudgetId,
    required String paymentMethod,
    required int supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
    List<XFile>? invoiceFiles,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final hasInvoices = invoiceFiles != null && invoiceFiles.isNotEmpty;

      if (hasInvoices) {
        return await _storeMultipart(
          token: token,
          outletId: outletId,
          transactionDate: transactionDate,
          categoryBudgetId: categoryBudgetId,
          paymentMethod: paymentMethod,
          supplierId: supplierId,
          notes: notes,
          items: items,
          invoiceFiles: invoiceFiles!,
        );
      }

      final body = <String, dynamic>{
        'outlet_id': outletId,
        'transaction_date': transactionDate,
        'category_budget_id': categoryBudgetId,
        'payment_method': paymentMethod,
        'supplier_id': supplierId,
        'items': items,
      };
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/retail-non-food'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': false, 'message': error['message'] ?? 'Gagal menyimpan'};
      } catch (_) {
        return {'success': false, 'message': 'Gagal menyimpan (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> _storeMultipart({
    required String token,
    required int outletId,
    required String transactionDate,
    required int categoryBudgetId,
    required String paymentMethod,
    required int supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
    required List<XFile> invoiceFiles,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/retail-non-food'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['outlet_id'] = outletId.toString();
      request.fields['transaction_date'] = transactionDate;
      request.fields['category_budget_id'] = categoryBudgetId.toString();
      request.fields['payment_method'] = paymentMethod;
      request.fields['supplier_id'] = supplierId.toString();
      // Kirim items sebagai form array agar Laravel terima native array (hindari "items must be an array")
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        request.fields['items[$i][item_name]'] = item['item_name']?.toString() ?? '';
        request.fields['items[$i][qty]'] = (item['qty'] is num ? (item['qty'] as num).toString() : item['qty']?.toString()) ?? '0';
        request.fields['items[$i][unit]'] = item['unit']?.toString() ?? '';
        request.fields['items[$i][price]'] = (item['price'] is num ? (item['price'] as num).toString() : item['price']?.toString()) ?? '0';
      }
      if (notes != null && notes.isNotEmpty) request.fields['notes'] = notes;

      for (var i = 0; i < invoiceFiles.length; i++) {
        final xFile = invoiceFiles[i];
        final path = xFile.path;
        final name = xFile.name;
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
        if (path.isEmpty) continue;
        if (!['jpg', 'jpeg', 'png'].contains(ext)) continue;
        final file = await http.MultipartFile.fromPath(
          'invoices[]',
          path,
          filename: name.isNotEmpty ? name : 'invoice_$i.jpg',
        );
        request.files.add(file);
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': false, 'message': error['message'] ?? 'Gagal menyimpan'};
      } catch (_) {
        return {'success': false, 'message': 'Gagal menyimpan (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
