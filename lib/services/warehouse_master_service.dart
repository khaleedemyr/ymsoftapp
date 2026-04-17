import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseMasterService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return auth.getToken();
  }

  Future<Map<String, dynamic>> _decodeMap(http.Response response) async {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Format respons tidak valid'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Gagal membaca respons (${response.statusCode})'
      };
    }
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
      };

  // WAREHOUSES
  Future<Map<String, dynamic>> getWarehouses({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/warehouses')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createWarehouse({
    required String code,
    required String name,
    required String location,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/warehouses'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'location': location,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateWarehouse({
    required int id,
    required String code,
    required String name,
    required String location,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/warehouses/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'location': location,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleWarehouseStatus({
    required int id,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouses/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode({'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteWarehouse(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/warehouses/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // WAREHOUSE OUTLETS
  Future<Map<String, dynamic>> getWarehouseOutletCreateData() async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-outlets/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getWarehouseOutlets({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri = Uri.parse(
              '$baseUrl/api/approval-app/warehouse-master/warehouse-outlets')
          .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createWarehouseOutlet({
    required String code,
    required String name,
    required int outletId,
    required String location,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-outlets'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'outlet_id': outletId,
          'location': location,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateWarehouseOutlet({
    required int id,
    required String code,
    required String name,
    required int outletId,
    required String location,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-outlets/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'outlet_id': outletId,
          'location': location,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteWarehouseOutlet(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-outlets/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleWarehouseOutletStatus({
    required int id,
    String? status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-outlets/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode(
            status == null ? <String, dynamic>{} : {'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // WAREHOUSE DIVISIONS
  Future<Map<String, dynamic>> getWarehouseDivisionCreateData() async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-divisions/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getWarehouseDivisions({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri = Uri.parse(
              '$baseUrl/api/approval-app/warehouse-master/warehouse-divisions')
          .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createWarehouseDivision({
    required String name,
    required int warehouseId,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-divisions'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'warehouse_id': warehouseId,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateWarehouseDivision({
    required int id,
    required String name,
    required int warehouseId,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-divisions/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'warehouse_id': warehouseId,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteWarehouseDivision(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-divisions/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleWarehouseDivisionStatus({
    required int id,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/warehouse-divisions/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode({'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // OUTLETS
  Future<Map<String, dynamic>> getOutletCreateData() async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/outlets/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getMasterOutlets({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/outlets')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createMasterOutlet({
    required String namaOutlet,
    required String lokasi,
    required int regionId,
    String? qrCode,
    String? lat,
    String? long,
    String? keterangan,
    String? urlPlaces,
    String? sn,
    String? activationCode,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/outlets'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'nama_outlet': namaOutlet,
          'lokasi': lokasi,
          'region_id': regionId,
          'qr_code': qrCode,
          'lat': lat,
          'long': long,
          'keterangan': keterangan,
          'url_places': urlPlaces,
          'sn': sn,
          'activation_code': activationCode,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateMasterOutlet({
    required int id,
    required String namaOutlet,
    required String lokasi,
    required int regionId,
    required String status,
    String? qrCode,
    String? lat,
    String? long,
    String? keterangan,
    String? urlPlaces,
    String? sn,
    String? activationCode,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/outlets/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'nama_outlet': namaOutlet,
          'lokasi': lokasi,
          'region_id': regionId,
          'status': status,
          'qr_code': qrCode,
          'lat': lat,
          'long': long,
          'keterangan': keterangan,
          'url_places': urlPlaces,
          'sn': sn,
          'activation_code': activationCode,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteMasterOutlet(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/outlets/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleMasterOutletStatus(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/outlets/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode(<String, dynamic>{}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // CUSTOMERS
  Future<Map<String, dynamic>> getCustomers({
    String? search,
    String? status,
    String? type,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (type != null && type.isNotEmpty) query['type'] = type;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/customers')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createCustomer({
    required String code,
    required String name,
    required String type,
    required String region,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/customers'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'type': type,
          'region': region,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateCustomer({
    required int id,
    required String code,
    required String name,
    required String type,
    required String region,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/customers/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'type': type,
          'region': region,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleCustomerStatus({
    required int id,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/customers/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode({'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteCustomer(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/customers/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // SUPPLIERS
  Future<Map<String, dynamic>> getSuppliers({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/suppliers')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createSupplier({
    required String code,
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? npwp,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? paymentTerm,
    String? paymentDays,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/suppliers'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'contact_person': contactPerson,
          'phone': phone,
          'email': email,
          'address': address,
          'city': city,
          'province': province,
          'postal_code': postalCode,
          'npwp': npwp,
          'bank_name': bankName,
          'bank_account_number': bankAccountNumber,
          'bank_account_name': bankAccountName,
          'payment_term': paymentTerm,
          'payment_days': paymentDays,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateSupplier({
    required int id,
    required String code,
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? npwp,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? paymentTerm,
    String? paymentDays,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/suppliers/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'contact_person': contactPerson,
          'phone': phone,
          'email': email,
          'address': address,
          'city': city,
          'province': province,
          'postal_code': postalCode,
          'npwp': npwp,
          'bank_name': bankName,
          'bank_account_number': bankAccountNumber,
          'bank_account_name': bankAccountName,
          'payment_term': paymentTerm,
          'payment_days': paymentDays,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleSupplierStatus({
    required int id,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/suppliers/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode({'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteSupplier(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/suppliers/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // REGIONS
  Future<Map<String, dynamic>> getRegions({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/regions')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createRegion({
    required String code,
    required String name,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/regions'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateRegion({
    required int id,
    required String code,
    required String name,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/regions/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'status': status,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleRegionStatus({
    required int id,
    required String status,
  }) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.patch(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/regions/$id/toggle-status'),
        headers: _headers(token, json: true),
        body: jsonEncode({'status': status}),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteRegion(int id) async {
    try {
      final token = await _getToken();
      if (token == null)
        return {'success': false, 'message': 'No authentication token'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/regions/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // INVESTORS
  Future<Map<String, dynamic>> getInvestorCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/investors/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getInvestors({
    String? search,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/investors')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createInvestor({
    required String name,
    String? email,
    String? phone,
    required List<int> outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/investors'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'outlet_ids': outletIds,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateInvestor({
    required int id,
    required String name,
    String? email,
    String? phone,
    required List<int> outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/investors/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'outlet_ids': outletIds,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteInvestor(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/investors/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // OFFICER CHECKS
  Future<Map<String, dynamic>> getOfficerCheckCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/officer-checks/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getOfficerChecks({
    String? search,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/officer-checks')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createOfficerCheck({
    required int userId,
    required String nilai,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/officer-checks'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'user_id': userId,
          'nilai': nilai,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateOfficerCheck({
    required int id,
    required int userId,
    required String nilai,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/officer-checks/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'user_id': userId,
          'nilai': nilai,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteOfficerCheck(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/officer-checks/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // PAYMENT TYPES
  Future<Map<String, dynamic>> getPaymentTypeCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/payment-types/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPaymentTypes({
    String? search,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/payment-types')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createPaymentType({
    required String name,
    required String code,
    required bool isBank,
    String? bankName,
    String? description,
    required String status,
    required String outletType,
    required List<int> outletIds,
    required List<int> regionIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/payment-types'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'code': code,
          'is_bank': isBank,
          'bank_name': bankName,
          'description': description,
          'status': status,
          'outlet_type': outletType,
          'outlets': outletIds,
          'regions': regionIds,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePaymentType({
    required int id,
    required String name,
    required String code,
    required bool isBank,
    String? bankName,
    String? description,
    required String status,
    required String outletType,
    required List<int> outletIds,
    required List<int> regionIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/payment-types/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'code': code,
          'is_bank': isBank,
          'bank_name': bankName,
          'description': description,
          'status': status,
          'outlet_type': outletType,
          'outlets': outletIds,
          'regions': regionIds,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePaymentType(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/payment-types/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ITEM SCHEDULES
  Future<Map<String, dynamic>> getItemScheduleCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/item-schedules/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getItemSchedules({
    String? search,
    String? arrivalDay,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (arrivalDay != null && arrivalDay.isNotEmpty) {
        query['arrival_day'] = arrivalDay;
      }

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/item-schedules')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createItemSchedule({
    required int itemId,
    required String arrivalDay,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/item-schedules'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'item_id': itemId,
          'arrival_day': arrivalDay,
          'notes': notes,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateItemSchedule({
    required int id,
    required int itemId,
    required String arrivalDay,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/item-schedules/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'item_id': itemId,
          'arrival_day': arrivalDay,
          'notes': notes,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteItemSchedule(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/item-schedules/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // RO SCHEDULES
  Future<Map<String, dynamic>> getRoScheduleCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/fo-schedules/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getRoSchedules({
    String? search,
    String? foMode,
    String? day,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (foMode != null && foMode.isNotEmpty) query['fo_mode'] = foMode;
      if (day != null && day.isNotEmpty) query['day'] = day;

      final uri =
          Uri.parse('$baseUrl/api/approval-app/warehouse-master/fo-schedules')
              .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createRoSchedule({
    required String foMode,
    required List<int> warehouseDivisionIds,
    required String day,
    required String openTime,
    required String closeTime,
    required List<int> regionIds,
    required List<int> outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/warehouse-master/fo-schedules'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'fo_mode': foMode,
          'warehouse_division_ids': warehouseDivisionIds,
          'day': day,
          'open_time': openTime,
          'close_time': closeTime,
          'region_ids': regionIds,
          'outlet_ids': outletIds,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateRoSchedule({
    required int id,
    required String foMode,
    required List<int> warehouseDivisionIds,
    required String day,
    required String openTime,
    required String closeTime,
    required List<int> regionIds,
    required List<int> outletIds,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/fo-schedules/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'fo_mode': foMode,
          'warehouse_division_ids': warehouseDivisionIds,
          'day': day,
          'open_time': openTime,
          'close_time': closeTime,
          'region_ids': regionIds,
          'outlet_ids': outletIds,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteRoSchedule(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/warehouse-master/fo-schedules/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // LOCKED BUDGET FOOD CATEGORIES
  Future<Map<String, dynamic>> getLockedBudgetFoodCategoryCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/locked-budget-food-categories/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getLockedBudgetFoodCategories({
    String? search,
    int? categoryId,
    int? outletId,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (categoryId != null) query['category_id'] = categoryId.toString();
      if (outletId != null) query['outlet_id'] = outletId.toString();
      final uri = Uri.parse(
              '$baseUrl/api/approval-app/finance-master/locked-budget-food-categories/index')
          .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createLockedBudgetFoodCategory({
    required int categoryId,
    required int subCategoryId,
    required int outletId,
    required num budget,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/locked-budget-food-categories/store'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'category_id': categoryId,
          'sub_category_id': subCategoryId,
          'outlet_id': outletId,
          'budget': budget,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateLockedBudgetFoodCategory({
    required int id,
    required int categoryId,
    required int subCategoryId,
    required int outletId,
    required num budget,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/locked-budget-food-categories/update/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'category_id': categoryId,
          'sub_category_id': subCategoryId,
          'outlet_id': outletId,
          'budget': budget,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteLockedBudgetFoodCategory(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/locked-budget-food-categories/destroy/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // BUDGET MANAGEMENT
  Future<Map<String, dynamic>> getBudgetManagementCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/budget-management/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getBudgetManagementCategories({
    String? search,
    String? division,
    String? budgetType,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (division != null && division.isNotEmpty) query['division'] = division;
      if (budgetType != null && budgetType.isNotEmpty) {
        query['budget_type'] = budgetType;
      }
      final uri = Uri.parse(
              '$baseUrl/api/approval-app/finance-master/budget-management/index')
          .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createBudgetManagementCategory({
    required String name,
    required String division,
    required String subcategory,
    required num budgetLimit,
    required String budgetType,
    String? description,
    List<int> selectedOutletIds = const [],
    Map<String, dynamic> outletBudgets = const {},
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/budget-management/store'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'division': division,
          'subcategory': subcategory,
          'budget_limit': budgetLimit,
          'budget_type': budgetType,
          'description': description,
          'selected_outlets': selectedOutletIds,
          'outlet_budgets': outletBudgets,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateBudgetManagementCategory({
    required int id,
    required String name,
    required String division,
    required String subcategory,
    required num budgetLimit,
    required String budgetType,
    String? description,
    List<int> selectedOutletIds = const [],
    Map<String, dynamic> outletBudgets = const {},
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/budget-management/update/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'name': name,
          'division': division,
          'subcategory': subcategory,
          'budget_limit': budgetLimit,
          'budget_type': budgetType,
          'description': description,
          'selected_outlets': selectedOutletIds,
          'outlet_budgets': outletBudgets,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteBudgetManagementCategory(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/budget-management/destroy/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // CHART OF ACCOUNTS
  Future<Map<String, dynamic>> getChartOfAccountCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/chart-of-accounts/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getChartOfAccounts({
    String? search,
    String? status,
    String? type,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (type != null && type.isNotEmpty) query['type'] = type;
      final uri = Uri.parse(
              '$baseUrl/api/approval-app/finance-master/chart-of-accounts/index')
          .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createChartOfAccount({
    required String code,
    required String name,
    required String type,
    int? parentId,
    String? description,
    num? budgetLimit,
    bool isActive = true,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/chart-of-accounts/store'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'type': type,
          'parent_id': parentId,
          'description': description,
          'budget_limit': budgetLimit,
          'is_active': isActive,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateChartOfAccount({
    required int id,
    required String code,
    required String name,
    required String type,
    int? parentId,
    String? description,
    num? budgetLimit,
    bool isActive = true,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/chart-of-accounts/update/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'code': code,
          'name': name,
          'type': type,
          'parent_id': parentId,
          'description': description,
          'budget_limit': budgetLimit,
          'is_active': isActive,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteChartOfAccount(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/chart-of-accounts/destroy/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // BANK ACCOUNTS
  Future<Map<String, dynamic>> getBankAccountCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/bank-accounts/create-data'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getBankAccounts({
    String? search,
    String? status,
    String? outletId,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final query = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (outletId != null && outletId.isNotEmpty)
        query['outlet_id'] = outletId;
      final uri = Uri.parse(
              '$baseUrl/api/approval-app/finance-master/bank-accounts/index')
          .replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers(token));
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
    int? outletId,
    int? coaId,
    bool isActive = true,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/bank-accounts/store'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_name': accountName,
          'outlet_id': outletId,
          'coa_id': coaId,
          'is_active': isActive,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateBankAccount({
    required int id,
    required String bankName,
    required String accountNumber,
    required String accountName,
    int? outletId,
    int? coaId,
    bool isActive = true,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/bank-accounts/update/$id'),
        headers: _headers(token, json: true),
        body: jsonEncode({
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_name': accountName,
          'outlet_id': outletId,
          'coa_id': coaId,
          'is_active': isActive,
        }),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteBankAccount(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/approval-app/finance-master/bank-accounts/destroy/$id'),
        headers: _headers(token),
      );
      return _decodeMap(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
