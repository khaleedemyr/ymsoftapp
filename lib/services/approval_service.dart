import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/approval_models.dart';

class ApprovalService {
  static const String baseUrl = AuthService.baseUrl;
  
  // Cache for raw JSON responses (for caching in home screen)
  final Map<String, List<dynamic>> _rawJsonCache = {};

  Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // Public method to get token (for use in detail screens)
  Future<String?> getToken() async {
    return await _getToken();
  }
  
  // Get raw JSON cache (for home screen caching)
  Map<String, List<dynamic>> getRawJsonCache() {
    return Map<String, List<dynamic>>.from(_rawJsonCache);
  }

  // Check if current user is superadmin (id_role = '5af56935b011a')
  Future<bool> _isSuperadmin() async {
    try {
      final authService = AuthService();
      final userData = await authService.getUserData();
      if (userData != null && userData['id_role'] == '5af56935b011a') {
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking superadmin status: $e');
      return false;
    }
  }

  // Get Pending Purchase Requisition Approvals
  Future<List<PurchaseRequisitionApproval>> getPendingPrApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('PR Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/purchase-requisitions/pending-approvals';
      print('PR Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('PR Approvals: Status code = ${response.statusCode}');
      print('PR Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('PR Approvals: Parsed data = $data');
        if (data['success'] == true && data['purchase_requisitions'] != null) {
          final List<dynamic> approvalsJson = data['purchase_requisitions'];
          // Store raw JSON for caching
          _rawJsonCache['pr'] = approvalsJson;
          print('PR Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => PurchaseRequisitionApproval.fromJson(json))
              .toList();
        } else {
          print('PR Approvals: success=false or purchase_requisitions is null');
        }
      } else {
        print('PR Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading PR approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Purchase Order Ops Approvals
  Future<List<PurchaseOrderOpsApproval>> getPendingPoOpsApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('PO Ops Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/po-ops/pending-approvals';
      print('PO Ops Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('PO Ops Approvals: Status code = ${response.statusCode}');
      print('PO Ops Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('PO Ops Approvals: Parsed data = $data');
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> approvalsJson = data['data'];
          // Store raw JSON for caching
          _rawJsonCache['po_ops'] = approvalsJson;
          print('PO Ops Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => PurchaseOrderOpsApproval.fromJson(json))
              .toList();
        } else {
          print('PO Ops Approvals: success=false or data is null');
        }
      } else {
        print('PO Ops Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading PO Ops approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Leave Approvals
  Future<List<LeaveApproval>> getPendingLeaveApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Leave Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/approval/pending';
      print('Leave Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Leave Approvals: Status code = ${response.statusCode}');
      print('Leave Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Leave Approvals: Parsed data = $data');
        if (data['success'] == true && data['approvals'] != null) {
          final List<dynamic> approvalsJson = data['approvals'];
          final isSuperadmin = await _isSuperadmin();
          
          // Filter based on user role
          final filtered = approvalsJson.where((a) {
            final status = (a['status'] ?? a['approval_status'] ?? '').toString().toLowerCase();
            if (isSuperadmin) {
              // Superadmin sees all approvals that are not completed
              if (status.isEmpty) return true;
              return !['approved', 'rejected', 'completed', 'cancelled'].contains(status);
            } else {
              // Regular users only see pending, awaiting, or waiting
              if (status.isEmpty) return true;
              return status == 'pending' || status == 'awaiting' || status == 'waiting';
            }
          }).toList();
          print('Leave Approvals: Found ${filtered.length} approvals (filtered from ${approvalsJson.length}, superadmin: $isSuperadmin)');
          return filtered
              .map((json) => LeaveApproval.fromJson(json))
              .toList();
        } else {
          print('Leave Approvals: success=false or approvals is null');
        }
      } else {
        print('Leave Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Leave approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get PR Approval Details
  Future<Map<String, dynamic>?> getPrApprovalDetails(int prId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$prId/approval-details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Error loading PR approval details: $e');
      return null;
    }
  }

  // Add Comment to PR
  Future<Map<String, dynamic>> addPrComment(int prId, String comment, {bool isInternal = false}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$prId/comments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'comment': comment,
          'is_internal': isInternal,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to add comment',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get PO Ops Approval Details
  Future<Map<String, dynamic>?> getPoOpsApprovalDetails(int poId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/po-ops/$poId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // PO Ops endpoint returns data with 'po', 'budgetInfo', and 'itemsBudgetInfo' keys
        if (data['po'] != null) {
          Map<String, dynamic> poData = Map<String, dynamic>.from(data['po']);
          
          // Load budget info if available
          Map<String, dynamic>? budgetInfo;
          if (data['budgetInfo'] != null) {
            budgetInfo = data['budgetInfo'];
            poData['budget_info'] = budgetInfo;
          }
          
          // Load itemsBudgetInfo if available (per outlet+category budget info)
          Map<String, dynamic>? itemsBudgetInfo;
          if (data['itemsBudgetInfo'] != null) {
            itemsBudgetInfo = data['itemsBudgetInfo'];
            poData['items_budget_info'] = itemsBudgetInfo;
            print('ItemsBudgetInfo loaded: ${data['itemsBudgetInfo']}');
          }
          
          // Also load budget info if PO has source PR (fallback for old structure)
          if (data['po']?['source_type'] == 'purchase_requisition_ops' && 
              data['po']?['source_id'] != null && budgetInfo == null) {
            try {
              final budgetResponse = await http.get(
                Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/${data['po']['source_id']}/approval-details'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                },
              );
              if (budgetResponse.statusCode == 200) {
                final budgetData = jsonDecode(budgetResponse.body);
                if (budgetData['success'] == true && budgetData['budget_info'] != null) {
                  budgetInfo = budgetData['budget_info'];
                  poData['budget_info'] = budgetInfo;
                }
              }
            } catch (e) {
              print('Error loading budget info: $e');
            }
          }
          
          // Return with 'po' key to match expected structure
          return {
            'po': poData,
            'budget_info': budgetInfo,
            'items_budget_info': itemsBudgetInfo,
          };
        }
      }
      return null;
    } catch (e) {
      print('Error loading PO Ops approval details: $e');
      return null;
    }
  }

  // Approve Purchase Requisition
  Future<Map<String, dynamic>> approvePr(int prId, {String? comment}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$prId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: comment != null ? jsonEncode({'comment': comment}) : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve PR',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Purchase Requisition
  Future<Map<String, dynamic>> rejectPr(int prId, {String? comment, String? reason}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/purchase-requisitions/$prId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'rejection_reason': reason ?? comment ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject PR',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Purchase Order Ops
  Future<Map<String, dynamic>> approvePoOps(int poId, {String? comment}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/po-ops/$poId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': true,
          'comments': comment ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve PO',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Purchase Order Ops
  Future<Map<String, dynamic>> rejectPoOps(int poId, {String? comment, String? reason}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/po-ops/$poId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': false,
          'comments': reason ?? comment ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject PO',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Leave
  Future<Map<String, dynamic>> approveLeave(int leaveId, {String? comment, String? notes}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support both 'notes' and 'comment' parameters (web uses 'notes' or 'comment')
      final notesValue = notes ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/approval/$leaveId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (notesValue != null) 'notes': notesValue,
          if (comment != null && notes == null) 'comment': comment, // Also send as comment for compatibility
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve leave',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Leave
  Future<Map<String, dynamic>> rejectLeave(int leaveId, {String? comment, String? reason}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/approval/$leaveId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (comment != null) 'comment': comment,
          if (reason != null) 'reason': reason,
          // Also send as 'notes' for compatibility
          if (comment != null) 'notes': comment,
          if (reason != null && comment == null) 'notes': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject leave',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve HRD Leave
  Future<Map<String, dynamic>> approveHrdLeave(int leaveId, {String? notes, String? comment}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support both 'notes' and 'comment' parameters (web uses 'notes')
      final notesValue = notes ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/approval/$leaveId/hrd-approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (notesValue != null) 'notes': notesValue,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve HRD leave',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject HRD Leave
  Future<Map<String, dynamic>> rejectHrdLeave(int leaveId, {String? notes, String? comment, String? reason}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'notes', 'comment', and 'reason' parameters (web uses 'notes' and requires it)
      final notesValue = notes ?? comment ?? reason;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/approval/$leaveId/hrd-reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (notesValue != null) 'notes': notesValue,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject HRD leave',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get Pending Category Cost Approvals
  Future<List<CategoryCostApproval>> getPendingCategoryCostApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Category Cost Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/outlet-internal-use-waste/approvals/pending';
      print('Category Cost Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Category Cost Approvals: Status code = ${response.statusCode}');
      print('Category Cost Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Category Cost Approvals: Parsed data = $data');
        if (data['success'] == true && data['headers'] != null) {
          final List<dynamic> approvalsJson = data['headers'];
          print('Category Cost Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => CategoryCostApproval.fromJson(json))
              .toList();
        } else {
          print('Category Cost Approvals: success=false or headers is null');
        }
      } else {
        print('Category Cost Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Category Cost approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Stock Adjustment Approvals
  Future<List<StockAdjustmentApproval>> getPendingStockAdjustmentApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Stock Adjustment Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/outlet-food-inventory-adjustment/pending-approvals';
      print('Stock Adjustment Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Stock Adjustment Approvals: Status code = ${response.statusCode}');
      print('Stock Adjustment Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Stock Adjustment Approvals: Parsed data = $data');
        if (data['success'] == true && data['adjustments'] != null) {
          final List<dynamic> approvalsJson = data['adjustments'];
          print('Stock Adjustment Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => StockAdjustmentApproval.fromJson(json))
              .toList();
        } else {
          print('Stock Adjustment Approvals: success=false or adjustments is null');
        }
      } else {
        print('Stock Adjustment Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Stock Adjustment approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Outlet Transfer Approvals
  Future<List<OutletTransferApproval>> getPendingOutletTransferApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Outlet Transfer Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/outlet-transfers/pending-approvals';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['outlet_transfers'] != null) {
          final List<dynamic> approvalsJson = data['outlet_transfers'];
          _rawJsonCache['outlet_transfer'] = approvalsJson;
          return approvalsJson
              .map((json) => OutletTransferApproval.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error loading Outlet Transfer approvals: $e');
      return [];
    }
  }

  // Get Pending Stock Opname Approvals
  Future<List<StockOpnameApproval>> getPendingStockOpnameApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final url = '$baseUrl/api/approval-app/stock-opnames/pending-approvals';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['stock_opnames'] != null) {
          final List<dynamic> approvalsJson = data['stock_opnames'];
          _rawJsonCache['stock_opnames'] = approvalsJson;
          return approvalsJson
              .map((json) => StockOpnameApproval.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error loading Stock Opname approvals: $e');
      return [];
    }
  }

  Future<List<WarehouseStockOpnameApproval>> getPendingWarehouseStockOpnameApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final url = '$baseUrl/api/approval-app/warehouse-stock-opnames/pending-approvals';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['warehouse_stock_opnames'] != null) {
          final List<dynamic> approvalsJson = data['warehouse_stock_opnames'];
          _rawJsonCache['warehouse_stock_opnames'] = approvalsJson;
          return approvalsJson
              .map((json) => WarehouseStockOpnameApproval.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error loading Warehouse Stock Opname approvals: $e');
      return [];
    }
  }

  Future<List<CctvAccessRequestApproval>> getPendingCctvAccessRequestApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final url = '$baseUrl/api/approval-app/cctv-access-requests/pending-approvals';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'] is List ? data['data'] as List<dynamic> : [];
          _rawJsonCache['cctv_access_requests'] = list;
          return list
              .map((json) => CctvAccessRequestApproval.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error loading CCTV access request approvals: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCctvAccessRequestDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/cctv-access-requests/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data'] as Map);
        }
      }
      return null;
    } catch (e) {
      print('Error loading CCTV access request detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> approveCctvAccessRequest(int id, {String? approvalNotes}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis. Silakan login kembali.'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/cctv-access-requests/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approval_notes': approvalNotes,
        }),
      );

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'success': false, 'message': 'Respons server tidak valid (${response.statusCode})'};
      }
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Gagal menyetujui permintaan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> rejectCctvAccessRequest(int id, String approvalNotes) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Sesi habis. Silakan login kembali.'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/cctv-access-requests/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approval_notes': approvalNotes,
        }),
      );

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'success': false, 'message': 'Respons server tidak valid (${response.statusCode})'};
      }
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Gagal menolak permintaan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Returns { 'adjustments': List<WarehouseStockAdjustmentApproval>, 'error': String? }
  Future<Map<String, dynamic>> getPendingWarehouseStockAdjustmentApprovalsWithError() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'adjustments': <WarehouseStockAdjustmentApproval>[], 'error': 'Sesi habis. Silakan login kembali.'};
      }

      final url = '$baseUrl/api/approval-app/food-inventory-adjustment/pending-approvals';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['adjustments'] != null) {
          final List<dynamic> list = data['adjustments'];
          final adjustments = list
              .map((json) => WarehouseStockAdjustmentApproval.fromJson(json as Map<String, dynamic>))
              .toList();
          return {'adjustments': adjustments, 'error': null};
        }
        return {'adjustments': <WarehouseStockAdjustmentApproval>[], 'error': null};
      }
      if (response.statusCode == 401) {
        return {'adjustments': <WarehouseStockAdjustmentApproval>[], 'error': 'Sesi habis. Silakan login kembali.'};
      }
      String errMsg = 'Gagal memuat data';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) errMsg = err['error'].toString();
      } catch (_) {}
      return {'adjustments': <WarehouseStockAdjustmentApproval>[], 'error': errMsg};
    } catch (e) {
      print('Error loading Warehouse Stock Adjustment approvals: $e');
      return {'adjustments': <WarehouseStockAdjustmentApproval>[], 'error': 'Koneksi gagal: $e'};
    }
  }

