import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class PurchaseRequisitionService {
  static const String baseUrl = AuthService.baseUrl;

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  /// Shared multipart fields for create/update PR (attachments added separately).
  void _setPurchaseRequisitionFormFields(
    http.MultipartRequest request, {
    required String title,
    required String mode,
    required int divisionId,
    int? categoryId,
    int? outletId,
    int? ticketId,
    String? description,
    String? priority,
    String? currency,
    required List<Map<String, dynamic>> items,
    List<int>? approvers,
    List<int>? travelOutletIds,
    String? travelAgenda,
    String? travelNotes,
    num? kasbonAmount,
    int? kasbonTermin,
    String? kasbonReason,
  }) {
    double totalAmount = 0;
    if (mode == 'kasbon' && kasbonAmount != null) {
      totalAmount = kasbonAmount.toDouble();
    } else {
      for (final item in items) {
        totalAmount += (item['subtotal'] as num?)?.toDouble() ?? 0.0;
      }
    }

    request.fields['title'] = title;
    request.fields['mode'] = mode;
    request.fields['division_id'] = divisionId.toString();
    request.fields['amount'] = totalAmount.toString();
    if (categoryId != null) request.fields['category_id'] = categoryId.toString();
    if (outletId != null) request.fields['outlet_id'] = outletId.toString();
    if (ticketId != null) request.fields['ticket_id'] = ticketId.toString();
    if (description != null) request.fields['description'] = description;
    if (priority != null) request.fields['priority'] = priority;
    if (currency != null) request.fields['currency'] = currency;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      request.fields['items[$i][item_name]'] = item['item_name'] as String;

      final qty = item['qty'] ?? 0.0;
      final unitPrice = item['unit_price'] ?? 0.0;
      final subtotal = item['subtotal'] ?? 0.0;

      request.fields['items[$i][qty]'] = (qty as num).toString();
      request.fields['items[$i][unit]'] = item['unit'] as String? ?? '';
      request.fields['items[$i][unit_price]'] = (unitPrice as num).toString();
      request.fields['items[$i][subtotal]'] = (subtotal as num).toString();

      final itemOutletId = item['outlet_id'];
      final itemCategoryId = item['category_id'];

      if (itemOutletId != null) {
        final outletIdStr = itemOutletId is int
            ? itemOutletId.toString()
            : (itemOutletId is num ? itemOutletId.toInt().toString() : itemOutletId.toString());
        request.fields['items[$i][outlet_id]'] = outletIdStr;
      }
      if (itemCategoryId != null) {
        final categoryIdStr = itemCategoryId is int
            ? itemCategoryId.toString()
            : (itemCategoryId is num ? itemCategoryId.toInt().toString() : itemCategoryId.toString());
        request.fields['items[$i][category_id]'] = categoryIdStr;
      }

      if (item['item_type'] != null) {
        request.fields['items[$i][item_type]'] = item['item_type'] as String;
      }
      if (item['allowance_recipient_name'] != null) {
        request.fields['items[$i][allowance_recipient_name]'] = item['allowance_recipient_name'] as String;
      }
      if (item['allowance_account_number'] != null) {
        request.fields['items[$i][allowance_account_number]'] = item['allowance_account_number'] as String;
      }
      if (item['others_notes'] != null) {
        request.fields['items[$i][others_notes]'] = item['others_notes'] as String;
      }
    }

    if (approvers != null && approvers.isNotEmpty) {
      for (int i = 0; i < approvers.length; i++) {
        request.fields['approvers[$i]'] = approvers[i].toString();
      }
    }

    if (mode == 'travel_application') {
      if (travelOutletIds != null && travelOutletIds.isNotEmpty) {
        for (int i = 0; i < travelOutletIds.length; i++) {
          request.fields['travel_outlet_ids[$i]'] = travelOutletIds[i].toString();
        }
      }
      if (travelAgenda != null) request.fields['travel_agenda'] = travelAgenda;
      if (travelNotes != null) request.fields['travel_notes'] = travelNotes;
    }

    if (mode == 'kasbon') {
      if (kasbonAmount != null) {
        request.fields['kasbon_amount'] = kasbonAmount.round().toString();
      }
      if (kasbonTermin != null) {
        request.fields['kasbon_termin'] = kasbonTermin.toString();
      }
      if (kasbonReason != null) request.fields['kasbon_reason'] = kasbonReason;
    }
  }

  // Get list of purchase requisitions
  Future<Map<String, dynamic>?> getPurchaseRequisitions({
    String? search,
    String? status,
    String? division,
    String? category,
    String? outlet,
    String? isHeld,
    String? dateFrom,
    String? dateTo,
    int? perPage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status != 'all') queryParams['status'] = status;
      if (division != null && division != 'all') queryParams['division'] = division;
      if (category != null && category != 'all') queryParams['category'] = category;
      if (outlet != null && outlet != 'all') queryParams['outlet'] = outlet;
      if (isHeld != null && isHeld != 'all') queryParams['is_held'] = isHeld;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/purchase-requisitions').replace(
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
        final decoded = jsonDecode(response.body);
        print('PR List Response: ${response.statusCode}');
        print('PR List Data keys: ${decoded.keys}');
        return decoded;
      }

      print('PR List Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting purchase requisitions: $e');
      return null;
    }
  }

  // Get purchase requisition detail
  Future<Map<String, dynamic>?> getPurchaseRequisition(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('PR Detail Response: ${response.statusCode}');
        print('PR Detail Data keys: ${decoded.keys}');
        print('PR Detail purchaseRequisition keys: ${decoded['purchaseRequisition']?.keys}');
        return decoded;
      }

      print('PR Detail Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting purchase requisition: $e');
      return null;
    }
  }

  // Get approval details (for modal)
  Future<Map<String, dynamic>?> getApprovalDetails(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/purchase-requisitions/$id/approval-details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      return null;
    } catch (e) {
      print('Error getting approval details: $e');
      return null;
    }
  }

  // Get pending approvals
  Future<Map<String, dynamic>?> getPendingApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/purchase-requisitions/pending-approvals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('Error getting pending approvals: $e');
      return null;
    }
  }

  /// Get next PR number (preview) - same logic as web, from backend.
  Future<String?> getNextPrNumber({String mode = 'pr_ops'}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/next-number').replace(
        queryParameters: {'mode': mode},
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return data['next_number']?.toString();
        }
      }
      return null;
    } catch (e) {
      print('Error getNextPrNumber: $e');
      return null;
    }
  }

  // Create purchase requisition
  Future<Map<String, dynamic>> createPurchaseRequisition({
    required String title,
    required String mode,
    required int divisionId,
    int? categoryId,
    int? outletId,
    int? ticketId,
    String? description,
    String? priority,
    String? currency,
    required List<Map<String, dynamic>> items,
    List<int>? approvers,
    // For travel_application
    List<int>? travelOutletIds,
    String? travelAgenda,
    String? travelNotes,
    // For kasbon
    double? kasbonAmount,
    int? kasbonTermin,
    String? kasbonReason,
    // Attachments (for non-pr_ops/purchase_payment)
    List<File>? attachments,
    // For pr_ops/purchase_payment: attachments per outlet
    Map<int, List<File>>? outletAttachments,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      // Prepare form data
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      _setPurchaseRequisitionFormFields(
        request,
        title: title,
        mode: mode,
        divisionId: divisionId,
        categoryId: categoryId,
        outletId: outletId,
        ticketId: ticketId,
        description: description,
        priority: priority,
        currency: currency,
        items: items,
        approvers: approvers,
        travelOutletIds: travelOutletIds,
        travelAgenda: travelAgenda,
        travelNotes: travelNotes,
        kasbonAmount: kasbonAmount,
        kasbonTermin: kasbonTermin,
        kasbonReason: kasbonReason,
      );

      // Add attachments (for non-pr_ops/purchase_payment)
      if (attachments != null && attachments.isNotEmpty && mode != 'pr_ops' && mode != 'purchase_payment') {
        for (int i = 0; i < attachments.length; i++) {
          final file = attachments[i];
          final fileName = file.path.split('/').last;
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachments[$i]',
              file.path,
              filename: fileName,
            ),
          );
        }
      }
      
      // For pr_ops/purchase_payment: upload attachments per outlet after PR is created
      // Note: Attachments per outlet need to be uploaded separately after PR creation
      // This is handled in the create screen after successful PR creation

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to create purchase requisition'};
      }
    } catch (e) {
      print('Error creating purchase requisition: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Update purchase requisition
  Future<Map<String, dynamic>> updatePurchaseRequisition({
    required int id,
    required String title,
    required String mode,
    required int divisionId,
    int? categoryId,
    int? outletId,
    int? ticketId,
    String? description,
    String? priority,
    String? currency,
    required List<Map<String, dynamic>> items,
    List<int>? approvers,
    // For travel_application
    List<int>? travelOutletIds,
    String? travelAgenda,
    String? travelNotes,
    // For kasbon
    double? kasbonAmount,
    int? kasbonTermin,
    String? kasbonReason,
    // Attachments
    List<File>? attachments,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['_method'] = 'PUT';

      _setPurchaseRequisitionFormFields(
        request,
        title: title,
        mode: mode,
        divisionId: divisionId,
        categoryId: categoryId,
        outletId: outletId,
        ticketId: ticketId,
        description: description,
        priority: priority,
        currency: currency,
        items: items,
        approvers: approvers,
        travelOutletIds: travelOutletIds,
        travelAgenda: travelAgenda,
        travelNotes: travelNotes,
        kasbonAmount: kasbonAmount,
        kasbonTermin: kasbonTermin,
        kasbonReason: kasbonReason,
      );

      if (attachments != null && attachments.isNotEmpty && mode != 'pr_ops' && mode != 'purchase_payment') {
        for (int i = 0; i < attachments.length; i++) {
          final file = attachments[i];
          final fileName = file.path.split('/').last;
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachments[$i]',
              file.path,
              filename: fileName,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to update purchase requisition'};
      }
    } catch (e) {
      print('Error updating purchase requisition: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Submit purchase requisition
  Future<Map<String, dynamic>> submitPurchaseRequisition(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Purchase requisition submitted successfully'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to submit purchase requisition'};
      }
    } catch (e) {
      print('Error submitting purchase requisition: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Approve purchase requisition
  Future<Map<String, dynamic>> approvePurchaseRequisition({
    required int id,
    String? comments,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/purchase-requisitions/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': true,
          if (comments != null) 'comments': comments,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Purchase requisition approved'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to approve purchase requisition'};
      }
    } catch (e) {
      print('Error approving purchase requisition: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Reject purchase requisition
  Future<Map<String, dynamic>> rejectPurchaseRequisition({
    required int id,
    required String rejectionReason,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'rejection_reason': rejectionReason,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Purchase requisition rejected'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to reject purchase requisition'};
      }
    } catch (e) {
      print('Error rejecting purchase requisition: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Get categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['categories'] != null) {
          return List<Map<String, dynamic>>.from(data['categories']);
        }
      }

      return [];
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  // Get divisions
  Future<List<Map<String, dynamic>>> getDivisions() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('❌ No token for getDivisions');
        return [];
      }

      print('🔑 Token exists: ${token.substring(0, 20)}...');

      // Use approval-app endpoint (with auth middleware)
      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/divisions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Divisions API Status: ${response.statusCode}');

      print('📡 Divisions API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📡 Divisions Data: ${data}');
        
        // Divisions API returns direct array (like outlets)
        if (data is List) {
          final divisions = List<Map<String, dynamic>>.from(data);
          print('✅ Loaded ${divisions.length} divisions (direct array)');
          return divisions;
        }
        
        // Try wrapped format (just in case)
        if (data is Map) {
          if (data['success'] == true) {
            if (data['data'] != null) {
              final divisions = List<Map<String, dynamic>>.from(data['data']);
              print('✅ Loaded ${divisions.length} divisions (wrapped in data)');
              return divisions;
            } else if (data['divisions'] != null) {
              final divisions = List<Map<String, dynamic>>.from(data['divisions']);
              print('✅ Loaded ${divisions.length} divisions (wrapped in divisions)');
              return divisions;
            }
          }
        }
      } else if (response.statusCode == 401) {
        print('❌ Unauthenticated - Token may be expired or invalid');
        print('❌ Response: ${response.body}');
      } else {
        print('❌ Divisions API Error: ${response.statusCode} - ${response.body}');
      }

      return [];
    } catch (e) {
      print('❌ Error getting divisions: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get outlets
  Future<List<Map<String, dynamic>>> getOutlets() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('❌ No token for getOutlets');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/outlets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Outlets API Status: ${response.statusCode}');
      print('📡 Outlets API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📡 Outlets Data: ${data}');
        
        // Outlets API returns direct array (not wrapped)
        if (data is List) {
          final outlets = List<Map<String, dynamic>>.from(data);
          print('✅ Loaded ${outlets.length} outlets (direct array)');
          return outlets;
        }
        
        // Check wrapped format (just in case)
        if (data is Map) {
          if (data['success'] == true) {
            if (data['data'] != null) {
              final outlets = List<Map<String, dynamic>>.from(data['data']);
              print('✅ Loaded ${outlets.length} outlets (wrapped)');
              return outlets;
            } else if (data['outlets'] != null) {
              final outlets = List<Map<String, dynamic>>.from(data['outlets']);
              print('✅ Loaded ${outlets.length} outlets (wrapped)');
              return outlets;
            }
          }
        }
      } else {
        print('❌ Outlets API Error: ${response.statusCode} - ${response.body}');
      }

      return [];
    } catch (e) {
      print('❌ Error getting outlets: $e');
      return [];
    }
  }

  // Get approvers (search)
  Future<List<Map<String, dynamic>>> getApprovers({String? search}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/approvers').replace(
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
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] != null) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
      }

      return [];
    } catch (e) {
      print('Error getting approvers: $e');
      return [];
    }
  }

  // Get budget info
  Future<Map<String, dynamic>?> getBudgetInfo({
    required int categoryId,
    int? outletId,
    double? currentAmount,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'category_id': categoryId.toString(),
      };
      if (outletId != null) queryParams['outlet_id'] = outletId.toString();
      if (currentAmount != null) queryParams['current_amount'] = currentAmount.toString();

      final uri = Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/budget-info').replace(
        queryParameters: queryParams,
      );

      print('📡 Budget Info API Call: $uri');
      print('📡 Budget Info Query Params: $queryParams');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Budget Info API Status: ${response.statusCode}');
      print('📡 Budget Info API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📡 Budget Info Parsed Data: $data');
        
        // Handle both wrapped and direct response formats
        if (data['success'] == true) {
          // If data is wrapped in 'data' key, return it
          if (data['data'] != null) {
            print('✅ Budget Info: Returning data from data key');
            return data['data'] as Map<String, dynamic>;
          }
          // Otherwise return the whole response (but remove success key)
          final result = Map<String, dynamic>.from(data);
          result.remove('success');
          print('✅ Budget Info: Returning whole response (without success key)');
          return result;
        } else {
          print('❌ Budget Info: success is false');
        }
      }

      print('❌ Budget Info Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error getting budget info: $e');
      return null;
    }
  }

  // Add comment
  Future<Map<String, dynamic>> addComment({
    required int id,
    required String comment,
    bool isInternal = false,
    File? attachment,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id/comments'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['comment'] = comment;
      // Laravel boolean validation: send "1" for true, "0" for false
      // Laravel will convert "1" to true and "0" to false for boolean validation
      if (isInternal) {
        request.fields['is_internal'] = '1';
      } else {
        request.fields['is_internal'] = '0';
      }

      if (attachment != null) {
        final fileName = attachment.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: fileName,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to add comment'};
      }
    } catch (e) {
      print('Error adding comment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Delete comment
  Future<Map<String, dynamic>> deleteComment({
    required int id,
    required int commentId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'Comment deleted successfully'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to delete comment'};
      }
    } catch (e) {
      print('Error deleting comment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Get comments
  Future<List<Map<String, dynamic>>> getComments(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id/comments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Comments API Response: ${data.keys}');
        if (data['success'] == true && data['data'] != null) {
          final comments = List<Map<String, dynamic>>.from(data['data']);
          print('Comments API: Found ${comments.length} comments');
          return comments;
        } else {
          print('Comments API: success=${data['success']}, data=${data['data']}');
        }
      } else {
        print('Comments API: Status code ${response.statusCode}');
      }

      return [];
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Check kasbon period and user per outlet
  Future<Map<String, dynamic>> checkKasbonPeriod({
    required int outletId,
    int? excludeId, // For edit mode, exclude current PR
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'exists': false, 'message': 'No authentication token'};
      }

      // Periode kasbon sama dengan web: bisa ajukan hanya tanggal 10–20 bulan berjalan
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      final startDate = DateTime(currentYear, currentMonth, 10);
      final endDate = DateTime(currentYear, currentMonth, 20);
      
      final queryParams = <String, String>{
        'outlet_id': outletId.toString(),
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
      };
      
      if (excludeId != null) {
        queryParams['exclude_id'] = excludeId.toString();
      }

      final uri = Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/check-kasbon-period').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      return {'exists': false, 'message': 'Failed to check kasbon period'};
    } catch (e) {
      print('Error checking kasbon period: $e');
      return {'exists': false, 'message': 'Error: $e'};
    }
  }

  // Upload attachment (for pr_ops/purchase_payment - per outlet)
  Future<Map<String, dynamic>> uploadAttachment({
    required int id,
    required File file,
    int? outletId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final uploadUrl = '$baseUrl/api/approval-app/purchase-requisitions/$id/attachments';
      print('📤 Uploading attachment to: $uploadUrl');
      print('📤 File path: ${file.path}');
      print('📤 Outlet ID: $outletId');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(uploadUrl),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      final fileName = file.path.split('/').last;
      print('📤 File name: $fileName');
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',  // Changed from 'attachment' to 'file' to match backend validation
          file.path,
          filename: fileName,
        ),
      );

      if (outletId != null) {
        request.fields['outlet_id'] = outletId.toString();
        print('📤 Outlet ID field added: $outletId');
      }

      print('📤 Sending upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📤 Upload response status: ${response.statusCode}');
      print('📤 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Attachment uploaded successfully');
        print('✅ Response data: $data');
        
        // Check if file_path is returned and log it
        // Backend response structure: {success: true, message: "...", attachment: {...}}
        String? filePath;
        if (data['attachment'] != null) {
          final attachment = data['attachment'];
          if (attachment is Map) {
            filePath = attachment['file_path'] ?? attachment['path'];
            print('✅ Attachment data: ${attachment.keys}');
          }
        } else if (data['data'] != null) {
          final responseData = data['data'];
          if (responseData is Map) {
            if (responseData['file_path'] != null) {
              filePath = responseData['file_path'];
            } else if (responseData['attachment'] != null && responseData['attachment'] is Map) {
              filePath = responseData['attachment']['file_path'] ?? responseData['attachment']['path'];
            }
          }
        }
        
        if (filePath != null && filePath.isNotEmpty) {
          print('✅ File path from backend: $filePath');
          // Backend returns relative path like "purchase_requisitions/attachments/filename.jpg"
          // Frontend needs to construct full URL: storageUrl + /storage/ + file_path
          final storagePath = filePath.startsWith('/') 
              ? filePath 
              : (filePath.startsWith('storage/') ? '/$filePath' : '/storage/$filePath');
          print('✅ Full storage URL: ${AuthService.storageUrl}$storagePath');
        } else {
          print('⚠️ WARNING: File path not found in response!');
          print('⚠️ Response structure: ${data.keys}');
          if (data['attachment'] != null) {
            print('⚠️ Attachment object: ${data['attachment']}');
            if (data['attachment'] is Map) {
              print('⚠️ Attachment keys: ${(data['attachment'] as Map).keys}');
            }
          }
          if (data['data'] != null && data['data'] is Map) {
            print('⚠️ Data keys: ${(data['data'] as Map).keys}');
          }
          print('⚠️ This might cause issues when viewing the attachment!');
        }
        
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        print('❌ Upload failed: ${error['message']}');
        return {'success': false, 'message': error['message'] ?? 'Failed to upload attachment'};
      }
    } catch (e, stackTrace) {
      print('❌ Error uploading attachment: $e');
      print('❌ Stack trace: $stackTrace');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Delete purchase requisition
  Future<Map<String, dynamic>> deletePurchaseRequisition(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      // Use POST with _method=DELETE for Laravel method spoofing (similar to update)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$id'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['_method'] = 'DELETE';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Delete PR Response Status: ${response.statusCode}');
      print('Delete PR Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Try to parse JSON response
        try {
          final data = jsonDecode(response.body);
          return {'success': true, 'message': data['message'] ?? 'Purchase Requisition deleted successfully'};
        } catch (e) {
          // If response is empty or not JSON, consider it success for 200/204
          return {'success': true, 'message': 'Purchase Requisition deleted successfully'};
        }
      } else {
        // Try to parse error response as JSON
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'message': error['message'] ?? 'Failed to delete purchase requisition'};
        } catch (e) {
          // If response is HTML or not JSON, return generic error
          if (response.body.contains('<!DOCTYPE') || response.body.contains('<html')) {
            return {'success': false, 'message': 'Server error: Invalid response format. Please try again.'};
          }
          return {'success': false, 'message': 'Failed to delete purchase requisition (Status: ${response.statusCode})'};
        }
      }
    } catch (e) {
      print('Error deleting purchase requisition: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

