import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee_onboarding_models.dart';
import 'auth_service.dart';

class EmployeeOnboardingService {
  static String get _prefix => '${AuthService.baseUrl}/api/approval-app/employee-onboarding';

  Future<String?> _token() async => AuthService().getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<List<EoListItem>> fetchMyTasks({int page = 1}) async {
    final token = await _token();
    if (token == null) return [];

    final uri = Uri.parse('$_prefix/my-tasks').replace(queryParameters: {'page': '$page', 'per_page': '20'});
    final res = await http.get(uri, headers: _headers(token));
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != true) return [];

    return (decoded['records'] as List? ?? [])
        .map((e) => EoListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>?> getDetail(int id) async {
    final token = await _token();
    if (token == null) return null;

    final res = await http.get(Uri.parse('$_prefix/$id'), headers: _headers(token));
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic> && decoded['success'] == true) return decoded;
    return null;
  }

  Future<Map<String, dynamic>> updateItems({required int id, required List<Map<String, dynamic>> items}) async {
    final token = await _token();
    if (token == null) return {'success': false, 'message': 'Sesi habis.'};

    final res = await http.post(
      Uri.parse('$_prefix/$id/items'),
      headers: _headers(token),
      body: jsonEncode({'items': items}),
    );
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'success': false, 'message': 'Gagal menyimpan.'};
  }

  Future<Map<String, dynamic>> submitWeek({required int id, required int weekNumber, List<int>? approvers}) async {
    final token = await _token();
    if (token == null) return {'success': false, 'message': 'Sesi habis.'};

    final Map<String, dynamic> body = {'week_number': weekNumber};
    if (approvers != null && approvers.isNotEmpty) body['approvers'] = approvers;

    final res = await http.post(
      Uri.parse('$_prefix/$id/submit-week'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'success': false, 'message': 'Gagal submit.'};
  }

  Future<List<EoPendingApproval>> getPendingApprovals() async {
    final token = await _token();
    if (token == null) return [];

    final res = await http.get(Uri.parse('$_prefix/pending-approvals'), headers: _headers(token));
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != true) return [];

    return (decoded['data'] as List? ?? [])
        .map((e) => EoPendingApproval.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> approve({required int id, required int weekNumber, required String action, String comments = ''}) async {
    final token = await _token();
    if (token == null) return {'success': false, 'message': 'Sesi habis.'};

    final res = await http.post(
      Uri.parse('$_prefix/$id/approve'),
      headers: _headers(token),
      body: jsonEncode({'week_number': weekNumber, 'action': action, 'comments': comments}),
    );
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'success': false, 'message': 'Gagal approval.'};
  }
}