  // Get Pending Warehouse Stock Adjustment (Food Inventory Adjustment) Approvals
  Future<List<WarehouseStockAdjustmentApproval>> getPendingWarehouseStockAdjustmentApprovals() async {
    final result = await getPendingWarehouseStockAdjustmentApprovalsWithError();
    return List<WarehouseStockAdjustmentApproval>.from(result['adjustments'] as List? ?? []);
  }

  // Get Warehouse Stock Adjustment approval details
  Future<Map<String, dynamic>?> getWarehouseStockAdjustmentApprovalDetails(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/approval-app/food-inventory-adjustment/$id/approval-details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      print('Error loading Warehouse Stock Adjustment details: $e');
      return null;
    }
  }

  // Approve Warehouse Stock Adjustment
  Future<Map<String, dynamic>> approveWarehouseStockAdjustment(int id, {String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-inventory-adjustment/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({if (note != null && note.isNotEmpty) 'note': note}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['error'] ?? err['message'] ?? 'Gagal approve'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Reject Warehouse Stock Adjustment
  Future<Map<String, dynamic>> rejectWarehouseStockAdjustment(int id, {String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-inventory-adjustment/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({if (note != null && note.isNotEmpty) 'note': note}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : {'success': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['error'] ?? err['message'] ?? 'Gagal reject'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Get Pending Contra Bon Approvals
  Future<List<ContraBonApproval>> getPendingContraBonApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Contra Bon Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/contra-bon/pending-approvals';
      print('Contra Bon Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Contra Bon Approvals: Status code = ${response.statusCode}');
      print('Contra Bon Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Contra Bon Approvals: Parsed data = $data');
        if (data['success'] == true && data['contra_bons'] != null) {
          final List<dynamic> approvalsJson = data['contra_bons'];
          print('Contra Bon Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => ContraBonApproval.fromJson(json))
              .toList();
        } else {
          print('Contra Bon Approvals: success=false or contra_bons is null');
        }
      } else {
        print('Contra Bon Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Contra Bon approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Employee Movement Approvals
  Future<List<EmployeeMovementApproval>> getPendingMovementApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Movement Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/employee-movements/pending-approvals?limit=100';
      print('Movement Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Movement Approvals: Status code = ${response.statusCode}');
      print('Movement Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Movement Approvals: Parsed data = $data');
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> approvalsJson = data['data'];
          print('Movement Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => EmployeeMovementApproval.fromJson(json))
              .toList();
        } else {
          print('Movement Approvals: success=false or data is null');
        }
      } else {
        print('Movement Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Movement approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Coaching Approvals
  Future<List<CoachingApproval>> getPendingCoachingApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Coaching Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/coaching/pending-approvals';
      print('Coaching Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Coaching Approvals: Status code = ${response.statusCode}');
      print('Coaching Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Coaching Approvals: Parsed data = $data');
        if (data['success'] == true && data['pending_approvals'] != null) {
          final List<dynamic> approvalsJson = data['pending_approvals'];
          print('Coaching Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => CoachingApproval.fromJson(json))
              .toList();
        } else {
          print('Coaching Approvals: success=false or pending_approvals is null');
        }
      } else {
        print('Coaching Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Coaching approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Correction Approvals
  Future<List<CorrectionApproval>> getPendingCorrectionApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Correction Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/schedule-attendance-correction/pending-approvals';
      print('Correction Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Correction Approvals: Status code = ${response.statusCode}');
      print('Correction Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Correction Approvals: Parsed data = $data');
        if (data['success'] == true && data['approvals'] != null) {
          final List<dynamic> approvalsJson = data['approvals'];
          print('Correction Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => CorrectionApproval.fromJson(json))
              .toList();
        } else {
          print('Correction Approvals: success=false or approvals is null. Data: $data');
        }
      } else if (response.statusCode == 403) {
        // Check if user is superadmin - if so, this shouldn't happen, but log it
        final isSuperadmin = await _isSuperadmin();
        print('Correction Approvals: 403 Forbidden. Is superadmin: $isSuperadmin');
        if (isSuperadmin) {
          print('Correction Approvals: Superadmin got 403 - backend may need fix');
        }
      } else {
        print('Correction Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Correction approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending HRD Approvals
  Future<List<LeaveApproval>> getPendingHrdApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('HRD Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/approval/pending-hrd';
      print('HRD Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('HRD Approvals: Status code = ${response.statusCode}');
      print('HRD Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('HRD Approvals: Parsed data = $data');
        if (data['success'] == true && data['approvals'] != null) {
          final List<dynamic> approvalsJson = data['approvals'];
          final isSuperadmin = await _isSuperadmin();
          
          // Filter based on user role
          final filtered = approvalsJson.where((a) {
            final status = (a['status'] ?? a['approval_status'] ?? '').toString().toLowerCase();
            if (isSuperadmin) {
              // Superadmin sees all approvals that are not completed
              if (status.isEmpty) return true;
              return !['approved', 'rejected', 'completed', 'cancelled'].contains(status);
            } else {
              // Regular users only see pending, awaiting, or waiting
              if (status.isEmpty) return true;
              return status == 'pending' || status == 'awaiting' || status == 'waiting';
            }
          }).toList();
          print('HRD Approvals: Found ${filtered.length} approvals (filtered from ${approvalsJson.length}, superadmin: $isSuperadmin)');
          return filtered
              .map((json) => LeaveApproval.fromJson(json))
              .toList();
        } else {
          print('HRD Approvals: success=false or approvals is null');
        }
      } else {
        print('HRD Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading HRD approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Approve Category Cost
  Future<Map<String, dynamic>> approveCategoryCost(int id, {String? comment, String? note, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'notes' parameters (web uses 'note', 'comment', or 'notes')
      final noteValue = note ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
          if (noteValue != null) 'note': noteValue,
          if (comment != null && note == null) 'comment': comment, // Also send as 'comment' for compatibility
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Category Cost
  Future<Map<String, dynamic>> rejectCategoryCost(int id, {String? comment, String? reason, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'rejection_reason', 'reason', and 'comment' parameters (web uses 'rejection_reason')
      final rejectionReason = reason ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-internal-use-waste/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
          if (rejectionReason != null) 'reason': rejectionReason, // Also send as 'reason' for compatibility
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Stock Adjustment
  Future<Map<String, dynamic>> approveStockAdjustment(int id, {String? comment, String? note, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'notes' parameters (web uses 'note', 'comment', or 'notes')
      final noteValue = note ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustment/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
          if (noteValue != null) 'note': noteValue,
          if (comment != null && note == null) 'comment': comment, // Also send as 'comment' for compatibility
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Stock Adjustment
  Future<Map<String, dynamic>> rejectStockAdjustment(int id, {String? comment, String? reason, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'rejection_reason', 'reason', and 'comment' parameters (web uses 'rejection_reason' as primary)
      final rejectionReason = reason ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/outlet-food-inventory-adjustment/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
          if (rejectionReason != null) 'reason': rejectionReason, // Also send as 'reason' for compatibility
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Contra Bon
  Future<Map<String, dynamic>> approveContraBon(int id, {String? comment, String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note' and 'comment' parameters (web uses 'note')
      final noteValue = note ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/contra-bon/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': true, // Contra Bon uses approved boolean (default true)
          if (noteValue != null) 'note': noteValue, // Contra Bon uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Contra Bon
  Future<Map<String, dynamic>> rejectContraBon(int id, {String? comment, String? reason, String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'reason' parameters (web uses 'note')
      final noteValue = note ?? reason ?? comment;

      // Contra Bon reject uses the same approve endpoint with approved: false (same as web)
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/contra-bon/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': false, // Contra Bon reject uses approved: false
          if (noteValue != null) 'note': noteValue, // Contra Bon uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Movement
  Future<Map<String, dynamic>> approveMovement(int id, {String? comment, String? notes, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'notes' and 'comment' parameters (web uses 'notes')
      final notesValue = notes ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/employee-movements/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'status': 'approved', // Employee Movement uses status: 'approved'
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
          if (notesValue != null) 'notes': notesValue, // Employee Movement uses 'notes' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Movement
  Future<Map<String, dynamic>> rejectMovement(int id, {String? comment, String? reason, String? notes, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'notes', 'comment', and 'reason' parameters (web uses 'notes')
      final notesValue = notes ?? reason ?? comment;

      // Employee Movement reject uses the same approve endpoint with status: 'rejected' (same as web)
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/employee-movements/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'status': 'rejected', // Employee Movement uses status: 'rejected'
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId,
          if (notesValue != null) 'notes': notesValue, // Employee Movement uses 'notes' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Coaching
  Future<Map<String, dynamic>> approveCoaching(int id, {String? comment, String? comments, int? approverId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'comments' and 'comment' parameters (web uses 'comments')
      final commentsValue = comments ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/coaching/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approverId != null) 'approver_id': approverId, // Coaching requires approver_id
          if (commentsValue != null) 'comments': commentsValue, // Coaching uses 'comments' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Coaching
  Future<Map<String, dynamic>> rejectCoaching(int id, {String? comment, String? reason, String? comments, int? approverId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'comments', 'comment', and 'reason' parameters (web uses 'comments' and requires it)
      final commentsValue = comments ?? comment ?? reason;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/coaching/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approverId != null) 'approver_id': approverId,
          if (commentsValue != null) 'comments': commentsValue, // Coaching uses 'comments' parameter (required for reject)
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Correction
  Future<Map<String, dynamic>> approveCorrection(int id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Correction approve doesn't require any parameters (same as web)
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}), // Empty body, no parameters needed
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Correction
  Future<Map<String, dynamic>> rejectCorrection(int id, {String? comment, String? reason, String? rejection_reason}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'rejection_reason', 'reason', and 'comment' parameters (web uses 'rejection_reason' and requires it)
      final rejectionReasonValue = rejection_reason ?? reason ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/schedule-attendance-correction/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (rejectionReasonValue != null) 'rejection_reason': rejectionReasonValue, // Correction uses 'rejection_reason' parameter (required)
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Get Pending Food Payment Approvals
  Future<List<FoodPaymentApproval>> getPendingFoodPaymentApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Food Payment Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/food-payment/pending-approvals';
      print('Food Payment Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Food Payment Approvals: Status code = ${response.statusCode}');
      print('Food Payment Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Food Payment Approvals: Parsed data = $data');
        if (data['success'] == true && data['food_payments'] != null) {
          final List<dynamic> approvalsJson = data['food_payments'];
          print('Food Payment Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => FoodPaymentApproval.fromJson(json))
              .toList();
        } else {
          print('Food Payment Approvals: success=false or food_payments is null');
        }
      } else {
        print('Food Payment Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Food Payment approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Non Food Payment Approvals
  Future<List<NonFoodPaymentApproval>> getPendingNonFoodPaymentApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Non Food Payment Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/non-food-payment/pending-approvals';
      print('Non Food Payment Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Non Food Payment Approvals: Status code = ${response.statusCode}');
      print('Non Food Payment Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Non Food Payment Approvals: Parsed data = $data');
        if (data['success'] == true && data['non_food_payments'] != null) {
          final List<dynamic> approvalsJson = data['non_food_payments'];
          print('Non Food Payment Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => NonFoodPaymentApproval.fromJson(json))
              .toList();
        } else {
          print('Non Food Payment Approvals: success=false or non_food_payments is null');
        }
      } else {
        print('Non Food Payment Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Non Food Payment approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending PR Food Approvals
  Future<List<PRFoodApproval>> getPendingPrFoodApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('PR Food Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/pr-food/pending-approvals';
      print('PR Food Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('PR Food Approvals: Status code = ${response.statusCode}');
      print('PR Food Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('PR Food Approvals: Parsed data = $data');
        if (data['success'] == true && data['pr_foods'] != null) {
          final List<dynamic> approvalsJson = data['pr_foods'];
          print('PR Food Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => PRFoodApproval.fromJson(json))
              .toList();
        } else {
          print('PR Food Approvals: success=false or pr_foods is null');
        }
      } else {
        print('PR Food Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading PR Food approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending PO Food Approvals
  Future<List<POFoodApproval>> getPendingPoFoodApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('PO Food Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/po-food/pending-approvals';
      print('PO Food Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('PO Food Approvals: Status code = ${response.statusCode}');
      print('PO Food Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('PO Food Approvals: Parsed data = $data');
        if (data['success'] == true && data['po_foods'] != null) {
          final List<dynamic> approvalsJson = data['po_foods'];
          print('PO Food Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => POFoodApproval.fromJson(json))
              .toList();
        } else {
          print('PO Food Approvals: success=false or po_foods is null');
        }
      } else {
        print('PO Food Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading PO Food approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending RO Khusus Approvals
  Future<List<ROKhususApproval>> getPendingROKhususApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('RO Khusus Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/ro-khusus/pending-approvals';
      print('RO Khusus Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('RO Khusus Approvals: Status code = ${response.statusCode}');
      print('RO Khusus Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('RO Khusus Approvals: Parsed data = $data');
        if (data['success'] == true && data['ro_khusus'] != null) {
          final List<dynamic> approvalsJson = data['ro_khusus'];
          print('RO Khusus Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => ROKhususApproval.fromJson(json))
              .toList();
        } else {
          print('RO Khusus Approvals: success=false or ro_khusus is null');
        }
      } else {
        print('RO Khusus Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading RO Khusus approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get Pending Employee Resignation Approvals
  Future<List<EmployeeResignationApproval>> getPendingEmployeeResignationApprovals() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('Employee Resignation Approvals: No token found');
        return [];
      }

      final url = '$baseUrl/api/approval-app/employee-resignation/pending-approvals';
      print('Employee Resignation Approvals: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Employee Resignation Approvals: Status code = ${response.statusCode}');
      print('Employee Resignation Approvals: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Employee Resignation Approvals: Parsed data = $data');
        if (data['success'] == true && data['resignations'] != null) {
          final List<dynamic> approvalsJson = data['resignations'];
          print('Employee Resignation Approvals: Found ${approvalsJson.length} approvals');
          return approvalsJson
              .map((json) => EmployeeResignationApproval.fromJson(json))
              .toList();
        } else {
          print('Employee Resignation Approvals: success=false or resignations is null');
        }
      } else {
        print('Employee Resignation Approvals: Non-200 status code: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error loading Employee Resignation approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Approve Food Payment
  Future<Map<String, dynamic>> approveFoodPayment(int id, {String? comment, String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note' and 'comment' parameters (web uses 'note')
      final noteValue = note ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-payment/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': true, // Required field for Food Payment approval
          if (noteValue != null) 'note': noteValue, // Food Payment uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Food Payment
  Future<Map<String, dynamic>> rejectFoodPayment(int id, {String? reason, String? comment, String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'reason' parameters (web uses 'note')
      final noteValue = note ?? comment ?? reason;

      // Food Payment reject uses the same approve endpoint with approved: false (same as web)
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/food-payment/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': false, // Required field for Food Payment rejection
          if (noteValue != null) 'note': noteValue, // Food Payment uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Non Food Payment
  Future<Map<String, dynamic>> approveNonFoodPayment(int id, {String? comment, String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note' and 'comment' parameters (web uses 'note')
      final noteValue = note ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/non-food-payment/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (noteValue != null) 'note': noteValue, // NonFoodPayment uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Non Food Payment
  Future<Map<String, dynamic>> rejectNonFoodPayment(int id, {String? comment, String? reason, String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'reason' parameters (web uses 'note')
      final noteValue = note ?? reason ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/non-food-payment/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (noteValue != null) 'note': noteValue, // NonFoodPayment uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve PR Food
  Future<Map<String, dynamic>> approvePrFood(int id, {String? comment, String? note, String? approvalLevel}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note' and 'comment' parameters (web uses level-specific notes)
      final noteValue = note ?? comment;

      // Determine endpoint based on approval level
      String endpoint;
      if (approvalLevel == 'assistant_ssd_manager') {
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-assistant-ssd-manager';
      } else if (approvalLevel == 'ssd_manager' || approvalLevel == 'sous_chef_mk') {
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-ssd-manager';
      } else if (approvalLevel == 'vice_coo') {
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-vice-coo';
      } else {
        // Default to assistant_ssd_manager if not specified
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-assistant-ssd-manager';
      }

      // Build request body with level-specific note fields (web uses these)
      final Map<String, dynamic> requestBody = {
        'approved': true, // PR Food uses 'approved' boolean
      };

      // Add level-specific note fields (web uses these)
      if (noteValue != null) {
        if (approvalLevel == 'assistant_ssd_manager') {
          requestBody['assistant_ssd_manager_note'] = noteValue;
        } else if (approvalLevel == 'ssd_manager' || approvalLevel == 'sous_chef_mk') {
          requestBody['ssd_manager_note'] = noteValue;
        } else if (approvalLevel == 'vice_coo') {
          requestBody['vice_coo_note'] = noteValue;
        } else {
          // Fallback to generic 'note' if level not specified
          requestBody['note'] = noteValue;
        }
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject PR Food
  Future<Map<String, dynamic>> rejectPrFood(int id, {String? comment, String? reason, String? note, String? approvalLevel}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'reason' parameters (web uses level-specific notes)
      final noteValue = note ?? reason ?? comment;

      // Determine endpoint based on approval level (same endpoint as approve, with approved: false)
      String endpoint;
      if (approvalLevel == 'assistant_ssd_manager') {
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-assistant-ssd-manager';
      } else if (approvalLevel == 'ssd_manager' || approvalLevel == 'sous_chef_mk') {
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-ssd-manager';
      } else if (approvalLevel == 'vice_coo') {
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-vice-coo';
      } else {
        // Default to assistant_ssd_manager if not specified
        endpoint = '$baseUrl/api/approval-app/pr-food/$id/approve-assistant-ssd-manager';
      }

      // Build request body with level-specific note fields (web uses these)
      final Map<String, dynamic> requestBody = {
        'approved': false, // PR Food uses 'approved' boolean for reject
      };

      // Add level-specific note fields (web uses these)
      if (noteValue != null) {
        if (approvalLevel == 'assistant_ssd_manager') {
          requestBody['assistant_ssd_manager_note'] = noteValue;
        } else if (approvalLevel == 'ssd_manager' || approvalLevel == 'sous_chef_mk') {
          requestBody['ssd_manager_note'] = noteValue;
        } else if (approvalLevel == 'vice_coo') {
          requestBody['vice_coo_note'] = noteValue;
        } else {
          // Fallback to generic 'note' if level not specified
          requestBody['note'] = noteValue;
        }
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve PO Food
  Future<Map<String, dynamic>> approvePoFood(int id, {String? comment, String? note, String? approvalLevel}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note' and 'comment' parameters (web uses level-specific notes)
      final noteValue = note ?? comment;

      // Determine endpoint based on approval level
      String endpoint;
      if (approvalLevel == 'purchasing_manager') {
        endpoint = '$baseUrl/api/approval-app/po-food/$id/approve-purchasing-manager';
      } else if (approvalLevel == 'gm_finance') {
        endpoint = '$baseUrl/api/approval-app/po-food/$id/approve-gm-finance';
      } else {
        // Default to purchasing_manager if not specified
        endpoint = '$baseUrl/api/approval-app/po-food/$id/approve-purchasing-manager';
      }

      // Build request body with level-specific note fields (web uses these)
      final Map<String, dynamic> requestBody = {
        'approved': true, // PO Food uses 'approved' boolean
      };

      // Add level-specific note fields (web uses these)
      if (noteValue != null) {
        if (approvalLevel == 'purchasing_manager') {
          requestBody['purchasing_manager_note'] = noteValue;
        } else if (approvalLevel == 'gm_finance') {
          requestBody['gm_finance_note'] = noteValue;
        } else {
          // Fallback to generic 'note' if level not specified
          requestBody['note'] = noteValue;
        }
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject PO Food
  Future<Map<String, dynamic>> rejectPoFood(int id, {String? comment, String? reason, String? note, String? approvalLevel}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'reason' parameters (web uses level-specific notes)
      final noteValue = note ?? reason ?? comment;

      // Determine endpoint based on approval level (same endpoint as approve, with approved: false)
      String endpoint;
      if (approvalLevel == 'purchasing_manager') {
        endpoint = '$baseUrl/api/approval-app/po-food/$id/approve-purchasing-manager';
      } else if (approvalLevel == 'gm_finance') {
        endpoint = '$baseUrl/api/approval-app/po-food/$id/approve-gm-finance';
      } else {
        // Default to purchasing_manager if not specified
        endpoint = '$baseUrl/api/approval-app/po-food/$id/approve-purchasing-manager';
      }

      // Build request body with level-specific note fields (web uses these)
      final Map<String, dynamic> requestBody = {
        'approved': false, // PO Food uses 'approved' boolean for reject
      };

      // Add level-specific note fields (web uses these)
      if (noteValue != null) {
        if (approvalLevel == 'purchasing_manager') {
          requestBody['purchasing_manager_note'] = noteValue;
        } else if (approvalLevel == 'gm_finance') {
          requestBody['gm_finance_note'] = noteValue;
        } else {
          // Fallback to generic 'note' if level not specified
          requestBody['note'] = noteValue;
        }
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve RO Khusus
  Future<Map<String, dynamic>> approveROKhusus(int id, {String? comment, String? note, String? notes, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'notes', 'note', and 'comment' parameters (web uses 'notes')
      final noteValue = notes ?? note ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/ro-khusus/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': true, // RO Khusus uses 'approved' boolean
          if (noteValue != null) 'note': noteValue, // Backend accepts 'note', 'comment', 'notes', 'reason'
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      }

      // Handle budget violation (422) or other errors
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to approve',
        'violations': data['violations'] ?? null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject RO Khusus
  Future<Map<String, dynamic>> rejectROKhusus(int id, {String? comment, String? reason, String? note, String? notes, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'notes', 'note', 'comment', and 'reason' parameters (web uses 'notes')
      final noteValue = notes ?? note ?? reason ?? comment;

      // RO Khusus reject uses the same approve endpoint with approved: false (same as web)
      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/ro-khusus/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'approved': false, // RO Khusus uses 'approved' boolean for reject
          if (noteValue != null) 'note': noteValue, // Backend accepts 'note', 'comment', 'notes', 'reason'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Approve Employee Resignation
  Future<Map<String, dynamic>> approveEmployeeResignation(int id, {String? comment, String? note, String? comments, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'comments' parameters (web uses 'note')
      final noteValue = note ?? comment ?? comments;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/employee-resignation/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId, // Employee Resignation uses approval_flow_id
          if (noteValue != null) 'note': noteValue, // Employee Resignation uses 'note' parameter
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to approve',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reject Employee Resignation
  Future<Map<String, dynamic>> rejectEmployeeResignation(int id, {String? comment, String? reason, String? note, int? approvalFlowId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Support 'note', 'comment', and 'reason' parameters (web uses 'note' and it's required)
      final noteValue = note ?? reason ?? comment;

      final response = await http.post(
        Uri.parse('$baseUrl/api/approval-app/employee-resignation/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (approvalFlowId != null) 'approval_flow_id': approvalFlowId, // Employee Resignation uses approval_flow_id
          if (noteValue != null) 'note': noteValue, // Employee Resignation uses 'note' parameter (required for reject)
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }

      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to reject',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

