import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';

class RetailFoodService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<Map<String, dynamic>?> getList({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? paymentMethod,
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
      if (paymentMethod != null && paymentMethod.isNotEmpty) queryParams['payment_method'] = paymentMethod;
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/retail-food').replace(
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
      print('Error getting retail food list: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-food/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting retail food create data: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/retail-food/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting retail food detail: $e');
    }
    return null;
  }

  /// Search items (uses approval-app items/search)
  Future<List<Map<String, dynamic>>> searchItems(String query) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$baseUrl/api/approval-app/items/search').replace(
        queryParameters: {'q': query},
      );

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (data is Map && data['items'] != null && data['items'] is List) {
          return (data['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('Error searching items: $e');
    }
    return [];
  }

  /// Get units and optional default price for an item (for retail food form)
  Future<Map<String, dynamic>?> getItemUnits(
    int itemId, {
    String? paymentMethod,
    int? outletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (paymentMethod != null) queryParams['payment_method'] = paymentMethod;
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/retail-food/get-item-units/$itemId').replace(
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
      print('Error getting item units: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> store({
    required int outletId,
    required String transactionDate,
    int? warehouseOutletId,
    required String paymentMethod,
    int? supplierId,
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
          warehouseOutletId: warehouseOutletId,
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
        'payment_method': paymentMethod,
        'items': items,
      };
      if (warehouseOutletId != null) body['warehouse_outlet_id'] = warehouseOutletId;
      if (supplierId != null) body['supplier_id'] = supplierId;
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/retail-food'),
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
    int? warehouseOutletId,
    required String paymentMethod,
    int? supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
    required List<XFile> invoiceFiles,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/retail-food'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['outlet_id'] = outletId.toString();
      request.fields['transaction_date'] = transactionDate;
      request.fields['payment_method'] = paymentMethod;
      // Kirim items sebagai form array agar Laravel terima native array
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        request.fields['items[$i][item_name]'] = item['item_name']?.toString() ?? '';
        request.fields['items[$i][qty]'] = (item['qty'] is num ? (item['qty'] as num).toString() : item['qty']?.toString()) ?? '0';
        request.fields['items[$i][unit]'] = item['unit']?.toString() ?? '';
        request.fields['items[$i][price]'] = (item['price'] is num ? (item['price'] as num).toString() : item['price']?.toString()) ?? '0';
        if (item['unit_id'] != null) request.fields['items[$i][unit_id]'] = item['unit_id'].toString();
      }
      if (warehouseOutletId != null) request.fields['warehouse_outlet_id'] = warehouseOutletId.toString();
      if (supplierId != null) request.fields['supplier_id'] = supplierId.toString();
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

  Future<Map<String, dynamic>> deleteRetailFood(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/retail-food/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.trim().isEmpty) {
          return {'success': true, 'message': 'Transaksi retail food berhasil dihapus'};
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': false, 'message': error['message'] ?? 'Gagal menghapus'};
      } catch (_) {
        return {'success': false, 'message': 'Gagal menghapus (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
