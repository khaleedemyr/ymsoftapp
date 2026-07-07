import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class LostBreakageService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final auth = AuthService();
    return await auth.getToken();
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>?> getList({
    int? outletId,
    int? ownerOutletId,
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{};
      if (outletId != null) qp['outlet_id'] = outletId.toString();
      if (ownerOutletId != null) qp['owner_outlet_id'] = ownerOutletId.toString();
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (status != null && status.isNotEmpty) qp['status'] = status;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
      if (page != null) qp['page'] = page.toString();
      if (perPage != null) qp['per_page'] = perPage.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('LostBreakageService.getList error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/$id');
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('LostBreakageService.getDetail error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAssetItems({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final qp = <String, String>{};
      if (search != null && search.isNotEmpty) qp['search'] = search;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/items').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('LostBreakageService.getAssetItems error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getItemUnits(int itemId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/item-units/$itemId');
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['units'] is List) {
          return (decoded['units'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('LostBreakageService.getItemUnits error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> searchApprovers(String query) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{'q': query};
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/approvers').replace(queryParameters: qp);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('LostBreakageService.searchApprovers error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> save(Map<String, dynamic> payload) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage');
      final resp = await http.post(uri,
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode(payload));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.save error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> submit(int headerId, List<int> approverIds) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/$headerId/submit');
      final resp = await http.post(uri,
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode({'approvers': approverIds}));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.submit error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> approve(int headerId, {String? note, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/$headerId/approve');
      final body = <String, dynamic>{
        'comments': note ?? '',
        if (note != null && note.isNotEmpty) 'note': note,
        if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
      };
      final resp = await http.post(uri,
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode(body));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.approve error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> reject(int headerId, {String? reason, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/$headerId/reject');
      final body = <String, dynamic>{
        'rejection_reason': reason ?? '',
        if (reason != null && reason.isNotEmpty) 'comments': reason,
        if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
      };
      final resp = await http.post(uri,
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode(body));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.reject error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> deleteHeader(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/$id');
      final resp = await http.delete(uri, headers: _headers(token));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.deleteHeader error: $e');
    }
    return null;
  }

  Future<String?> uploadPhoto(File file) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/approval-app/lost-breakage/upload-photo'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('photo', file.path));
      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true) return decoded['path'];
      }
    } catch (e) {
      print('LostBreakageService.uploadPhoto error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getReport({
    int? outletId,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{};
      if (outletId != null) qp['outlet_id'] = outletId.toString();
      if (status != null && status.isNotEmpty) qp['status'] = status;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
      if (page != null) qp['page'] = page.toString();
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage-report').replace(queryParameters: qp.isNotEmpty ? qp : null);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('LostBreakageService.getReport error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getReportDetails(int headerId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage-report/details/$headerId');
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['details'] is List) {
          return (decoded['details'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print('LostBreakageService.getReportDetails error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final uri = Uri.parse('$baseUrl/api/approval-app/outlets');
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        if (decoded is Map && decoded['outlets'] is List) return (decoded['outlets'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('LostBreakageService.getOutlets error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getFormMeta() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/form-meta');
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('LostBreakageService.getFormMeta error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getReplacementBacklog({
    String? search,
    int? ownerOutletId,
    int? outletId,
    String? type,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final qp = <String, String>{};
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (ownerOutletId != null) qp['owner_outlet_id'] = ownerOutletId.toString();
      if (outletId != null) qp['outlet_id'] = outletId.toString();
      if (type != null && type.isNotEmpty) qp['type'] = type;
      if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/replacement-backlog')
          .replace(queryParameters: qp.isNotEmpty ? qp : null);
      final resp = await http.get(uri, headers: _headers(token));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      print('LostBreakageService.getReplacementBacklog error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> preparePrFromBacklog(List<int> detailIds) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/lost-breakage/replacement-backlog/prepare-pr');
      final resp = await http.post(
        uri,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({'detail_ids': detailIds}),
      );
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.preparePrFromBacklog error: $e');
    }
    return null;
  }

  /// Catat penggantian parsial / identik (setelah dokumen APPROVED).
  /// Tidak dipakai di UI app — penggantian lewat Asset Replacement → PR Asset.
  Future<Map<String, dynamic>?> storeReplacement(
    int headerId,
    int detailId, {
    required double qtyReplaced,
    required int unitId,
    int? replacementItemId,
    String? note,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse(
          '$baseUrl/api/approval-app/lost-breakage/$headerId/details/$detailId/replacements');
      final body = <String, dynamic>{
        'qty_replaced': qtyReplaced,
        'unit_id': unitId,
        if (replacementItemId != null) 'replacement_item_id': replacementItemId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final resp = await http.post(
        uri,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      print('LostBreakageService.storeReplacement error: $e');
    }
    return null;
  }
}
