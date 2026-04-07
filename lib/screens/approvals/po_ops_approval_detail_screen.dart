import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:math' as math;
import '../../services/approval_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';
// import '../../widgets/purchase_requisition_comment_section.dart'; // Removed - was causing infinite loading

class POOpsApprovalDetailScreen extends StatefulWidget {
  final int poId;

  const POOpsApprovalDetailScreen({
    super.key,
    required this.poId,
  });

  @override
  State<POOpsApprovalDetailScreen> createState() => _POOpsApprovalDetailScreenState();
}

class _POOpsApprovalDetailScreenState extends State<POOpsApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _approvalData;
  bool _isLoading = true;
  bool _isProcessing = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _rejectReasonController = TextEditingController();
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadApprovalDetails();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null && userData['id'] != null) {
        setState(() {
          _currentUserId = userData['id'] as int?;
        });
      }
    } catch (e) {
      print('Error loading current user ID: $e');
    }
  }

  int? _getPurchaseRequisitionId() {
    if (_approvalData == null) return null;
    
    final po = _approvalData!;
    
    // Priority 1: Check if PO has source_pr (nested object with id)
    if (po['source_pr'] != null && po['source_pr'] is Map) {
      final sourcePr = po['source_pr'] as Map;
      if (sourcePr['id'] != null) {
        return sourcePr['id'] as int?;
      }
    }
    
    // Priority 2: Check if PO has purchase_requisition (nested object with id)
    if (po['purchase_requisition'] != null && po['purchase_requisition'] is Map) {
      final purchaseRequisition = po['purchase_requisition'] as Map;
      if (purchaseRequisition['id'] != null) {
        return purchaseRequisition['id'] as int?;
      }
    }
    
    // Priority 3: Check if PO has source_id and source_type is purchase_requisition_ops
    if (po['source_id'] != null && po['source_type'] == 'purchase_requisition_ops') {
      return po['source_id'] as int?;
    }
    
    return null;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovalDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _approvalService.getPoOpsApprovalDetails(widget.poId);
      
      setState(() {
        if (data == null) {
          _approvalData = null;
          _isLoading = false;
          return;
        }
        
        // PO Ops endpoint returns data directly with 'po' key
        // Get PO data - it might be directly in data or in data['po']
        _approvalData = data['po'] != null ? Map<String, dynamic>.from(data['po']) : Map<String, dynamic>.from(data);
        
        // Ensure budget_info is included in _approvalData
        if (data['budget_info'] != null) {
          _approvalData!['budget_info'] = data['budget_info'];
        } else if (data['budgetInfo'] != null) {
          _approvalData!['budget_info'] = data['budgetInfo'];
        }
        
        // Ensure items_budget_info is included in _approvalData
        if (data['items_budget_info'] != null) {
          _approvalData!['items_budget_info'] = data['items_budget_info'];
        } else if (data['itemsBudgetInfo'] != null) {
          _approvalData!['items_budget_info'] = data['itemsBudgetInfo'];
        }
        
        // Ensure approval_flows is included if it exists at root level
        if (data['approval_flows'] != null && _approvalData!['approval_flows'] == null) {
          _approvalData!['approval_flows'] = data['approval_flows'];
        }
        
        // Ensure items is included if it exists at root level
        if (data['items'] != null && (_approvalData!['items'] == null || (_approvalData!['items'] as List).isEmpty)) {
          _approvalData!['items'] = data['items'];
        }
        
        // Debug: Print data structure
        print('PO Ops Detail - Full data keys: ${data.keys.toList()}');
        print('PO Ops Detail - ApprovalData keys: ${_approvalData!.keys.toList()}');
        print('PO Ops Detail - Budget Info: ${_approvalData?['budget_info']}');
        print('PO Ops Detail - Items count: ${(_approvalData!['items'] as List<dynamic>? ?? []).length}');
        print('PO Ops Detail - Approval Flows count: ${(_approvalData!['approval_flows'] as List<dynamic>? ?? []).length}');
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading PO Ops details: $e');
      print('Error stack trace: ${StackTrace.current}');
      setState(() {
        _approvalData = null;
        _isLoading = false;
      });
    }
  }

  // Helper function to safely parse double from JSON (handles both string and number)
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rp 0';
    // Use default locale to avoid locale initialization issues
    final formatter = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  Future<void> _handleApprove() async {
    if (_isProcessing) return;

    // Budget validation removed - only show budget info, no blocking validation
    // Budget limit check only applies to PR Ops approval, not PO Ops approval

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text(
              'Konfirmasi Persetujuan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menyetujui PO ini?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _approvalService.approvePoOps(
        widget.poId,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PO berhasil disetujui'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menyetujui PO'),
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
          _isProcessing = false;
        });
      }
    }
  }

  bool _validateBudget() {
    if (_approvalData == null) return true;
    
    final budgetInfo = _approvalData!['budget_info'];
    if (budgetInfo == null) return true; // Skip validation if no budget info
    
    final poAmount = _parseDouble(_approvalData!['grand_total']) ?? 0.0;
    final budgetType = budgetInfo['budget_type'] as String? ?? 'GLOBAL';
    
    // For PER_OUTLET budget, validate using itemsBudgetInfo (per outlet+category)
    if (budgetType == 'PER_OUTLET') {
      final itemsBudgetInfo = _approvalData!['items_budget_info'] as Map<String, dynamic>?;
      if (itemsBudgetInfo != null && itemsBudgetInfo.isNotEmpty) {
        // Get items to validate per outlet+category
        final items = _approvalData!['items'] as List<dynamic>? ?? [];
        
        // Group items by outlet+category and validate each group
        final Map<String, double> groupAmounts = {};
        for (var item in items) {
          // Get outlet_id and category_id from item's prOpsItem or source
          final prOpsItem = item['pr_ops_item'] as Map<String, dynamic>?;
          final outletId = prOpsItem?['outlet_id']?.toString();
          final categoryId = prOpsItem?['category_id']?.toString();
          
          if (outletId != null && categoryId != null) {
            final key = '${outletId}_${categoryId}';
            final itemTotal = _parseDouble(item['total']) ?? 0.0;
            groupAmounts[key] = (groupAmounts[key] ?? 0.0) + itemTotal;
          }
        }
        
        // Validate each outlet+category group
        for (var entry in groupAmounts.entries) {
          final key = entry.key;
          final groupAmount = entry.value;
          
          if (itemsBudgetInfo[key] != null) {
            final groupBudgetInfo = itemsBudgetInfo[key] as Map<String, dynamic>;
            final outletBudget = _parseDouble(groupBudgetInfo['outlet_budget']) ?? 0.0;
            final outletUsedAmount = _parseDouble(groupBudgetInfo['outlet_used_amount']) ?? 0.0;
            final realRemainingBudget = _parseDouble(groupBudgetInfo['real_remaining_budget']) ?? 
                                       (outletBudget - outletUsedAmount);
            
            // Calculate total after approving this PO group
            final totalAfterApproval = outletUsedAmount + groupAmount;
            
            // Check if approving will exceed budget
            if (totalAfterApproval > outletBudget || realRemainingBudget < groupAmount) {
              final exceededAmount = totalAfterApproval > outletBudget 
                  ? totalAfterApproval - outletBudget 
                  : groupAmount - realRemainingBudget;
              
              _showBudgetExceededDialog(
                totalBudget: outletBudget,
                usedAmount: outletUsedAmount,
                poAmount: groupAmount,
                totalAfterApproval: totalAfterApproval,
                exceededAmount: exceededAmount,
                remainingAmount: realRemainingBudget,
                budgetType: budgetType,
              );
              return false;
            }
          }
        }
        
        // All groups passed validation
        return true;
      }
    }
    
    // For GLOBAL budget, use budget_info
    final totalBudget = _getTotalBudget(budgetInfo);
    final usedAmount = _getUsedAmount(budgetInfo);
    final remainingAmount = _getRemainingAmount(budgetInfo);
    final realRemainingBudget = _parseDouble(budgetInfo['real_remaining_budget']) ?? remainingAmount;
    
    // Calculate total after approving this PO
    final totalAfterApproval = usedAmount + poAmount;
    
    // Check if approving will exceed budget
    if (totalAfterApproval > totalBudget) {
      final exceededAmount = totalAfterApproval - totalBudget;
      
      _showBudgetExceededDialog(
        totalBudget: totalBudget,
        usedAmount: usedAmount,
        poAmount: poAmount,
        totalAfterApproval: totalAfterApproval,
        exceededAmount: exceededAmount,
        remainingAmount: realRemainingBudget,
        budgetType: budgetType,
      );
      return false;
    }
    
    // Additional check: if real remaining budget is less than PO amount
    if (realRemainingBudget < poAmount) {
      final exceededAmount = poAmount - realRemainingBudget;
      
      _showBudgetExceededDialog(
        totalBudget: totalBudget,
        usedAmount: usedAmount,
        poAmount: poAmount,
        totalAfterApproval: totalAfterApproval,
        exceededAmount: exceededAmount,
        remainingAmount: realRemainingBudget,
        budgetType: budgetType,
      );
      return false;
    }
    
    return true;
  }

  void _showBudgetExceededDialog({
    required double totalBudget,
    required double usedAmount,
    required double poAmount,
    required double totalAfterApproval,
    required double exceededAmount,
    required double remainingAmount,
    required String budgetType,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Budget Melebihi Limit',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tidak dapat menyetujui PO karena budget akan melebihi limit!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBudgetInfoRow('Total Budget', totalBudget, Colors.blue),
                    _buildBudgetInfoRow('Budget Terpakai', usedAmount, Colors.orange),
                    _buildBudgetInfoRow('Jumlah PO', poAmount, Colors.purple),
                    _buildBudgetInfoRow('Total Setelah Approve', totalAfterApproval, Colors.red),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Melebihi: ${_formatCurrency(exceededAmount)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sisa budget: ${_formatCurrency(remainingAmount)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
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
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetInfoRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Tolak PO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alasan Penolakan:'),
            const SizedBox(height: 8),
            TextField(
              controller: _rejectReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Masukkan alasan penolakan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Komentar (Opsional):'),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Masukkan komentar',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectReasonController.clear();
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _handleReject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;

    if (_rejectReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan penolakan harus diisi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _approvalService.rejectPoOps(
        widget.poId,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        reason: _rejectReasonController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PO berhasil ditolak'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menolak PO'),
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
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error boundary wrapper
    return Builder(
      builder: (context) {
        try {
          if (_isLoading) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('PO Ops Approval Detail'),
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              body: const Center(
                child: AppLoadingIndicator(),
              ),
            );
          }

          if (_approvalData == null) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('PO Ops Approval Detail'),
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Data tidak ditemukan',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        _loadApprovalDetails();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final po = _approvalData!;
          final budgetInfo = _approvalData!['budget_info'] as Map<String, dynamic>?;
          final approvalFlows = (_approvalData!['approval_flows'] as List<dynamic>?) ?? [];
          final items = (_approvalData!['items'] as List<dynamic>?) ?? [];
          
          // Debug: Print extracted data
          print('PO Ops Detail Build - PO keys: ${po.keys.toList()}');
          print('PO Ops Detail Build - PO number: ${po['number']}');
          print('PO Ops Detail Build - Budget Info: ${budgetInfo != null ? "exists" : "null"}');
          print('PO Ops Detail Build - Items count: ${items.length}');
          print('PO Ops Detail Build - Approval Flows count: ${approvalFlows.length}');
          
          return _buildMainContent(context, po, budgetInfo, approvalFlows, items);
        } catch (e, stackTrace) {
          print('Error in PO Ops Detail build: $e');
          print('Stack trace: $stackTrace');
          return Scaffold(
            appBar: AppBar(
              title: const Text('PO Ops Approval Detail'),
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Terjadi kesalahan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadApprovalDetails();
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    Map<String, dynamic> po,
    Map<String, dynamic>? budgetInfo,
    List<dynamic> approvalFlows,
    List<dynamic> items,
  ) {

    return Scaffold(
      appBar: AppBar(
        title: Text(po['number'] ?? 'PO Ops Approval Detail'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Basic Info - Always show
            Builder(
              builder: (context) {
                try {
                  return _buildSection(
                    'Informasi Dasar',
                    [
                      _buildInfoRow('PO Number', po['number']?.toString() ?? '-'),
                      _buildInfoRow('Supplier', () {
                        if (po['supplier'] is Map) {
                          return (po['supplier'] as Map?)?['name']?.toString() ?? '-';
                        }
                        return po['supplier_name']?.toString() ?? '-';
                      }()),
                      _buildInfoRow('Grand Total', _formatCurrency(_parseDouble(po['grand_total']))),
                      if (po['purchase_requisition'] != null) ...[
                        _buildInfoRow('PR Number', () {
                          if (po['purchase_requisition'] is Map) {
                            return (po['purchase_requisition'] as Map)['pr_number']?.toString() ?? '-';
                          }
                          return po['pr_number']?.toString() ?? '-';
                        }()),
                        _buildInfoRow('PR Title', () {
                          if (po['purchase_requisition'] is Map) {
                            return (po['purchase_requisition'] as Map)['title']?.toString() ?? '-';
                          }
                          return po['pr_title']?.toString() ?? '-';
                        }()),
                      ],
                      if (po['purchase_requisition'] is Map && (po['purchase_requisition'] as Map)['outlet'] != null)
                        _buildInfoRow('Outlet', ((po['purchase_requisition'] as Map)['outlet'] as Map?)?['nama_outlet']?.toString() ?? '-'),
                      if (po['purchase_requisition'] is Map && (po['purchase_requisition'] as Map)['division'] != null)
                        _buildInfoRow('Divisi', ((po['purchase_requisition'] as Map)['division'] as Map?)?['nama_divisi']?.toString() ?? '-'),
                      if (po['creator'] is Map)
                        _buildInfoRow('Created By', (po['creator'] as Map)['nama_lengkap']?.toString() ?? '-'),
                    ],
                  );
                } catch (e) {
                  print('Error building Basic Info section: $e');
                  return _buildSection(
                    'Informasi Dasar',
                    [
                      _buildInfoRow('PO Number', po['number']?.toString() ?? '-'),
                      _buildInfoRow('Error', 'Gagal memuat data detail'),
                    ],
                  );
                }
              },
            ),

            // Budget Info - Only show if GLOBAL, PER_OUTLET will be shown at item level
            if (budgetInfo != null && (budgetInfo['budget_type'] as String? ?? 'GLOBAL') == 'GLOBAL') ...[
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  try {
                    return _buildBudgetInfoSection(budgetInfo);
                  } catch (e) {
                    print('Error building Budget Info section: $e');
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],

            // Approval Flow - Always show section, even if empty
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                try {
                  if (approvalFlows.isNotEmpty) {
                    return _buildApprovalFlowSection(approvalFlows);
                  } else {
                    return _buildSection(
                      'Approval Flow',
                      [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Tidak ada data approval flow',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    );
                  }
                } catch (e) {
                  print('Error building Approval Flow section: $e');
                  return const SizedBox.shrink();
                }
              },
            ),

            // Items - Always show section, even if empty
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                try {
                  if (items.isNotEmpty) {
                    return _buildItemsSection(items);
                  } else {
                    return _buildSection(
                      'Items',
                      [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Tidak ada items',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    );
                  }
                } catch (e) {
                  print('Error building Items section: $e');
                  return _buildSection(
                    'Items',
                    [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error memuat items: ${e.toString()}',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),

            // PR Attachments - Check both purchase_requisition and source_pr
            Builder(
              builder: (context) {
                List<dynamic>? prAttachments;
                
                // Try purchase_requisition first
                if (po['purchase_requisition'] != null) {
                  final pr = po['purchase_requisition'];
                  print('PR data: ${pr.keys.toList()}');
                  print('PR attachments type: ${pr['attachments'].runtimeType}');
                  print('PR attachments: ${pr['attachments']}');
                  if (pr['attachments'] != null && pr['attachments'] is List) {
                    prAttachments = pr['attachments'] as List<dynamic>;
                    print('PR attachments count: ${prAttachments.length}');
                  }
                }
                
                // Fallback to source_pr
                if ((prAttachments == null || prAttachments.isEmpty) && po['source_pr'] != null) {
                  final sourcePr = po['source_pr'];
                  print('Source PR data: ${sourcePr.keys.toList()}');
                  print('Source PR attachments type: ${sourcePr['attachments']?.runtimeType}');
                  print('Source PR attachments: ${sourcePr['attachments']}');
                  if (sourcePr['attachments'] != null && sourcePr['attachments'] is List) {
                    prAttachments = sourcePr['attachments'] as List<dynamic>;
                    print('Source PR attachments count: ${prAttachments.length}');
                  }
                }
                
                if (prAttachments != null && prAttachments.isNotEmpty) {
                  print('Displaying PR attachments: ${prAttachments.length}');
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildAttachmentsSection(
                        'Purchase Requisition Attachments',
                        prAttachments,
                        isPrAttachment: true,
                      ),
                    ],
                  );
                }
                print('No PR attachments to display');
                return const SizedBox.shrink();
              },
            ),

            // PO Ops Attachments
            Builder(
              builder: (context) {
                List<dynamic>? poAttachments;
                
                print('PO attachments type: ${po['attachments']?.runtimeType}');
                print('PO attachments: ${po['attachments']}');
                if (po['attachments'] != null && po['attachments'] is List) {
                  poAttachments = po['attachments'] as List<dynamic>;
                  print('PO attachments count: ${poAttachments.length}');
                }
                
                if (poAttachments != null && poAttachments.isNotEmpty) {
                  print('Displaying PO attachments: ${poAttachments.length}');
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildAttachmentsSection(
                        'Purchase Order Attachments',
                        poAttachments,
                        isPrAttachment: false,
                      ),
                    ],
                  );
                }
                print('No PO attachments to display');
                return const SizedBox.shrink();
              },
            ),

            // Comment Section removed - was causing infinite loading

            // Action Buttons
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get total budget based on budget_type
  double _getTotalBudget(Map<String, dynamic> budgetInfo) {
    final budgetType = budgetInfo['budget_type'] as String? ?? 'GLOBAL';
    final outletBudget = _parseDouble(budgetInfo['outlet_budget']) ?? 0.0;
    final categoryBudget = _parseDouble(budgetInfo['category_budget']) ?? 0.0;
    
    if (budgetType == 'PER_OUTLET' && outletBudget > 0) {
      return outletBudget;
    }
    return categoryBudget;
  }
  
  // Helper function to get used amount based on budget_type
  double _getUsedAmount(Map<String, dynamic> budgetInfo) {
    final budgetType = budgetInfo['budget_type'] as String? ?? 'GLOBAL';
    final outletUsedAmount = _parseDouble(budgetInfo['outlet_used_amount']) ?? 0.0;
    final categoryUsedAmount = _parseDouble(budgetInfo['category_used_amount']) ?? 0.0;
    
    if (budgetType == 'PER_OUTLET' && outletUsedAmount > 0) {
      return outletUsedAmount;
    }
    return categoryUsedAmount;
  }
  
  // Helper function to get remaining amount based on budget_type
  double _getRemainingAmount(Map<String, dynamic> budgetInfo) {
    final budgetType = budgetInfo['budget_type'] as String? ?? 'GLOBAL';
    final outletRemainingAmount = _parseDouble(budgetInfo['outlet_remaining_amount']) ?? 0.0;
    final categoryRemainingAmount = _parseDouble(budgetInfo['category_remaining_amount']) ?? 0.0;
    
    if (budgetType == 'PER_OUTLET' && outletRemainingAmount != 0.0) {
      return outletRemainingAmount;
    }
    return categoryRemainingAmount;
  }

  Widget _buildBudgetInfoSection(Map<String, dynamic> budgetInfo) {
    // Get budget values using helper functions
    final budgetType = budgetInfo['budget_type'] as String? ?? 'GLOBAL';
    final totalBudget = _getTotalBudget(budgetInfo);
    final usedAmount = _getUsedAmount(budgetInfo);
    final remainingAmount = _getRemainingAmount(budgetInfo);
    
    // Get real remaining budget (from backend calculation)
    double realRemainingBudget = _parseDouble(budgetInfo['real_remaining_budget']) ?? remainingAmount;
    
    // If real_remaining_budget is 0 or not provided, use remaining_amount
    if (realRemainingBudget == 0.0) {
      realRemainingBudget = remainingAmount;
    }
    
    // Get additional values for display
    final categoryBudget = _parseDouble(budgetInfo['category_budget']) ?? 0.0;
    final outletBudget = _parseDouble(budgetInfo['outlet_budget']) ?? 0.0;
    final categoryRemainingAmount = _parseDouble(budgetInfo['category_remaining_amount']) ?? 0.0;
    
    // Get current PO amount
    final poAmount = _parseDouble(_approvalData?['grand_total']) ?? 0.0;
    
    // Calculate remaining after approving this PO
    final remainingAfterApprove = realRemainingBudget - poAmount;
    
    return Column(
      children: [
        // Total Budget Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budgetType == 'PER_OUTLET' ? 'Outlet Budget' : 'Total Budget (Global)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        if (budgetType == 'PER_OUTLET' && categoryBudget > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Global Budget: ${_formatCurrency(categoryBudget)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(totalBudget),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Remaining Budget Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: realRemainingBudget >= 0 
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : [Colors.red.shade50, Colors.red.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: realRemainingBudget >= 0 
                  ? Colors.green.shade300 
                  : Colors.red.shade300, 
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    realRemainingBudget >= 0 
                        ? Icons.check_circle 
                        : Icons.warning,
                    color: realRemainingBudget >= 0 
                        ? Colors.green.shade700 
                        : Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budgetType == 'PER_OUTLET' ? 'Sisa Budget Real (Outlet)' : 'Sisa Budget Real (Global)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: realRemainingBudget >= 0 
                                ? Colors.green.shade900 
                                : Colors.red.shade900,
                          ),
                        ),
                        if (budgetType == 'PER_OUTLET' && categoryRemainingAmount != 0.0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Sisa Global: ${_formatCurrency(categoryRemainingAmount)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(realRemainingBudget),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: realRemainingBudget >= 0 
                      ? Colors.green.shade900 
                      : Colors.red.shade900,
                ),
              ),
              if (poAmount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: remainingAfterApprove >= 0 
                        ? Colors.green.shade100 
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        remainingAfterApprove >= 0 
                            ? Icons.info_outline 
                            : Icons.warning_amber_rounded,
                        color: remainingAfterApprove >= 0 
                            ? Colors.green.shade700 
                            : Colors.red.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Setelah approve PO ini: ${_formatCurrency(remainingAfterApprove)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: remainingAfterApprove >= 0 
                                ? Colors.green.shade900 
                                : Colors.red.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Breakdown Budget Summary - Always try to render with error handling
        Builder(
          builder: (context) {
            try {
              // Check if any breakdown data exists
              final hasApproved = budgetInfo['approved_amount'] != null;
              final hasUnapproved = budgetInfo['unapproved_amount'] != null;
              final hasPoCreated = budgetInfo['po_created_amount'] != null;
              final hasPaid = budgetInfo['paid_amount'] != null;
              final hasUnpaid = budgetInfo['unpaid_amount'] != null;
              final hasAnyBreakdown = hasApproved || hasUnapproved || hasPoCreated || hasPaid || hasUnpaid;
              
              if (!hasAnyBreakdown) {
                // Debug: Print budget info to see what's available
                print('PO Ops Budget Info - No breakdown data found. Keys: ${budgetInfo.keys.toList()}');
                return const SizedBox.shrink();
              }
              
              return Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade50,
                          Colors.amber.shade50,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.shade200,
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
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade400, Colors.amber.shade400],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.pie_chart, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Breakdown Budget',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (hasApproved)
                              _buildBreakdownSummaryCard(
                                'Sudah Di-Approved',
                                _parseDouble(budgetInfo['approved_amount']) ?? 0.0,
                                Colors.green,
                                Icons.check_circle,
                              ),
                            if (hasUnapproved)
                              _buildBreakdownSummaryCard(
                                'Belum Di-Approved',
                                _parseDouble(budgetInfo['unapproved_amount']) ?? 0.0,
                                Colors.orange,
                                Icons.access_time,
                              ),
                            if (hasPoCreated)
                              _buildBreakdownSummaryCard(
                                'Sudah Dibuat PO',
                                _parseDouble(budgetInfo['po_created_amount']) ?? 0.0,
                                Colors.blue,
                                Icons.shopping_cart,
                              ),
                            if (hasPaid)
                              _buildBreakdownSummaryCard(
                                'Sudah Di-Bayar',
                                _parseDouble(budgetInfo['paid_amount']) ?? 0.0,
                                Colors.green,
                                Icons.check_circle_outline,
                              ),
                            if (hasUnpaid)
                              _buildBreakdownSummaryCard(
                                'Belum Di-Bayar',
                                _parseDouble(budgetInfo['unpaid_amount']) ?? 0.0,
                                Colors.orange,
                                Icons.error_outline,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } catch (e, stackTrace) {
              print('Error building Breakdown Budget section: $e');
              print('Stack trace: $stackTrace');
              // Return empty widget instead of crashing
              return const SizedBox.shrink();
            }
          },
        ),
        // Budget Breakdown Detail - Always try to render with error handling
        Builder(
          builder: (context) {
            try {
              if (budgetInfo['breakdown'] == null) {
                return const SizedBox.shrink();
              }
              
              final breakdown = budgetInfo['breakdown'];
              if (breakdown is! Map) {
                print('PO Ops Budget Info - Breakdown is not a Map: ${breakdown.runtimeType}');
                return const SizedBox.shrink();
              }
              
              return Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withOpacity(0.1),
                          const Color(0xFF8B5CF6).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
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
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.list_alt, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Budget Breakdown Detail',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._buildBudgetBreakdown(breakdown as Map<String, dynamic>),
                      ],
                    ),
                  ),
                ],
              );
            } catch (e, stackTrace) {
              print('Error building Budget Breakdown Detail section: $e');
              print('Stack trace: $stackTrace');
              // Return empty widget instead of crashing
              return const SizedBox.shrink();
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildBreakdownSummaryCard(String label, double amount, MaterialColor color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color.shade700, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color.shade900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _calculateGroupBudgetInfo({
    required String outletId,
    required String categoryId,
    required Map<String, dynamic> category,
    required double groupTotal,
  }) {
    // First, try to get budget info from itemsBudgetInfo (per outlet+category from backend)
    final itemsBudgetInfo = _approvalData?['items_budget_info'] as Map<String, dynamic>?;
    final key = '${outletId}_${categoryId}';
    
    print('_calculateGroupBudgetInfo called for outlet=$outletId category=$categoryId');
    print('ItemsBudgetInfo available: ${itemsBudgetInfo != null}');
    if (itemsBudgetInfo != null) {
      print('ItemsBudgetInfo keys: ${itemsBudgetInfo.keys.toList()}');
      print('Looking for key: $key');
      print('Key exists: ${itemsBudgetInfo.containsKey(key)}');
    }
    
    if (itemsBudgetInfo != null && itemsBudgetInfo[key] != null) {
      final budgetInfo = itemsBudgetInfo[key] as Map<String, dynamic>;
      print('Found budget info for key $key: $budgetInfo');
      final outletBudget = _parseDouble(budgetInfo['outlet_budget']) ?? 0.0;
      final usedAmount = _parseDouble(budgetInfo['outlet_used_amount']) ?? 0.0;
      final remainingAmount = _parseDouble(budgetInfo['real_remaining_budget']) ?? 
                              _parseDouble(budgetInfo['outlet_remaining_amount']) ?? 
                              (outletBudget - usedAmount);
      
      return {
        'outlet_id': outletId,
        'category_id': categoryId,
        'outlet_budget': outletBudget,
        'used_amount': usedAmount,
        'remaining_amount': remainingAmount,
        'real_remaining_budget': remainingAmount, // Use real_remaining_budget from backend
        'group_total': groupTotal,
        'budget_type': 'PER_OUTLET',
        'category_budget': _parseDouble(budgetInfo['category_budget']) ?? 0.0,
      };
    }
    
    // Fallback: Get budget limit from category
    final categoryBudgetLimit = _parseDouble(category['budget_limit']) ?? 0.0;
    
    // For PER_OUTLET, we need to get outlet budget from outlet_budgets table
    // Since we don't have direct access in frontend, we'll try to get from budget_info
    // or use category budget_limit as fallback
    double outletBudget = categoryBudgetLimit;
    
    // Try to get outlet budget from budget_info if available
    if (_approvalData?['budget_info'] != null) {
      final budgetInfo = _approvalData!['budget_info'];
      final outletBudgetFromInfo = _parseDouble(budgetInfo['outlet_budget']);
      if (outletBudgetFromInfo != null && outletBudgetFromInfo > 0) {
        outletBudget = outletBudgetFromInfo;
      }
    }
    
    // Get used amount from budget_info if available
    // For PER_OUTLET, we need the used amount for this specific outlet+category
    // Since we don't have this data directly, we'll use the groupTotal as approximation
    double usedAmount = 0.0;
    if (_approvalData?['budget_info'] != null) {
      final budgetInfo = _approvalData!['budget_info'];
      final outletUsedAmount = _parseDouble(budgetInfo['outlet_used_amount']);
      if (outletUsedAmount != null) {
        usedAmount = outletUsedAmount;
      } else {
        // Fallback: use groupTotal as used amount for this group
        usedAmount = groupTotal;
      }
    } else {
      usedAmount = groupTotal;
    }
    
    // Calculate remaining
    final remainingAmount = outletBudget - usedAmount;
    
    return {
      'outlet_id': outletId,
      'category_id': categoryId,
      'outlet_budget': outletBudget,
      'used_amount': usedAmount,
      'remaining_amount': remainingAmount,
      'group_total': groupTotal,
      'budget_type': 'PER_OUTLET',
      'category_budget': categoryBudgetLimit,
    };
  }

  Widget _buildInlineBudgetInfo(Map<String, dynamic> budgetInfo) {
    final outletBudget = _parseDouble(budgetInfo['outlet_budget']) ?? 0.0;
    final usedAmount = _parseDouble(budgetInfo['used_amount']) ?? 0.0;
    // Prioritize real_remaining_budget from backend (already includes current PO amount)
    final remainingAmount = _parseDouble(budgetInfo['real_remaining_budget']) ?? 
                            _parseDouble(budgetInfo['remaining_amount']) ?? 
                            (outletBudget - usedAmount);
    final groupTotal = _parseDouble(budgetInfo['group_total']) ?? 0.0;
    
    // Calculate remaining after approving this PO group
    // real_remaining_budget from backend already includes current PO amount
    // So remainingAfterApprove is the same as remainingAmount
    final remainingAfterApprove = remainingAmount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: remainingAfterApprove >= 0 
                  ? Colors.green.shade700 
                  : Colors.red.shade700,
              size: 16,
            ),
            const SizedBox(width: 6),
            const Text(
              'Budget Info',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Limit',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(outletBudget),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Used Budget',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(usedAmount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Sisa Budget',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(remainingAmount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: remainingAmount >= 0 
                          ? Colors.green.shade700 
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (groupTotal > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: remainingAfterApprove >= 0 
                  ? Colors.green.shade50 
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  remainingAfterApprove >= 0 
                      ? Icons.info_outline 
                      : Icons.warning_amber_rounded,
                  color: remainingAfterApprove >= 0 
                      ? Colors.green.shade700 
                      : Colors.red.shade700,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Setelah approve: ${_formatCurrency(remainingAfterApprove)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: remainingAfterApprove >= 0 
                          ? Colors.green.shade900 
                          : Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBudgetBreakdown(Map<String, dynamic> breakdown) {
    return [
      _buildBreakdownItem(
        'PR Unpaid',
        _parseDouble(breakdown['pr_unpaid']) ?? 0.0,
        Colors.blue,
        'PR Submitted & Approved yang belum dibuat PO',
      ),
      _buildBreakdownItem(
        'PO Unpaid',
        _parseDouble(breakdown['po_unpaid']) ?? 0.0,
        Colors.blue,
        'PO Submitted & Approved yang belum dibuat NFP',
      ),
      _buildBreakdownItem(
        'NFP Submitted',
        _parseDouble(breakdown['nfp_submitted']) ?? 0.0,
        Colors.orange,
        null,
      ),
      _buildBreakdownItem(
        'NFP Approved',
        _parseDouble(breakdown['nfp_approved']) ?? 0.0,
        Colors.amber,
        null,
      ),
      _buildBreakdownItem(
        'NFP Paid',
        _parseDouble(breakdown['nfp_paid']) ?? 0.0,
        Colors.green,
        null,
      ),
      _buildBreakdownItem(
        'Retail Non Food',
        _parseDouble(breakdown['retail_non_food']) ?? 0.0,
        Colors.purple,
        'Status: Approved',
      ),
    ];
  }

  Widget _buildBreakdownItem(String label, double amount, MaterialColor color, String? description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getBreakdownIcon(label),
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color.shade900,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getBreakdownIcon(String label) {
    if (label.contains('PR')) return Icons.description;
    if (label.contains('PO')) return Icons.shopping_cart;
    if (label.contains('NFP')) return Icons.payment;
    if (label.contains('Retail')) return Icons.store;
    return Icons.info;
  }

  Widget _buildApprovalFlowSection(List<dynamic> flows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval Flow',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ...flows.map((flow) => _buildApprovalFlowItem(flow)),
        ],
      ),
    );
  }

  Widget _buildApprovalFlowItem(Map<String, dynamic> flow) {
    // Convert status to lowercase for case-insensitive comparison
    final status = (flow['status'] ?? 'pending').toString().toLowerCase();
    final approverName = flow['approver']?['nama_lengkap'] ?? 'N/A';
    final approvedAt = flow['approved_at'];
    final comment = flow['comment'] ?? flow['comments']; // Support both 'comment' and 'comments'

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Approved';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Rejected';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
      statusText = 'Pending';
    }

    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  approverName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (approvedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${dateFormat.format(DateTime.parse(approvedAt))} ${timeFormat.format(DateTime.parse(approvedAt))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                comment,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<dynamic> items) {
    // Check if budget type is PER_OUTLET
    final budgetType = _approvalData?['budget_info']?['budget_type'] as String? ?? 'GLOBAL';
    final isPerOutlet = budgetType == 'PER_OUTLET';
    
    // If PER_OUTLET, group items by outlet_id and category_id
    if (isPerOutlet) {
      final Map<String, List<Map<String, dynamic>>> groupedItems = {};
      
      for (var item in items) {
        if (item is! Map<String, dynamic>) continue;
        
        // Get outlet_id and category_id from pr_ops_item
        String? outletId;
        String? categoryId;
        
        if (item['pr_ops_item'] != null) {
          final prOpsItem = item['pr_ops_item'];
          if (prOpsItem is Map) {
            outletId = prOpsItem['outlet_id']?.toString() ?? 'no_outlet';
            categoryId = prOpsItem['category_id']?.toString() ?? 'no_category';
          }
        }
        
        // Fallback to direct fields
        if (outletId == null) {
          outletId = item['outlet_id']?.toString() ?? 'no_outlet';
        }
        if (categoryId == null) {
          categoryId = item['category_id']?.toString() ?? 'no_category';
        }
        
        final groupKey = '$outletId|$categoryId';
        if (!groupedItems.containsKey(groupKey)) {
          groupedItems[groupKey] = [];
        }
        groupedItems[groupKey]!.add(item);
      }
      
      // Build widgets for each group
      final List<Widget> widgets = [];
      groupedItems.forEach((key, groupItems) {
        // Get outlet and category info from first item
        final firstItem = groupItems[0];
        String? outletName;
        String? categoryName;
        String? divisionName;
        
        if (firstItem['pr_ops_item'] != null) {
          final prOpsItem = firstItem['pr_ops_item'];
          if (prOpsItem is Map) {
            if (prOpsItem['outlet'] is Map) {
              outletName = prOpsItem['outlet']['nama_outlet']?.toString();
            }
            if (prOpsItem['category'] is Map) {
              final category = prOpsItem['category'];
              categoryName = category['name']?.toString();
              divisionName = category['division']?.toString();
            }
          }
        }
        
        // Calculate total amount for this group
        double groupTotal = 0.0;
        for (var item in groupItems) {
          final qty = _parseDouble(item['qty'] ?? item['quantity'] ?? item['qty_ordered'] ?? item['qty_received']) ?? 0.0;
          final price = _parseDouble(item['price'] ?? item['unit_price'] ?? item['harga']) ?? 0.0;
          final subtotal = _parseDouble(item['subtotal'] ?? item['total'] ?? item['amount']) ?? (qty * price);
          groupTotal += subtotal;
        }
        
        // Calculate budget info for this group if PER_OUTLET
        Map<String, dynamic>? groupBudgetInfo;
        if (firstItem['pr_ops_item'] != null) {
          final prOpsItem = firstItem['pr_ops_item'];
          if (prOpsItem is Map && prOpsItem['category'] is Map) {
            final category = prOpsItem['category'];
            final categoryBudgetType = category['budget_type']?.toString() ?? 'GLOBAL';
            if (categoryBudgetType == 'PER_OUTLET') {
              // Get outlet_id and category_id for budget calculation
              final outletId = prOpsItem['outlet_id']?.toString();
              final categoryId = prOpsItem['category_id']?.toString();
              
              if (outletId != null && categoryId != null) {
                // Calculate budget info for this outlet+category
                groupBudgetInfo = _calculateGroupBudgetInfo(
                  outletId: outletId,
                  categoryId: categoryId,
                  category: category,
                  groupTotal: groupTotal,
                );
              }
            }
          }
        }
        
        // Add group header with budget info integrated
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A90E2).withOpacity(0.1),
                  const Color(0xFF1E3A5F).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4A90E2).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, color: Color(0xFF4A90E2), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (outletName != null)
                            Text(
                              'Outlet: $outletName',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          if (categoryName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              divisionName != null 
                                  ? 'Category: $divisionName - $categoryName'
                                  : 'Category: $categoryName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Total: ${_formatCurrency(groupTotal)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        
        // Add items in this group
        for (var item in groupItems) {
          widgets.add(_buildItemRow(item, showPrOutletInfo: false));
        }
      });
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ...widgets,
          ],
        ),
      );
    }
    
    // If GLOBAL, show items normally without grouping
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item, {bool showPrOutletInfo = true}) {
    // Try multiple possible field names for quantity
    final qty = _parseDouble(item['qty'] ?? item['quantity'] ?? item['qty_ordered'] ?? item['qty_received']) ?? 0.0;
    final price = _parseDouble(item['price'] ?? item['unit_price'] ?? item['harga']) ?? 0.0;
    final subtotal = _parseDouble(item['subtotal'] ?? item['total'] ?? item['amount']) ?? (qty * price);
    
    // Debug: Print item keys to see what fields are available
    print('Item keys: ${item.keys.toList()}');
    print('Item data: $item');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A90E2).withOpacity(0.1),
                  const Color(0xFF1E3A5F).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF1E3A5F)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['item_name'] ?? 'Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PR and Outlet Info
                if (showPrOutletInfo) ...[
                  _buildPrOutletInfo(item),
                  const SizedBox(height: 16),
                ],
                
                // Qty and Unit in one row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Quantity',
                        qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
                        Icons.inventory_2,
                        const Color(0xFF4A90E2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        'Unit',
                        item['unit']?.toString() ?? '-',
                        Icons.square_foot,
                        const Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Price
                _buildInfoCard(
                  'Price',
                  _formatCurrency(price),
                  Icons.price_check,
                  Colors.orange,
                ),
                
                const SizedBox(height: 16),
                
                // Subtotal with highlight
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.15),
                        const Color(0xFF059669).withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.calculate,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCurrency(subtotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
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
    );
  }

  Widget _buildPrOutletInfo(Map<String, dynamic> item) {
    // Get PR info from various possible locations
    String? prNumber;
    String? prTitle;
    String? outletName;
    String? divisionName;
    String? categoryName;
    
    // First priority: Get from pr_ops_item relationship (most reliable)
    if (item['pr_ops_item'] != null) {
      final prOpsItem = item['pr_ops_item'];
      if (prOpsItem is Map) {
        // Get PR info from pr_ops_item.purchase_requisition
        if (prOpsItem['purchase_requisition'] != null) {
          final pr = prOpsItem['purchase_requisition'];
          if (pr is Map) {
            prNumber = pr['pr_number']?.toString() ?? pr['number']?.toString();
            prTitle = pr['title']?.toString();
          }
        }
        
        // Get outlet info from pr_ops_item.outlet
        if (prOpsItem['outlet'] != null) {
          final outlet = prOpsItem['outlet'];
          if (outlet is Map) {
            outletName = outlet['nama_outlet']?.toString() ?? outlet['name']?.toString();
          }
        }
        
        // Get category and division info from pr_ops_item.category
        if (prOpsItem['category'] != null) {
          final category = prOpsItem['category'];
          if (category is Map) {
            categoryName = category['name']?.toString();
            // Get division from category.division (it's an enum field, not a relationship)
            if (category['division'] != null) {
              divisionName = category['division']?.toString();
            }
          }
        }
      }
    }
    
    // Second priority: Try to get PR info from item directly - check purchase_requisition object
    if (prNumber == null && item['purchase_requisition'] != null) {
      final pr = item['purchase_requisition'];
      if (pr is Map) {
        prNumber = pr['pr_number']?.toString() ?? pr['number']?.toString();
        if (prTitle == null) {
          prTitle = pr['title']?.toString();
        }
        if (outletName == null && pr['outlet'] is Map) {
          outletName = pr['outlet']['nama_outlet']?.toString();
        }
        if (divisionName == null && pr['division'] is Map) {
          divisionName = pr['division']['nama_divisi']?.toString();
        }
        if (categoryName == null && pr['category'] is Map) {
          categoryName = pr['category']['name']?.toString();
        }
      }
    }
    
    // Third priority: Try alternative field names from item directly
    if (prNumber == null) {
      prNumber = item['pr_number']?.toString() ?? 
                 item['pr_id']?.toString() ?? 
                 item['purchase_requisition_id']?.toString();
    }
    if (prTitle == null) {
      prTitle = item['pr_title']?.toString();
    }
    
    // Get outlet info - try multiple ways
    if (outletName == null) {
      if (item['outlet'] is Map) {
        outletName = item['outlet']['nama_outlet']?.toString() ?? 
                     item['outlet']['name']?.toString();
      } else {
        outletName = item['outlet_name']?.toString();
      }
    }
    
    // Get division info
    if (divisionName == null) {
      if (item['division'] is Map) {
        divisionName = item['division']['nama_divisi']?.toString() ?? 
                       item['division']['name']?.toString();
      } else {
        divisionName = item['division_name']?.toString();
      }
    }
    
    // Get category info - try from category object or category_id lookup
    if (categoryName == null) {
      if (item['category'] is Map) {
        categoryName = item['category']['name']?.toString();
        // Also try to get division from category if not found
        if (divisionName == null && item['category']['division'] is Map) {
          divisionName = item['category']['division']['nama_divisi']?.toString();
        }
      } else {
        categoryName = item['category_name']?.toString();
      }
    }
    
    // Fallback: Try to get from PO level if not found in item
    if (_approvalData != null) {
      final po = _approvalData!;
      
      // Try purchase_requisition at PO level
      if (prNumber == null && po['purchase_requisition'] != null) {
        final poPr = po['purchase_requisition'];
        if (poPr is Map) {
          prNumber = poPr['pr_number']?.toString() ?? poPr['number']?.toString();
          if (prTitle == null) {
            prTitle = poPr['title']?.toString();
          }
        }
      }
      
      // Try source_pr at PO level
      if (prNumber == null && po['source_pr'] != null) {
        final sourcePr = po['source_pr'];
        if (sourcePr is Map) {
          prNumber = sourcePr['pr_number']?.toString() ?? sourcePr['number']?.toString();
          if (prTitle == null) {
            prTitle = sourcePr['title']?.toString();
          }
        }
      }
      
      // Get outlet from PO level
      if (outletName == null) {
        if (po['purchase_requisition'] != null) {
          final poPr = po['purchase_requisition'];
          if (poPr is Map && poPr['outlet'] is Map) {
            outletName = poPr['outlet']['nama_outlet']?.toString();
          }
        }
      }
    }
    
    // Debug: Print item keys to see what fields are available
    print('Item keys for PR/Outlet: ${item.keys.toList()}');
    print('Item pr_ops_item: ${item['pr_ops_item']}');
    print('Item purchase_requisition: ${item['purchase_requisition']}');
    print('Item outlet: ${item['outlet']}');
    print('Item category: ${item['category']}');
    print('PR Number: $prNumber, Outlet: $outletName, Category: $categoryName, Division: $divisionName');
    
    // Always show the section, even if some info is missing
    // This helps identify which items belong to which PR/Outlet
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.purple,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Informasi PR & Outlet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.description, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prNumber != null ? 'PR: $prNumber' : 'PR: -',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (prTitle != null && prTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                prTitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.store, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  outletName != null ? 'Outlet: $outletName' : 'Outlet: -',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (categoryName != null && categoryName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    divisionName != null && divisionName.isNotEmpty
                        ? 'Category: $divisionName - $categoryName'
                        : 'Category: $categoryName',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (divisionName != null && divisionName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Divisi: $divisionName',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Komentar (Opsional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Masukkan komentar',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _showRejectDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Tolak',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Setujui',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(String title, List<dynamic> attachments, {required bool isPrAttachment}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file,
                color: isPrAttachment ? Colors.blue : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPrAttachment ? Colors.blue : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${attachments.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPrAttachment ? Colors.blue : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75, // Reduced to accommodate text below image
                ),
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  return _buildAttachmentItem(attachments[index], isPrAttachment);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment, bool isPrAttachment) {
    final fileName = attachment['file_name'] ?? 'Unknown';
    final fileSize = attachment['file_size'] ?? 0;
    final attachmentId = attachment['id'];
    final filePath = attachment['file_path'] ?? attachment['path'] ?? '';
    
    // Check if it's an image - same logic as web version
    final isImage = _isImageFile(fileName);
    
    // Build view URL - use storage URL if file_path exists, otherwise use API endpoint
    String viewUrl;
    if (filePath.isNotEmpty) {
      if (filePath.startsWith('http')) {
        viewUrl = filePath;
      } else if (filePath.startsWith('/')) {
        viewUrl = '${AuthService.storageUrl}$filePath';
      } else {
        viewUrl = '${AuthService.storageUrl}/storage/$filePath';
      }
    } else {
      // Fallback to API endpoint if no file_path
      final baseUrl = ApprovalService.baseUrl;
      viewUrl = isPrAttachment
          ? '$baseUrl/api/approval-app/purchase-requisitions/attachments/$attachmentId/view'
          : '$baseUrl/api/approval-app/po-ops/attachments/$attachmentId/view';
    }

    if (isImage) {
      // Image thumbnail - same style as web version
      return FutureBuilder<String?>(
        future: _approvalService.getToken(),
        builder: (context, snapshot) {
          final token = snapshot.data;
          final headers = token != null
              ? {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                }
              : null;
          
          return InkWell(
            onTap: () {
              // Open lightbox for image
              if (token != null) {
                ImageLightbox.show(
                  context,
                  imageUrl: viewUrl,
                  fileName: fileName,
                  headers: headers,
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isPrAttachment ? Colors.blue : Colors.orange).withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: token != null && headers != null
                          ? CachedNetworkImage(
                              imageUrl: viewUrl,
                              fit: BoxFit.cover,
                              httpHeaders: headers,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                print('Image load error: $error');
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    fileName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatFileSize(fileSize),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Non-image file - open directly in browser (not download)
      return InkWell(
        onTap: () => _openAttachment(viewUrl),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isPrAttachment ? Colors.blue : Colors.orange).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (isPrAttachment ? Colors.blue : Colors.orange).withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getFileIcon(fileName),
                size: 32,
                color: isPrAttachment ? Colors.blue : Colors.orange,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatFileSize(fileSize),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
  }

  bool _isImageFile(String fileName) {
    // Same logic as web version
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final extension = fileName.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    // Same logic as web version: Math.floor(Math.log(bytes) / Math.log(k))
    if (bytes == 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    
    // Use logarithm to determine the correct index (same as web version)
    // Math.floor(Math.log(bytes) / Math.log(k))
    final i = bytes == 0 
        ? 0 
        : math.max(0, math.min(3, (math.log(bytes) / math.log(k)).floor()));
    
    if (i == 0) return '$bytes ${sizes[0]}';
    
    // Calculate correctly: bytes / (k^i)
    final size = bytes / math.pow(k, i);
    return '${size.toStringAsFixed(2)} ${sizes[i]}';
  }

  Future<void> _openAttachment(String url) async {
    try {
      // Get token for authenticated access
      final token = await _approvalService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka attachment: Token tidak ditemukan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mengunduh attachment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Download file with authentication
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final fileName = url.split('/').last.split('?').first;
        // Ensure unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${timestamp}_$fileName';
        final file = File('${tempDir.path}/$uniqueFileName');
        
        // Write file
        await file.writeAsBytes(response.bodyBytes);
        
        print('File saved to: ${file.path}');
        print('File name: $fileName');
        print('File exists: ${await file.exists()}');
        print('File size: ${await file.length()} bytes');
        
        // Check if file is PDF (check both extension and content type)
        final isPdf = fileName.toLowerCase().endsWith('.pdf') || 
                      response.headers['content-type']?.toLowerCase().contains('pdf') == true;
        
        print('Is PDF: $isPdf');
        print('Content-Type: ${response.headers['content-type']}');
        
        if (isPdf && mounted) {
          print('Opening PDF in-app viewer...');
          // Open PDF in-app viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _PdfViewerScreen(
                filePath: file.path,
                fileName: fileName,
              ),
            ),
          );
        } else {
          print('Opening file with external app...');
          // Open other files with external app
          final result = await OpenFilex.open(file.path);
          if (result.type != ResultType.done) {
            throw Exception('Tidak dapat membuka file: ${result.message}');
          }
        }
      } else {
        throw Exception('Gagal mengunduh file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error opening attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// PDF Viewer Screen
class _PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const _PdfViewerScreen({
    required this.filePath,
    required this.fileName,
  });

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('PDF Viewer Screen initialized');
    print('File path: ${widget.filePath}');
    print('File name: ${widget.fileName}');
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        print('ERROR: File tidak ditemukan: ${widget.filePath}');
        setState(() {
          _errorMessage = 'File tidak ditemukan: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      print('Loading PDF from: ${widget.filePath}');
      print('File size: ${await file.length()} bytes');

      // PdfControllerPinch expects Future<PdfDocument>, not PdfDocument
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );

      // Wait a bit to ensure controller is initialized
      await Future.delayed(const Duration(milliseconds: 100));

      print('PDF Controller created successfully');
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('ERROR loading PDF: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Gagal memuat PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    print('Disposing PDF viewer');
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              // Share PDF file
              final result = await OpenFilex.open(widget.filePath);
              if (result.type != ResultType.done) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tidak dapat membuka file: ${result.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            tooltip: 'Buka dengan aplikasi lain',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadPdf();
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) {
                    print('Building PdfViewPinch widget');
                    return PdfViewPinch(
                      controller: _pdfController,
                      onDocumentLoaded: (PdfDocument document) {
                        print('PDF document loaded successfully');
                        print('Page count: ${document.pagesCount}');
                      },
                      onPageChanged: (int page) {
                        print('Page changed to: $page');
                      },
                    );
                  },
                ),
    );
  }
}

