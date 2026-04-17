import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/approval_service.dart';
import '../models/approval_models.dart';
import '../widgets/approvals/pr_approval_card.dart';
import '../widgets/approvals/po_ops_approval_card.dart';
import '../widgets/approvals/leave_approval_card.dart';
import '../widgets/approvals/category_cost_approval_card.dart';
import '../widgets/approvals/stock_adjustment_approval_card.dart';
import '../widgets/approvals/stock_opname_approval_card.dart';
import '../widgets/approvals/warehouse_stock_opname_approval_card.dart';
import '../widgets/approvals/cctv_access_request_approval_card.dart';
import '../widgets/approvals/outlet_transfer_approval_card.dart';
import '../widgets/approvals/contra_bon_approval_card.dart';
import '../widgets/approvals/movement_approval_card.dart';
import '../widgets/approvals/coaching_approval_card.dart';
import '../widgets/approvals/correction_approval_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/approvals/food_payment_approval_card.dart';
import '../widgets/approvals/non_food_payment_approval_card.dart';
import '../widgets/approvals/pr_food_approval_card.dart';
import '../widgets/approvals/po_food_approval_card.dart';
import '../widgets/approvals/ro_khusus_approval_card.dart';
import '../widgets/approvals/employee_resignation_approval_card.dart';
import 'approvals/pr_approval_detail_screen.dart';
import 'approvals/po_ops_approval_detail_screen.dart';
import 'approvals/leave_approval_detail_screen.dart';
import 'approvals/category_cost_approval_detail_screen.dart';
import 'approvals/stock_adjustment_approval_detail_screen.dart';
import 'outlet_transfer/outlet_transfer_detail_screen.dart';
import 'stock_opname/stock_opname_detail_screen.dart';
import 'warehouse_stock_opname/warehouse_stock_opname_detail_screen.dart';
import 'approvals/cctv_access_request_approval_detail_screen.dart';
import 'approvals/contra_bon_approval_detail_screen.dart';
import 'approvals/movement_approval_detail_screen.dart';
import 'approvals/coaching_approval_detail_screen.dart';
import 'approvals/correction_approval_detail_screen.dart';
import 'approvals/food_payment_approval_detail_screen.dart';
import 'approvals/non_food_payment_approval_detail_screen.dart';
import 'approvals/pr_food_approval_detail_screen.dart';
import 'approvals/po_food_approval_detail_screen.dart';
import 'approvals/ro_khusus_approval_detail_screen.dart';
import 'approvals/employee_resignation_approval_detail_screen.dart';
import '../widgets/approval_list_modal.dart';
import '../widgets/app_scaffold.dart';
import 'login_screen.dart';
import 'web_only_feature_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _greeting = '';
  Map<String, String> _quote = {'text': '', 'author': ''};

  // Announcements & Birthdays
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _allAnnouncements = [];
  List<Map<String, dynamic>> _birthdays = [];
  bool _isLoadingAnnouncements = false;
  bool _isLoadingAllAnnouncements = false;
  bool _isLoadingBirthdays = false;
  
  // Approval states
  final ApprovalService _approvalService = ApprovalService();
  List<PurchaseRequisitionApproval> _prApprovals = [];
  List<PurchaseOrderOpsApproval> _poOpsApprovals = [];
  List<LeaveApproval> _leaveApprovals = [];
  List<LeaveApproval> _hrdApprovals = [];
  List<CategoryCostApproval> _categoryCostApprovals = [];
  List<StockAdjustmentApproval> _stockAdjustmentApprovals = [];
  List<StockOpnameApproval> _stockOpnameApprovals = [];
  List<WarehouseStockOpnameApproval> _warehouseStockOpnameApprovals = [];
  List<CctvAccessRequestApproval> _cctvAccessRequestApprovals = [];
  List<OutletTransferApproval> _outletTransferApprovals = [];
  List<ContraBonApproval> _contraBonApprovals = [];
  List<EmployeeMovementApproval> _movementApprovals = [];
  List<CoachingApproval> _coachingApprovals = [];
  List<CorrectionApproval> _correctionApprovals = [];
  List<FoodPaymentApproval> _foodPaymentApprovals = [];
  List<NonFoodPaymentApproval> _nonFoodPaymentApprovals = [];
  List<PRFoodApproval> _prFoodApprovals = [];
  List<POFoodApproval> _poFoodApprovals = [];
  List<ROKhususApproval> _roKhususApprovals = [];
  List<EmployeeResignationApproval> _employeeResignationApprovals = [];
  bool _isLoadingApprovals = false;
  bool _isApprovalsRefreshInProgress = false;
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadUserData();
    _updateGreeting();
    _loadQuote();
    _loadAnnouncements();
    _loadBirthdays();
    // Load approvals (will show cache first, then refresh)
    _loadAllApprovals(showLoading: false);
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = AuthService();
    // Try to refresh from API first, fallback to cached data
    final refreshResult = await authService.refreshUserData();
    if (refreshResult['success'] == true) {
      setState(() {
        _userData = refreshResult['user'];
        _isLoading = false;
      });
    } else {
      // Fallback to cached data
      final userData = await authService.getUserData();
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _uploadBanner() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      final authService = AuthService();
      final result = await authService.uploadBanner(pickedFile.path);

      if (result['success'] == true) {
        // Reload user data
        await _loadUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banner berhasil diupload'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengupload banner'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour >= 5 && hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour >= 12 && hour < 16) {
      greeting = 'Selamat Siang';
    } else if (hour >= 16 && hour < 19) {
      greeting = 'Selamat Sore';
    } else {
      greeting = 'Selamat Malam';
    }
    
    setState(() {
      _greeting = greeting;
    });
  }

  Future<void> _loadQuote() async {
    // Simple quote for now - can be replaced with API call
    setState(() {
      _quote = {
        'text': 'The future belongs to those who believe in the beauty of their dreams.',
        'author': 'Eleanor Roosevelt',
      };
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadAnnouncements() async {
    try {
      setState(() {
        _isLoadingAnnouncements = true;
      });

      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/approval-app/user-announcements'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = _extractMapList(
          data,
          primaryKeys: ['announcements'],
        );

        if (mounted) {
          setState(() {
            _announcements = list;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _announcements = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _announcements = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnnouncements = false;
        });
      }
    }
  }

  Future<void> _loadAllAnnouncements() async {
    try {
      setState(() {
        _isLoadingAllAnnouncements = true;
      });

      final token = await _getAuthToken();
      final response = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/api/approval-app/user-announcements?per_page=50&page=1'),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = _extractMapList(
          data,
          primaryKeys: ['announcements'],
        );
        if (mounted) {
          setState(() {
            _allAnnouncements = list;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _allAnnouncements = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allAnnouncements = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAllAnnouncements = false;
        });
      }
    }
  }

  Future<void> _loadBirthdays() async {
    try {
      setState(() {
        _isLoadingBirthdays = true;
      });

      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/approval-app/birthdays'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = _extractMapList(
          data,
          primaryKeys: ['birthdays'],
        );

        if (mounted) {
          setState(() {
            _birthdays = list;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _birthdays = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _birthdays = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBirthdays = false;
        });
      }
    }
  }

  // Load approvals separately like in Home.vue
  Future<void> _loadPendingPrApprovals() async {
    try {
      final approvals = await _approvalService.getPendingPrApprovals();
      // Store raw JSON for caching (get from service's cache)
      final rawCache = _approvalService.getRawJsonCache();
      if (rawCache.containsKey('pr')) {
        _cachedApprovalsJson['pr'] = rawCache['pr']!;
      }
      if (mounted) {
        setState(() {
          _prApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading PR approvals: $e');
    }
  }

  Future<void> _loadPendingPoOpsApprovals() async {
    try {
      final approvals = await _approvalService.getPendingPoOpsApprovals();
      // Store raw JSON for caching
      final rawCache = _approvalService.getRawJsonCache();
      if (rawCache.containsKey('po_ops')) {
        _cachedApprovalsJson['po_ops'] = rawCache['po_ops']!;
      }
      if (mounted) {
        setState(() {
          _poOpsApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading PO Ops approvals: $e');
    }
  }

  Future<void> _loadPendingLeaveApprovals() async {
    try {
      print('Loading Leave approvals...');
      final approvals = await _approvalService.getPendingLeaveApprovals();
      print('Leave approvals loaded: ${approvals.length}');
      if (mounted) {
        setState(() {
          _leaveApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Leave approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadPendingHrdApprovals() async {
    try {
      print('Loading HRD approvals...');
      final approvals = await _approvalService.getPendingHrdApprovals();
      print('HRD approvals loaded: ${approvals.length}');
      if (mounted) {
        setState(() {
          _hrdApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading HRD approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadPendingCategoryCostApprovals() async {
    try {
      final approvals = await _approvalService.getPendingCategoryCostApprovals();
      if (mounted) {
        setState(() {
          _categoryCostApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Category Cost approvals: $e');
    }
  }

  Future<void> _loadPendingStockAdjustmentApprovals() async {
    try {
      final approvals = await _approvalService.getPendingStockAdjustmentApprovals();
      if (mounted) {
        setState(() {
          _stockAdjustmentApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Stock Adjustment approvals: $e');
    }
  }

  Future<void> _loadPendingStockOpnameApprovals() async {
    try {
      final approvals = await _approvalService.getPendingStockOpnameApprovals();
      final rawCache = _approvalService.getRawJsonCache();
      if (rawCache.containsKey('stock_opnames')) {
        _cachedApprovalsJson['stock_opnames'] = rawCache['stock_opnames']!;
      }
      if (mounted) {
        setState(() {
          _stockOpnameApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Stock Opname approvals: $e');
    }
  }

  Future<void> _loadPendingWarehouseStockOpnameApprovals() async {
    try {
      final approvals = await _approvalService.getPendingWarehouseStockOpnameApprovals();
      final rawCache = _approvalService.getRawJsonCache();
      if (rawCache.containsKey('warehouse_stock_opnames')) {
        _cachedApprovalsJson['warehouse_stock_opnames'] = rawCache['warehouse_stock_opnames']!;
      }
      if (mounted) {
        setState(() {
          _warehouseStockOpnameApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Warehouse Stock Opname approvals: $e');
    }
  }

  Future<void> _loadPendingCctvAccessRequestApprovals() async {
    try {
      final approvals = await _approvalService.getPendingCctvAccessRequestApprovals();
      final rawCache = _approvalService.getRawJsonCache();
      if (rawCache.containsKey('cctv_access_requests')) {
        _cachedApprovalsJson['cctv_access_requests'] = rawCache['cctv_access_requests']!;
      }
      if (mounted) {
        setState(() {
          _cctvAccessRequestApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading CCTV access request approvals: $e');
    }
  }

  Future<void> _loadPendingOutletTransferApprovals() async {
    try {
      final approvals = await _approvalService.getPendingOutletTransferApprovals();
      final rawCache = _approvalService.getRawJsonCache();
      if (rawCache.containsKey('outlet_transfer')) {
        _cachedApprovalsJson['outlet_transfer'] = rawCache['outlet_transfer']!;
      }
      if (mounted) {
        setState(() {
          _outletTransferApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Outlet Transfer approvals: $e');
    }
  }

  Future<void> _loadPendingContraBonApprovals() async {
    try {
      final approvals = await _approvalService.getPendingContraBonApprovals();
      if (mounted) {
        setState(() {
          _contraBonApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Contra Bon approvals: $e');
    }
  }

  Future<void> _loadPendingMovementApprovals() async {
    try {
      print('Loading Movement approvals...');
      final approvals = await _approvalService.getPendingMovementApprovals();
      print('Movement approvals loaded: ${approvals.length}');
      if (mounted) {
        setState(() {
          _movementApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Movement approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadPendingCoachingApprovals() async {
    try {
      print('Loading Coaching approvals...');
      final approvals = await _approvalService.getPendingCoachingApprovals();
      print('Coaching approvals loaded: ${approvals.length}');
      if (mounted) {
        setState(() {
          _coachingApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Coaching approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadPendingCorrectionApprovals() async {
    try {
      print('Loading Correction approvals...');
      final approvals = await _approvalService.getPendingCorrectionApprovals();
      print('Correction approvals loaded: ${approvals.length}');
      if (mounted) {
        setState(() {
          _correctionApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Correction approvals: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadPendingFoodPaymentApprovals() async {
    try {
      final approvals = await _approvalService.getPendingFoodPaymentApprovals();
      if (mounted) {
        setState(() {
          _foodPaymentApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Food Payment approvals: $e');
    }
  }

  Future<void> _loadPendingNonFoodPaymentApprovals() async {
    try {
      final approvals = await _approvalService.getPendingNonFoodPaymentApprovals();
      if (mounted) {
        setState(() {
          _nonFoodPaymentApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Non Food Payment approvals: $e');
    }
  }

  Future<void> _loadPendingPrFoodApprovals() async {
    try {
      final approvals = await _approvalService.getPendingPrFoodApprovals();
      if (mounted) {
        setState(() {
          _prFoodApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading PR Food approvals: $e');
    }
  }

  Future<void> _loadPendingPoFoodApprovals() async {
    try {
      final approvals = await _approvalService.getPendingPoFoodApprovals();
      if (mounted) {
        setState(() {
          _poFoodApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading PO Food approvals: $e');
    }
  }

  Future<void> _loadPendingROKhususApprovals() async {
    try {
      final approvals = await _approvalService.getPendingROKhususApprovals();
      if (mounted) {
        setState(() {
          _roKhususApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading RO Khusus approvals: $e');
    }
  }

  Future<void> _loadPendingEmployeeResignationApprovals() async {
    try {
      final approvals = await _approvalService.getPendingEmployeeResignationApprovals();
      if (mounted) {
        setState(() {
          _employeeResignationApprovals = approvals;
        });
      }
    } catch (e) {
      print('Error loading Employee Resignation approvals: $e');
    }
  }

  // Cache raw JSON data from API responses
  Map<String, List<dynamic>> _cachedApprovalsJson = {};

  // Load cached approvals from SharedPreferences
  Future<void> _loadCachedApprovals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_approvals');
      if (cachedJson != null) {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        final timestamp = cached['timestamp'] as int?;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Use cache if less than 5 minutes old
        if (timestamp != null && (now - timestamp) < 5 * 60 * 1000) {
          _cachedApprovalsJson = Map<String, List<dynamic>>.from(cached['data'] as Map? ?? {});
          
          if (mounted) {
            setState(() {
              _prApprovals = (_cachedApprovalsJson['pr'] as List<dynamic>?)
                      ?.map((e) => PurchaseRequisitionApproval.fromJson(e))
                      .toList() ?? [];
              _poOpsApprovals = (_cachedApprovalsJson['po_ops'] as List<dynamic>?)
                      ?.map((e) => PurchaseOrderOpsApproval.fromJson(e))
                      .toList() ?? [];
              _leaveApprovals = (_cachedApprovalsJson['leave'] as List<dynamic>?)
                      ?.map((e) => LeaveApproval.fromJson(e))
                      .toList() ?? [];
              _hrdApprovals = (_cachedApprovalsJson['hrd'] as List<dynamic>?)
                      ?.map((e) => LeaveApproval.fromJson(e))
                      .toList() ?? [];
              _categoryCostApprovals = (_cachedApprovalsJson['category_cost'] as List<dynamic>?)
                      ?.map((e) => CategoryCostApproval.fromJson(e))
                      .toList() ?? [];
              _stockAdjustmentApprovals = (_cachedApprovalsJson['stock_adjustment'] as List<dynamic>?)
                      ?.map((e) => StockAdjustmentApproval.fromJson(e))
                      .toList() ?? [];
              _stockOpnameApprovals = (_cachedApprovalsJson['stock_opnames'] as List<dynamic>?)
                      ?.map((e) => StockOpnameApproval.fromJson(e))
                      .toList() ?? [];
              _warehouseStockOpnameApprovals =
                  (_cachedApprovalsJson['warehouse_stock_opnames'] as List<dynamic>?)
                          ?.map((e) => WarehouseStockOpnameApproval.fromJson(e))
                          .toList() ??
                      [];
              _cctvAccessRequestApprovals =
                  (_cachedApprovalsJson['cctv_access_requests'] as List<dynamic>?)
                          ?.map((e) => CctvAccessRequestApproval.fromJson(e))
                          .toList() ??
                      [];
              _outletTransferApprovals = (_cachedApprovalsJson['outlet_transfer'] as List<dynamic>?)
                      ?.map((e) => OutletTransferApproval.fromJson(e))
                      .toList() ?? [];
              _contraBonApprovals = (_cachedApprovalsJson['contra_bon'] as List<dynamic>?)
                      ?.map((e) => ContraBonApproval.fromJson(e))
                      .toList() ?? [];
              _movementApprovals = (_cachedApprovalsJson['movement'] as List<dynamic>?)
                      ?.map((e) => EmployeeMovementApproval.fromJson(e))
                      .toList() ?? [];
              _coachingApprovals = (_cachedApprovalsJson['coaching'] as List<dynamic>?)
                      ?.map((e) => CoachingApproval.fromJson(e))
                      .toList() ?? [];
              _correctionApprovals = (_cachedApprovalsJson['correction'] as List<dynamic>?)
                      ?.map((e) => CorrectionApproval.fromJson(e))
                      .toList() ?? [];
              _foodPaymentApprovals = (_cachedApprovalsJson['food_payment'] as List<dynamic>?)
                      ?.map((e) => FoodPaymentApproval.fromJson(e))
                      .toList() ?? [];
              _nonFoodPaymentApprovals = (_cachedApprovalsJson['non_food_payment'] as List<dynamic>?)
                      ?.map((e) => NonFoodPaymentApproval.fromJson(e))
                      .toList() ?? [];
              _prFoodApprovals = (_cachedApprovalsJson['pr_food'] as List<dynamic>?)
                      ?.map((e) => PRFoodApproval.fromJson(e))
                      .toList() ?? [];
              _poFoodApprovals = (_cachedApprovalsJson['po_food'] as List<dynamic>?)
                      ?.map((e) => POFoodApproval.fromJson(e))
                      .toList() ?? [];
              _roKhususApprovals = (_cachedApprovalsJson['ro_khusus'] as List<dynamic>?)
                      ?.map((e) => ROKhususApproval.fromJson(e))
                      .toList() ?? [];
              _employeeResignationApprovals = (_cachedApprovalsJson['employee_resignation'] as List<dynamic>?)
                      ?.map((e) => EmployeeResignationApproval.fromJson(e))
                      .toList() ?? [];
            });
          }
          print('Loaded approvals from cache');
        }
      }
    } catch (e) {
      print('Error loading cached approvals: $e');
    }
  }

  // Save approvals to cache (store raw JSON)
  Future<void> _saveApprovalsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': _cachedApprovalsJson,
      };
      await prefs.setString('cached_approvals', jsonEncode(cacheData));
      print('Saved approvals to cache');
    } catch (e) {
      print('Error saving approvals to cache: $e');
    }
  }

  // Refresh specific approval type (for after returning from detail screen)
  Future<void> _refreshApprovalType(String type) async {
    try {
      switch (type) {
        case 'pr':
          await _loadPendingPrApprovals();
          break;
        case 'po_ops':
          await _loadPendingPoOpsApprovals();
          break;
        case 'leave':
          await _loadPendingLeaveApprovals();
          break;
        case 'hrd':
          await _loadPendingHrdApprovals();
          break;
        case 'category_cost':
          await _loadPendingCategoryCostApprovals();
          break;
        case 'stock_adjustment':
          await _loadPendingStockAdjustmentApprovals();
          break;
        case 'stock_opname':
          await _loadPendingStockOpnameApprovals();
          break;
        case 'warehouse_stock_opname':
          await _loadPendingWarehouseStockOpnameApprovals();
          break;
        case 'cctv_access_request':
          await _loadPendingCctvAccessRequestApprovals();
          break;
        case 'outlet_transfer':
          await _loadPendingOutletTransferApprovals();
          break;
        case 'contra_bon':
          await _loadPendingContraBonApprovals();
          break;
        case 'movement':
          await _loadPendingMovementApprovals();
          break;
        case 'coaching':
          await _loadPendingCoachingApprovals();
          break;
        case 'correction':
          await _loadPendingCorrectionApprovals();
          break;
        case 'food_payment':
          await _loadPendingFoodPaymentApprovals();
          break;
        case 'non_food_payment':
          await _loadPendingNonFoodPaymentApprovals();
          break;
        case 'pr_food':
          await _loadPendingPrFoodApprovals();
          break;
        case 'po_food':
          await _loadPendingPoFoodApprovals();
          break;
        case 'ro_khusus':
          await _loadPendingROKhususApprovals();
          break;
        case 'employee_resignation':
          await _loadPendingEmployeeResignationApprovals();
          break;
      }
      // Save to cache after refresh
      await _saveApprovalsToCache();
    } catch (e) {
      print('Error refreshing approval type $type: $e');
    }
  }

  // Load all approvals with caching and parallel loading
  Future<void> _loadAllApprovals({bool showLoading = true, bool backgroundRefresh = false}) async {
    if (_isApprovalsRefreshInProgress) {
      print('Skipping approvals reload: previous request still in progress');
      return;
    }

    _isApprovalsRefreshInProgress = true;
    try {
      // Load from cache first (instant display) - unless it's a background refresh
      if (!backgroundRefresh) {
        await _loadCachedApprovals();
      }

      if (showLoading && mounted && !backgroundRefresh) {
        setState(() {
          _isLoadingApprovals = true;
        });
      }

      print('Loading all approvals from API...');
      
      // Load approvals in parallel batches for faster loading
      // Batch 1: Most common approvals
      await Future.wait([
        _loadPendingPrApprovals(),
        _loadPendingPoOpsApprovals(),
        _loadPendingLeaveApprovals(),
        _loadPendingHrdApprovals(),
      ], eagerError: false);

      // Batch 2: Other approvals
      await Future.wait([
        _loadPendingCategoryCostApprovals(),
        _loadPendingStockAdjustmentApprovals(),
        _loadPendingStockOpnameApprovals(),
        _loadPendingWarehouseStockOpnameApprovals(),
        _loadPendingCctvAccessRequestApprovals(),
        _loadPendingOutletTransferApprovals(),
        _loadPendingContraBonApprovals(),
        _loadPendingMovementApprovals(),
      ], eagerError: false);

      // Batch 3: Remaining approvals
      await Future.wait([
        _loadPendingCoachingApprovals(),
        _loadPendingCorrectionApprovals(),
        _loadPendingFoodPaymentApprovals(),
        _loadPendingNonFoodPaymentApprovals(),
      ], eagerError: false);

      // Batch 4: Food-related approvals
      await Future.wait([
        _loadPendingPrFoodApprovals(),
        _loadPendingPoFoodApprovals(),
        _loadPendingROKhususApprovals(),
        _loadPendingEmployeeResignationApprovals(),
      ], eagerError: false);

      // Save to cache after loading
      await _saveApprovalsToCache();

      print('Approvals loaded: PR=${_prApprovals.length}, PO=${_poOpsApprovals.length}, Leave=${_leaveApprovals.length}, HRD=${_hrdApprovals.length}, CategoryCost=${_categoryCostApprovals.length}, StockAdj=${_stockAdjustmentApprovals.length}, StockOpname=${_stockOpnameApprovals.length}, WhStockOpname=${_warehouseStockOpnameApprovals.length}, CCTV=${_cctvAccessRequestApprovals.length}, OutletTransfer=${_outletTransferApprovals.length}, ContraBon=${_contraBonApprovals.length}, Movement=${_movementApprovals.length}, Coaching=${_coachingApprovals.length}, Correction=${_correctionApprovals.length}, FoodPayment=${_foodPaymentApprovals.length}, NonFoodPayment=${_nonFoodPaymentApprovals.length}, PRFood=${_prFoodApprovals.length}, POFood=${_poFoodApprovals.length}, ROKhusus=${_roKhususApprovals.length}, EmployeeResignation=${_employeeResignationApprovals.length}');
    } catch (e) {
      print('Error loading approvals: $e');
    } finally {
      _isApprovalsRefreshInProgress = false;
      if (mounted && _isLoadingApprovals) {
        setState(() {
          _isLoadingApprovals = false;
        });
      }
    }
  }

  int get _totalPendingApprovals {
    return _prApprovals.length +
        _poOpsApprovals.length +
        _leaveApprovals.length +
        _hrdApprovals.length +
        _categoryCostApprovals.length +
        _stockAdjustmentApprovals.length +
        _stockOpnameApprovals.length +
        _warehouseStockOpnameApprovals.length +
        _cctvAccessRequestApprovals.length +
        _outletTransferApprovals.length +
        _contraBonApprovals.length +
        _movementApprovals.length +
        _coachingApprovals.length +
        _correctionApprovals.length +
        _foodPaymentApprovals.length +
        _nonFoodPaymentApprovals.length +
        _prFoodApprovals.length +
        _poFoodApprovals.length +
        _roKhususApprovals.length +
        _employeeResignationApprovals.length;
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getBannerUrl() {
    if (_userData?['banner'] != null) {
      return '${AuthService.storageUrl}/storage/${_userData!['banner']}';
    }
    return '';
  }

  String _getAvatarUrl() {
    if (_userData?['avatar'] != null) {
      return '${AuthService.storageUrl}/storage/${_userData!['avatar']}';
    }
    return '';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 3),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Home',
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAllApprovals(showLoading: false, backgroundRefresh: true);
          await _loadAnnouncements();
          await _loadBirthdays();
        },
        color: const Color(0xFF6366F1),
        backgroundColor: Colors.white,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Welcome Card
                  _buildWelcomeCard(),

                  const SizedBox(height: 20),

                  // Highlights: Announcements & Birthdays
                  _buildHighlightsSection(),
                  
                  // Approvals Section
                  _buildApprovalsSection(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              // Banner Section with Glassmorphism
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner Image or Gradient
                    _getBannerUrl().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _getBannerUrl(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildGradientBanner(),
                            errorWidget: (context, url, error) => _buildGradientBanner(),
                          )
                        : _buildGradientBanner(),
                    
                    // Glassmorphism Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    
                    // Upload Banner Button with Glassmorphism
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Material(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _uploadBanner,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Avatar Section
              Transform.translate(
                offset: const Offset(0, -50),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _getAvatarUrl().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _getAvatarUrl(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildAvatarPlaceholder(),
                            errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
                          )
                        : _buildAvatarPlaceholder(),
                  ),
                ),
              ),
              
              // User Info Section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Greeting
                    Text(
                      _greeting,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Name
                    Text(
                      _userData?['nama_lengkap'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // User Information Cards - Modern Design
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.85,
                      children: [
                        _buildModernInfoCard(
                          Icons.store_rounded,
                          'Outlet',
                          _userData?['outlet_name'] ?? 'N/A',
                          const Color(0xFF3B82F6),
                          const Color(0xFFEFF6FF),
                        ),
                        _buildModernInfoCard(
                          Icons.business_rounded,
                          'Divisi',
                          _userData?['division_name'] ?? 'N/A',
                          const Color(0xFF10B981),
                          const Color(0xFFECFDF5),
                        ),
                        _buildModernInfoCard(
                          Icons.trending_up_rounded,
                          'Level',
                          _userData?['jabatan']?['level_name'] ?? 
                          _userData?['jabatan']?['level']?['nama_level'] ?? 
                          _userData?['level_name'] ?? 'N/A',
                          const Color(0xFF8B5CF6),
                          const Color(0xFFF5F3FF),
                        ),
                        _buildModernInfoCard(
                          Icons.badge_rounded,
                          'Jabatan',
                          _userData?['jabatan_name'] ?? 'N/A',
                          const Color(0xFFF59E0B),
                          const Color(0xFFFEF3C7),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Quote Section - Modern Design
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.08),
                            const Color(0xFF8B5CF6).withOpacity(0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.format_quote_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Quote of the Day',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '"${_quote['text']}"',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade800,
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '— ${_quote['author']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAnnouncementsCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildBirthdaysCard()),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnnouncementsCard(),
              const SizedBox(height: 16),
              _buildBirthdaysCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pengumuman Terbaru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _openAnnouncementsModal();
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingAnnouncements)
            Column(
              children: List.generate(3, (index) => _buildAnnouncementSkeleton()),
            )
          else if (_announcements.isEmpty)
            _buildEmptyState(
              icon: Icons.campaign_outlined,
              message: 'Belum ada pengumuman untuk Anda',
            )
          else
            Column(
              children: _announcements.take(3).map(_buildAnnouncementItem).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementItem(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Tanpa Judul').toString();
    final content = (item['content'] ?? '').toString();
    final creatorName = (item['creator_name'] ?? 'Unknown').toString();
    final dateText = _formatAnnouncementDate(item);
    final imagePath = item['image_path']?.toString();

    return InkWell(
      onTap: () {
        _showAnnouncementDetail(item);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null && imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: '${AuthService.storageUrl}/storage/$imagePath',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    width: 54,
                    height: 54,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    width: 54,
                    height: 54,
                    child: const Icon(Icons.image_not_supported_outlined, size: 20),
                  ),
                ),
              )
            else
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.article_outlined, color: Color(0xFF3B82F6)),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.isEmpty ? 'Klik untuk melihat detail' : content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateText,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAnnouncementsModal() async {
    if (_allAnnouncements.isEmpty) {
      await _loadAllAnnouncements();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Semua Pengumuman',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoadingAllAnnouncements
                        ? ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: 6,
                            itemBuilder: (context, index) => _buildAnnouncementSkeleton(),
                          )
                        : (_allAnnouncements.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.campaign_outlined,
                                message: 'Belum ada pengumuman untuk Anda',
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                                itemCount: _allAnnouncements.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  return _buildAnnouncementModalItem(_allAnnouncements[index]);
                                },
                              )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementModalItem(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Tanpa Judul').toString();
    final content = (item['content'] ?? '').toString();
    final creatorName = (item['creator_name'] ?? 'Unknown').toString();
    final dateText = _formatAnnouncementDate(item);
    final imagePath = item['image_path']?.toString();

    return InkWell(
      onTap: () => _showAnnouncementDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null && imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: '${AuthService.storageUrl}/storage/$imagePath',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    width: 54,
                    height: 54,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    width: 54,
                    height: 54,
                    child: const Icon(Icons.image_not_supported_outlined, size: 20),
                  ),
                ),
              )
            else
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.article_outlined, color: Color(0xFF3B82F6)),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.isEmpty ? 'Klik untuk melihat detail' : content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateText,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Tanpa Judul').toString();
    final content = (item['content'] ?? '').toString();
    final creatorName = (item['creator_name'] ?? 'Unknown').toString();
    final dateText = _formatAnnouncementDate(item);
    final imagePath = item['image_path']?.toString();
    final files = (item['files'] is List) ? List<Map<String, dynamic>>.from(item['files']) : <Map<String, dynamic>>[];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          creatorName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (imagePath != null && imagePath.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: '${AuthService.storageUrl}/storage/$imagePath',
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          height: 180,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          height: 180,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  if (imagePath != null && imagePath.isNotEmpty) const SizedBox(height: 12),
                  Text(
                    content.isEmpty ? 'Tidak ada isi pengumuman.' : content,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                  if (files.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Lampiran',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...files.map((file) {
                      final fileName = (file['file_name'] ?? 'File').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBirthdaysCard() {
    final hasToday = _birthdays.any((b) => _isBirthdayToday(b['birthday']?.toString()));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE7F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ulang Tahun',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (hasToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE7F3),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF9A8D4)),
                  ),
                  child: const Text(
                    'Hari ini',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBE185D)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingBirthdays)
            Column(
              children: List.generate(3, (index) => _buildBirthdaySkeleton()),
            )
          else if (_birthdays.isEmpty)
            _buildEmptyState(
              icon: Icons.cake_outlined,
              message: 'Tidak ada ulang tahun dalam 30 hari ke depan',
            )
          else
            Column(
              children: _birthdays.take(5).map(_buildBirthdayItem).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBirthdayItem(Map<String, dynamic> person) {
    final name = (person['nama_lengkap'] ?? 'Unknown').toString();
    final avatar = person['avatar']?.toString();
    final jabatan = (person['jabatan']?['nama_jabatan'] ?? person['jabatan_name'] ?? 'N/A').toString();
    final outlet = (person['outlet']?['nama_outlet'] ?? person['outlet_name'] ?? 'N/A').toString();
    final birthday = person['birthday']?.toString();
    final isToday = _isBirthdayToday(birthday);
    final age = _calculateAge(birthday);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFDF2F8) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? const Color(0xFFFBCFE8) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: avatar != null && avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: '${AuthService.storageUrl}/storage/$avatar',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildAvatarCircle(name),
                    errorWidget: (context, url, error) => _buildAvatarCircle(name),
                  )
                : _buildAvatarCircle(name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jabatan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        outlet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatBirthdayDate(birthday),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isToday ? const Color(0xFFBE185D) : const Color(0xFF64748B),
                ),
              ),
              if (age != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$age th',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? const Color(0xFFBE185D) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              if (isToday)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.cake_rounded, size: 16, color: Color(0xFFEC4899)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String name) {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFFEFF6FF),
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B82F6),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: double.infinity, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 10, width: 180, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 8, width: 120, color: Colors.grey.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdaySkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: double.infinity, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 10, width: 150, color: Colors.grey.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractMapList(
    dynamic data, {
    List<String> primaryKeys = const [],
  }) {
    if (data is List) {
      return _asMapList(data);
    }

    if (data is Map) {
      for (final key in primaryKeys) {
        final value = data[key];
        if (value is List) return _asMapList(value);
        if (value is Map && value['data'] is List) return _asMapList(value['data']);
      }

      if (data['data'] is List) return _asMapList(data['data']);
      if (data['data'] is Map && data['data']['data'] is List) return _asMapList(data['data']['data']);
    }

    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _asMapList(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _formatAnnouncementDate(Map<String, dynamic> item) {
    final formatted = item['created_at_formatted']?.toString();
    if (formatted != null && formatted.isNotEmpty) return formatted;
    final raw = item['created_at']?.toString();
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  bool _isBirthdayToday(String? birthday) {
    if (birthday == null || birthday.isEmpty) return false;
    try {
      final date = DateTime.parse(birthday);
      final now = DateTime.now();
      return date.month == now.month && date.day == now.day;
    } catch (_) {
      return false;
    }
  }

  String _formatBirthdayDate(String? birthday) {
    if (birthday == null || birthday.isEmpty) return '-';
    try {
      final date = DateTime.parse(birthday);
      final now = DateTime.now();
      final thisYear = DateTime(now.year, date.month, date.day);
      final nextBirthday = thisYear.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year + 1, date.month, date.day)
          : thisYear;
      final diffDays = nextBirthday.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diffDays == 0) return 'Hari ini';
      if (diffDays == 1) return 'Besok';
      if (diffDays <= 7) return '$diffDays hari lagi';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return birthday;
    }
  }

  int? _calculateAge(String? birthday) {
    if (birthday == null || birthday.isEmpty) return null;
    try {
      final date = DateTime.parse(birthday);
      final now = DateTime.now();
      var age = now.year - date.year;
      final hasHadBirthdayThisYear =
          (now.month > date.month) || (now.month == date.month && now.day >= date.day);
      if (!hasHadBirthdayThisYear) {
        age -= 1;
      }
      return age < 0 ? null : age;
    } catch (_) {
      return null;
    }
  }

  Widget _buildGradientBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
            Color(0xFFEC4899),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(_userData?['nama_lengkap']),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoCard(IconData icon, String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 5,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Pending Approvals',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_totalPendingApprovals > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEF4444),
                        Color(0xFFDC2626),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_totalPendingApprovals',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Content
          if (_isLoadingApprovals)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading approvals...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_totalPendingApprovals == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All caught up!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No pending approvals',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // PR Approvals
            if (_prApprovals.isNotEmpty) ...[
              _buildModernApprovalSection(
                'Purchase Requisition',
                _prApprovals.length,
                const Color(0xFF10B981),
                _prApprovals.map((approval) => PRApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PRApprovalDetailScreen(prId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('pr');
                      }
                    });
                  },
                )).toList(),
                'pr',
              ),
            ],
            
            // PO Ops Approvals
            if (_poOpsApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Purchase Order Ops',
                _poOpsApprovals.length,
                const Color(0xFFF59E0B),
                _poOpsApprovals.map((approval) => POOpsApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => POOpsApprovalDetailScreen(poId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('po_ops');
                      }
                    });
                  },
                )).toList(),
                'po_ops',
              ),
            ],
            
            // Leave Approvals
            if (_leaveApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Leave Approvals',
                _leaveApprovals.length,
                const Color(0xFF3B82F6),
                _leaveApprovals.map((approval) => LeaveApprovalCard(
                  approval: approval,
                  isHrd: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaveApprovalDetailScreen(
                          leaveId: approval.id,
                          isHrd: false,
                        ),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('leave');
                      }
                    });
                  },
                )).toList(),
                'leave',
              ),
            ],
            
            // HRD Approvals
            if (_hrdApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'HRD Approvals',
                _hrdApprovals.length,
                const Color(0xFF8B5CF6),
                _hrdApprovals.map((approval) => LeaveApprovalCard(
                  approval: approval,
                  isHrd: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaveApprovalDetailScreen(
                          leaveId: approval.id,
                          isHrd: true,
                        ),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('hrd');
                      }
                    });
                  },
                )).toList(),
                'hrd',
              ),
            ],
            
            // Category Cost Approvals
            if (_categoryCostApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Category Cost',
                _categoryCostApprovals.length,
                const Color(0xFF06B6D4),
                _categoryCostApprovals.map((approval) => CategoryCostApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryCostApprovalDetailScreen(headerId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('category_cost');
                      }
                    });
                  },
                )).toList(),
                'category_cost',
              ),
            ],
            
            // Stock Adjustment Approvals
            if (_stockAdjustmentApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Stock Adjustment',
                _stockAdjustmentApprovals.length,
                const Color(0xFF14B8A6),
                _stockAdjustmentApprovals.map((approval) => StockAdjustmentApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockAdjustmentApprovalDetailScreen(adjustmentId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('stock_adjustment');
                      }
                    });
                  },
                )).toList(),
                'stock_adjustment',
              ),
            ],

            // Stock Opname Approvals
            if (_stockOpnameApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Stock Opname',
                _stockOpnameApprovals.length,
                const Color(0xFF6366F1),
                _stockOpnameApprovals.map((approval) => StockOpnameApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockOpnameDetailScreen(opnameId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('stock_opname');
                      }
                    });
                  },
                )).toList(),
                'stock_opname',
              ),
            ],

            // Warehouse Stock Opname (gudang)
            if (_warehouseStockOpnameApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Stock Opname Gudang',
                _warehouseStockOpnameApprovals.length,
                const Color(0xFF7C3AED),
                _warehouseStockOpnameApprovals.map((approval) => WarehouseStockOpnameApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WarehouseStockOpnameDetailScreen(opnameId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('warehouse_stock_opname');
                      }
                    });
                  },
                )).toList(),
                'warehouse_stock_opname',
              ),
            ],

            // CCTV Access Request (IT Manager)
            if (_cctvAccessRequestApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Akses CCTV',
                _cctvAccessRequestApprovals.length,
                const Color(0xFF546E7A),
                _cctvAccessRequestApprovals.map((approval) => CctvAccessRequestApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CctvAccessRequestApprovalDetailScreen(requestId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('cctv_access_request');
                      }
                    });
                  },
                )).toList(),
                'cctv_access_request',
              ),
            ],

            // Outlet Transfer Approvals
            if (_outletTransferApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Outlet Transfer',
                _outletTransferApprovals.length,
                const Color(0xFFF97316),
                _outletTransferApprovals.map((approval) => OutletTransferApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OutletTransferDetailScreen(transferId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('outlet_transfer');
                      }
                    });
                  },
                )).toList(),
                'outlet_transfer',
              ),
            ],
            
            // Contra Bon Approvals
            if (_contraBonApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Contra Bon',
                _contraBonApprovals.length,
                const Color(0xFF6366F1),
                _contraBonApprovals.map((approval) => ContraBonApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContraBonApprovalDetailScreen(cbId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('contra_bon');
                      }
                    });
                  },
                )).toList(),
                'contra_bon',
              ),
            ],
            
            // Movement Approvals
            if (_movementApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Employee Movement',
                _movementApprovals.length,
                const Color(0xFF10B981),
                _movementApprovals.map((approval) => MovementApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovementApprovalDetailScreen(movementId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('movement');
                      }
                    });
                  },
                )).toList(),
                'movement',
              ),
            ],
            
            // Coaching Approvals
            if (_coachingApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Coaching',
                _coachingApprovals.length,
                const Color(0xFF3B82F6),
                _coachingApprovals.map((approval) => CoachingApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CoachingApprovalDetailScreen(coachingId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('coaching');
                      }
                    });
                  },
                )).toList(),
                'coaching',
              ),
            ],
            
            // Correction Approvals
            if (_correctionApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Correction',
                _correctionApprovals.length,
                const Color(0xFFF59E0B),
                _correctionApprovals.map((approval) => CorrectionApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CorrectionApprovalDetailScreen(correctionId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('correction');
                      }
                    });
                  },
                )).toList(),
                'correction',
              ),
            ],
                        
            // Food Payment Approvals
            if (_foodPaymentApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Food Payment',
                _foodPaymentApprovals.length,
                const Color(0xFFEC4899),
                _foodPaymentApprovals.map((approval) => FoodPaymentApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FoodPaymentApprovalDetailScreen(paymentId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('food_payment');
                      }
                    });
                  },
                )).toList(),
                'food_payment',
              ),
            ],
            
            // Non Food Payment Approvals
            if (_nonFoodPaymentApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Non Food Payment',
                _nonFoodPaymentApprovals.length,
                const Color(0xFF7C3AED),
                _nonFoodPaymentApprovals.map((approval) => NonFoodPaymentApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NonFoodPaymentApprovalDetailScreen(paymentId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('non_food_payment');
                      }
                    });
                  },
                )).toList(),
                'non_food_payment',
              ),
            ],
            
            // PR Food Approvals
            if (_prFoodApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'PR Food',
                _prFoodApprovals.length,
                const Color(0xFFF59E0B),
                _prFoodApprovals.map((approval) => PRFoodApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PRFoodApprovalDetailScreen(prFoodId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('pr_food');
                      }
                    });
                  },
                )).toList(),
                'pr_food',
              ),
            ],
            
            // PO Food Approvals
            if (_poFoodApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'PO Food',
                _poFoodApprovals.length,
                const Color(0xFF92400E),
                _poFoodApprovals.map((approval) => POFoodApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => POFoodApprovalDetailScreen(poFoodId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('po_food');
                      }
                    });
                  },
                )).toList(),
                'po_food',
              ),
            ],
            
            // RO Khusus Approvals
            if (_roKhususApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'RO Khusus',
                _roKhususApprovals.length,
                const Color(0xFFEA580C),
                _roKhususApprovals.map((approval) => ROKhususApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ROKhususApprovalDetailScreen(roKhususId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('ro_khusus');
                      }
                    });
                  },
                )).toList(),
                'ro_khusus',
              ),
            ],
            
            // Employee Resignation Approvals
            if (_employeeResignationApprovals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildModernApprovalSection(
                'Employee Resignation',
                _employeeResignationApprovals.length,
                const Color(0xFFEF4444),
                _employeeResignationApprovals.map((approval) => EmployeeResignationApprovalCard(
                  approval: approval,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmployeeResignationApprovalDetailScreen(resignationId: approval.id),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _refreshApprovalType('employee_resignation');
                      }
                    });
                  },
                )).toList(),
                'employee_resignation',
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModernApprovalSection(
    String title,
    int count,
    Color color,
    List<Widget> cards,
    String type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...cards.take(3),
        if (cards.length > 3) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAllApprovals(title, cards, color, type),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lihat Semua (${cards.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, Color dotColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: dotColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showAllApprovals(String title, List<Widget> cards, Color color, String type) {
    // Get the actual approval objects from the cards
    List<dynamic> approvals = [];
    
    switch (type) {
      case 'pr':
        approvals = _prApprovals;
        break;
      case 'po_ops':
        approvals = _poOpsApprovals;
        break;
      case 'leave':
        approvals = _leaveApprovals;
        break;
      case 'hrd':
        approvals = _hrdApprovals;
        break;
      case 'category_cost':
        approvals = _categoryCostApprovals;
        break;
      case 'stock_adjustment':
        approvals = _stockAdjustmentApprovals;
        break;
      case 'stock_opname':
        approvals = _stockOpnameApprovals;
        break;
      case 'warehouse_stock_opname':
        approvals = _warehouseStockOpnameApprovals;
        break;
      case 'cctv_access_request':
        approvals = _cctvAccessRequestApprovals;
        break;
      case 'outlet_transfer':
        approvals = _outletTransferApprovals;
        break;
      case 'contra_bon':
        approvals = _contraBonApprovals;
        break;
      case 'movement':
        approvals = _movementApprovals;
        break;
      case 'coaching':
        approvals = _coachingApprovals;
        break;
      case 'correction':
        approvals = _correctionApprovals;
        break;
      case 'food_payment':
        approvals = _foodPaymentApprovals;
        break;
      case 'non_food_payment':
        approvals = _nonFoodPaymentApprovals;
        break;
      case 'pr_food':
        approvals = _prFoodApprovals;
        break;
      case 'po_food':
        approvals = _poFoodApprovals;
        break;
      case 'ro_khusus':
        approvals = _roKhususApprovals;
        break;
      case 'employee_resignation':
        approvals = _employeeResignationApprovals;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => ApprovalListModal(
        title: title,
        approvals: approvals,
        color: color,
        type: type,
        onRefresh: (type) => _refreshApprovalType(type),
      ),
    );
  }
}
