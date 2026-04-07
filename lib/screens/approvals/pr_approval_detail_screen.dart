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
import '../../models/approval_models.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class PRApprovalDetailScreen extends StatefulWidget {
  final int prId;

  const PRApprovalDetailScreen({
    super.key,
    required this.prId,
  });

  @override
  State<PRApprovalDetailScreen> createState() => _PRApprovalDetailScreenState();
}

class _PRApprovalDetailScreenState extends State<PRApprovalDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApprovalService _approvalService = ApprovalService();
  Map<String, dynamic>? _approvalData;
  bool _isLoading = true;
  bool _isProcessing = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _rejectReasonController = TextEditingController();
  final TextEditingController _newCommentController = TextEditingController();
  late AnimationController _animationController;
  bool _isInternalComment = false;
  bool _isAddingComment = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadApprovalDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _rejectReasonController.dispose();
    _newCommentController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovalDetails() async {
    setState(() {
      _isLoading = true;
    });

    final data = await _approvalService.getPrApprovalDetails(widget.prId);
    
    print('PR Approval Details Response: $data');
    
    setState(() {
      if (data != null) {
        _approvalData = data['purchase_requisition'];
        // Ensure budget_info is included in _approvalData
        if (data['budget_info'] != null && _approvalData != null) {
          _approvalData!['budget_info'] = data['budget_info'];
        }
        // Ensure items_budget_info is included for PR Ops (per outlet+category)
        if (data['items_budget_info'] != null && _approvalData != null) {
          _approvalData!['items_budget_info'] = data['items_budget_info'];
        } else if (data['itemsBudgetInfo'] != null && _approvalData != null) {
          _approvalData!['items_budget_info'] = data['itemsBudgetInfo'];
        }
        // Ensure items is included if it exists at root level
        if (data['items'] != null && _approvalData != null && 
            (_approvalData!['items'] == null || (_approvalData!['items'] as List).isEmpty)) {
          _approvalData!['items'] = data['items'];
        }
        print('PR Approval Data: $_approvalData');
        print('Budget Info: ${_approvalData?['budget_info']}');
        print('Items Budget Info: ${_approvalData?['items_budget_info']}');
        print('PR Items count: ${(_approvalData?['items'] as List<dynamic>? ?? []).length}');
        
        // Debug: Print attachments info
        if (_approvalData != null) {
          print('PR Data keys: ${_approvalData!.keys.toList()}');
          print('PR attachments: ${_approvalData!['attachments']}');
          print('PR attachments type: ${_approvalData!['attachments']?.runtimeType}');
          if (_approvalData!['attachments'] != null && _approvalData!['attachments'] is List) {
            print('PR attachments count: ${(_approvalData!['attachments'] as List).length}');
          }
        }
      }
      _isLoading = false;
    });
    
    _animationController.forward();
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
    final formatter = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      // Handle both string and DateTime objects
      DateTime dt;
      if (dateTime is String) {
        // Parse and convert to local timezone
        dt = DateTime.parse(dateTime).toLocal();
      } else if (dateTime is DateTime) {
        dt = dateTime.toLocal();
      } else {
        return '-';
      }
      
      // Format: "EEE, d MMM yyyy HH.mm" (same as Contra Bon approval detail)
      return DateFormat('EEE, d MMM yyyy HH.mm', 'id_ID').format(dt);
    } catch (e) {
      print('Error formatting date: $e');
      return '-';
    }
  }

  Color _darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  bool _validateBudget() {
    if (_approvalData == null) return true; // Skip validation if no data
    
    final budgetInfo = _approvalData!['budget_info'];
    if (budgetInfo == null) return true; // Skip validation if no budget info (e.g., kasbon mode)
    
    final mode = _approvalData!['mode']?.toString().toLowerCase();
    final budgetType = budgetInfo['budget_type'] as String? ?? 'GLOBAL';
    
    // For PR Ops and purchase_payment mode, validate per outlet+category from items
    if ((mode == 'pr_ops' || mode == 'purchase_payment')) {
      final itemsBudgetInfo = _approvalData!['items_budget_info'] as Map<String, dynamic>?;
      if (itemsBudgetInfo != null && itemsBudgetInfo.isNotEmpty) {
        // Get items to validate per outlet+category
        final items = _approvalData!['items'] as List<dynamic>? ?? [];
        
        // Group items by outlet+category and validate each group
        final Map<String, double> groupAmounts = {};
        for (var item in items) {
          // Get outlet_id and category_id from item
          final outletId = item['outlet_id']?.toString();
          final categoryId = item['category_id']?.toString();
          
          if (outletId != null && categoryId != null) {
            final key = '${outletId}_${categoryId}';
            final itemSubtotal = _parseDouble(item['subtotal']) ?? 0.0;
            groupAmounts[key] = (groupAmounts[key] ?? 0.0) + itemSubtotal;
          }
        }
        
        // Validate each outlet+category group
        for (var entry in groupAmounts.entries) {
          final key = entry.key;
          final groupAmount = entry.value;
          
          if (itemsBudgetInfo[key] != null) {
            final groupBudgetInfo = itemsBudgetInfo[key] as Map<String, dynamic>;
            final outletBudget = _parseDouble(groupBudgetInfo['outlet_budget']) ?? 
                               _parseDouble(groupBudgetInfo['category_budget']) ?? 0.0;
            final outletUsedAmount = _parseDouble(groupBudgetInfo['outlet_used_amount']) ?? 
                                   _parseDouble(groupBudgetInfo['category_used_amount']) ?? 0.0;
            final realRemainingBudget = _parseDouble(groupBudgetInfo['real_remaining_budget']) ?? 
                                       _parseDouble(groupBudgetInfo['remaining_after_current']) ??
                                       (outletBudget - outletUsedAmount);
            
            // Calculate total after approving this PR group
            final totalAfterApproval = outletUsedAmount + groupAmount;
            
            // Check if approving will exceed budget
            if (totalAfterApproval > outletBudget || realRemainingBudget < groupAmount) {
              final exceededAmount = totalAfterApproval > outletBudget 
                  ? totalAfterApproval - outletBudget 
                  : groupAmount - realRemainingBudget;
              
              _showBudgetExceededDialog(
                totalBudget: outletBudget,
                usedAmount: outletUsedAmount,
                prAmount: groupAmount,
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
    
    // For other modes (non-pr_ops), use main budget_info
    final prAmount = _parseDouble(_approvalData!['amount']) ?? 0.0;
    
    // Use the correct budget and used amount based on budget_type
    final totalBudget = _getTotalBudget(budgetInfo);
    final usedAmount = _getUsedAmount(budgetInfo);
    final remainingAmount = _getRemainingAmount(budgetInfo);
    final realRemainingBudget = _parseDouble(budgetInfo['real_remaining_budget']) ?? 
                               _parseDouble(budgetInfo['remaining_after_current']) ??
                               remainingAmount;
    
    // Calculate total after approving this PR
    final totalAfterApproval = usedAmount + prAmount;
    
    // Check if approving will exceed budget
    if (totalAfterApproval > totalBudget) {
      final exceededAmount = totalAfterApproval - totalBudget;
      
      _showBudgetExceededDialog(
        totalBudget: totalBudget,
        usedAmount: usedAmount,
        prAmount: prAmount,
        totalAfterApproval: totalAfterApproval,
        exceededAmount: exceededAmount,
        remainingAmount: realRemainingBudget,
        budgetType: budgetType,
      );
      return false;
    }
    
    // Additional check: if real remaining budget is less than PR amount
    if (realRemainingBudget < prAmount) {
      final exceededAmount = prAmount - realRemainingBudget;
      
      _showBudgetExceededDialog(
        totalBudget: totalBudget,
        usedAmount: usedAmount,
        prAmount: prAmount,
        totalAfterApproval: totalAfterApproval,
        exceededAmount: exceededAmount,
        remainingAmount: realRemainingBudget,
        budgetType: budgetType,
      );
      return false;
    }
    
    return true;
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

  void _showBudgetExceededDialog({
    required double totalBudget,
    required double usedAmount,
    required double prAmount,
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
                      'Tidak dapat menyetujui PR karena budget akan melebihi limit!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBudgetInfoRow(
                      budgetType == 'PER_OUTLET' ? 'Outlet Budget Limit' : 'Category Budget Limit', 
                      totalBudget, 
                      Colors.blue
                    ),
                    _buildBudgetInfoRow(
                      budgetType == 'PER_OUTLET' ? 'Outlet Budget Terpakai' : 'Category Budget Terpakai', 
                      usedAmount, 
                      Colors.orange
                    ),
                    _buildBudgetInfoRow('Jumlah PR', prAmount, Colors.purple),
                    _buildBudgetInfoRow('Total Setelah Approve', totalAfterApproval, Colors.red),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Melebihi: ${_formatCurrency(exceededAmount)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
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
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Tutup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
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

  Future<void> _handleApprove() async {
    if (_isProcessing) return;

    // Validate budget before approving
    if (!_validateBudget()) {
      return; // Stop if budget validation fails
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konfirmasi Persetujuan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menyetujui PR ini?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _approvalService.approvePr(
        widget.prId,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PR berhasil disetujui'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menyetujui PR'),
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
      final result = await _approvalService.rejectPr(
        widget.prId,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        reason: _rejectReasonController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PR berhasil ditolak'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menolak PR'),
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

  void _showRejectDialogMethod() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Tolak PR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alasan Penolakan:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rejectReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Masukkan alasan penolakan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Komentar (Opsional):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Masukkan komentar',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
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
            onPressed: () {
              Navigator.of(context).pop();
              _handleReject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PR Approval Detail'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: const Center(
              child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PR Approval Detail'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: const Center(
          child: Text('Data tidak ditemukan'),
        ),
      );
    }

    final pr = _approvalData!;
    // Budget info is at the same level as purchase_requisition in the API response
    final budgetInfo = _approvalData!['budget_info'];
    final approvalFlows = _approvalData!['approval_flows'] as List<dynamic>? ?? [];
    final items = _approvalData!['items'] as List<dynamic>? ?? [];
    
    // Debug: Print budget info
    print('Budget Info in build: $budgetInfo');
    if (budgetInfo != null && budgetInfo is Map) {
      print('Budget Info breakdown: ${budgetInfo['breakdown']}');
    }

    // Get status color
    final status = pr['status']?.toString().toLowerCase() ?? '';
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusBgColor = const Color(0xFF10B981).withOpacity(0.1);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusBgColor = const Color(0xFFEF4444).withOpacity(0.1);
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusBgColor = const Color(0xFFF59E0B).withOpacity(0.1);
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.withOpacity(0.1);
        statusIcon = Icons.info;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          pr['pr_number'] ?? 'PR Approval Detail',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981),
                const Color(0xFF059669),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _animationController,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusBgColor,
                              statusBgColor.withOpacity(0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(statusIcon, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Basic Info Card
                      _buildSection(
                        'Informasi Dasar',
                        _buildInfoRows(pr),
                        icon: Icons.info_outline,
                      ),

                      // Budget Info
                      if (budgetInfo != null) ...[
                        _buildBudgetInfoSection(budgetInfo),
                      ],

                      // Approval Flow
                      if (approvalFlows.isNotEmpty) ...[
                        _buildApprovalFlowSection(approvalFlows),
                      ],

                      // Items
                      if (items.isNotEmpty) ...[
                        _buildItemsSection(items),
                      ],

                      // Attachments
                      Builder(
                        builder: (context) {
                          List<dynamic>? attachments;
                          
                          if (pr['attachments'] != null && pr['attachments'] is List) {
                            attachments = pr['attachments'] as List<dynamic>;
                            print('PR attachments found: ${attachments.length}');
                          } else {
                            print('PR attachments: ${pr['attachments']}');
                            print('PR attachments type: ${pr['attachments']?.runtimeType}');
                          }
                          
                          if (attachments != null && attachments.isNotEmpty) {
                            return _buildAttachmentsSection(attachments);
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // Comment Section
                      const SizedBox(height: 20),
                      _buildCommentSection(),

                      // Action Buttons
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.1),
                  const Color(0xFF059669).withOpacity(0.05),
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
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  String _parseMode(String? mode) {
    if (mode == null) return '-';
    switch (mode.toLowerCase()) {
      case 'pr_ops':
        return 'Purchase Requisition';
      case 'purchase_payment':
        return 'Payment Application';
      case 'kasbon':
        return 'Kasbon';
      case 'travel_application':
        return 'Travel & Akomodasi';
      default:
        return mode;
    }
  }

  String _formatCategoryBudget(Map<String, dynamic>? category) {
    if (category == null) return '-';
    final division = category['division'];
    final name = category['name'] ?? '-';
    if (division != null && division.toString().isNotEmpty) {
      // Format: division-name (e.g., "MARKETING - Regular Marketing Expenses")
      final divisionName = division is Map 
          ? (division['nama_divisi'] ?? division['name'] ?? division.toString())
          : division.toString();
      return '$divisionName - $name';
    }
    return name;
  }

  List<Widget> _buildInfoRows(Map<String, dynamic> pr) {
    return [
      _buildInfoRow('PR Number', pr['pr_number'] ?? '-', Icons.tag),
      _buildInfoRow('Title', pr['title'] ?? '-', Icons.title),
      _buildInfoRow('Mode', _parseMode(pr['mode']), Icons.category),
      _buildInfoRow('Status', pr['status'] ?? '-', Icons.info_outline),
      _buildInfoRow(
        'Amount',
        _formatCurrency(_parseDouble(pr['amount'])),
        Icons.attach_money,
        valueColor: const Color(0xFF10B981),
      ),
      if (pr['category'] != null)
        _buildInfoRow('Category', _formatCategoryBudget(pr['category']), Icons.label),
      if (pr['division'] != null)
        _buildInfoRow('Divisi', pr['division']['nama_divisi'] ?? '-', Icons.business),
      if (pr['outlet'] != null)
        _buildInfoRow('Outlet', pr['outlet']['nama_outlet'] ?? '-', Icons.store),
      if (pr['description'] != null && pr['description'].toString().isNotEmpty)
        _buildInfoRow('Description', pr['description'].toString(), Icons.description, allowWrap: true),
      if (pr['notes'] != null && pr['notes'].toString().isNotEmpty)
        _buildInfoRow('Notes', pr['notes'].toString(), Icons.note, allowWrap: true),
      if (pr['creator'] != null)
        _buildInfoRow('Created By', pr['creator']['nama_lengkap'] ?? '-', Icons.person),
    ];
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor, bool allowWrap = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF10B981),
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
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: valueColor ?? const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: allowWrap ? null : 1,
                  overflow: allowWrap ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    
    // Get current PR amount
    final prAmount = _parseDouble(_approvalData!['amount']) ?? 0.0;
    
    // Calculate remaining after approving this PR
    final remainingAfterApprove = realRemainingBudget - prAmount;
    
    // Build budget cards list
    final List<Widget> budgetCards = [
      // Total Budget Card
      Container(
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Total Budget',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
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
            if (budgetType == 'PER_OUTLET' && outletBudget > 0 && categoryBudget > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Global: ${_formatCurrency(categoryBudget)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Remaining Budget Card
      Container(
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
          mainAxisSize: MainAxisSize.min,
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
                  child: Text(
                    'Remaining Budget',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: realRemainingBudget >= 0 
                          ? Colors.green.shade900 
                          : Colors.red.shade900,
                    ),
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
            if (prAmount > 0) ...[
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
                        'Setelah approve PR ini: ${_formatCurrency(remainingAfterApprove)}',
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
    ];
    
    // Add Breakdown Budget if available
    if (budgetInfo['approved_amount'] != null || budgetInfo['unapproved_amount'] != null || budgetInfo['po_created_amount'] != null) {
      budgetCards.add(const SizedBox(height: 20));
      budgetCards.add(
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
            mainAxisSize: MainAxisSize.min,
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
                  if (budgetInfo['approved_amount'] != null)
                    _buildBreakdownSummaryCard(
                      'Sudah Di-Approved',
                      _parseDouble(budgetInfo['approved_amount']) ?? 0.0,
                      Colors.green,
                      Icons.check_circle,
                    ),
                  if (budgetInfo['unapproved_amount'] != null)
                    _buildBreakdownSummaryCard(
                      'Belum Di-Approved',
                      _parseDouble(budgetInfo['unapproved_amount']) ?? 0.0,
                      Colors.orange,
                      Icons.access_time,
                    ),
                  if (budgetInfo['po_created_amount'] != null)
                    _buildBreakdownSummaryCard(
                      'Sudah Dibuat PO',
                      _parseDouble(budgetInfo['po_created_amount']) ?? 0.0,
                      Colors.blue,
                      Icons.shopping_cart,
                    ),
                  if (budgetInfo['paid_amount'] != null)
                    _buildBreakdownSummaryCard(
                      'Sudah Di-Bayar',
                      _parseDouble(budgetInfo['paid_amount']) ?? 0.0,
                      Colors.green,
                      Icons.check_circle_outline,
                    ),
                  if (budgetInfo['unpaid_amount'] != null)
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
      );
    }
    
    // Add Budget Breakdown Detail if available
    if (budgetInfo['breakdown'] != null) {
      budgetCards.add(const SizedBox(height: 20));
      budgetCards.add(
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
            mainAxisSize: MainAxisSize.min,
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
              ..._buildBudgetBreakdown(budgetInfo['breakdown']),
            ],
          ),
        ),
      );
    }
    
    // Return section with budget cards
    return _buildSection(
      'Budget Info',
      budgetCards,
      icon: Icons.account_balance_wallet,
    );
  }

  Widget _buildBreakdownSummaryCard(String label, double amount, MaterialColor color, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _darkenColor(color, 0.2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkenColor(color, 0.3),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
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
    );
  }

  Widget _buildApprovalFlowSection(List<dynamic> flows) {
    return _buildSection(
      'Approval Flow',
      flows.asMap().entries.map((entry) {
        final index = entry.key;
        final flow = entry.value;
        final flowStatus = flow['status']?.toString().toLowerCase() ?? 'pending';
        
        Color flowColor;
        Color flowBgColor;
        IconData flowIcon;
        
        switch (flowStatus) {
          case 'approved':
            flowColor = const Color(0xFF10B981);
            flowBgColor = const Color(0xFF10B981).withOpacity(0.1);
            flowIcon = Icons.check_circle;
            break;
          case 'rejected':
            flowColor = const Color(0xFFEF4444);
            flowBgColor = const Color(0xFFEF4444).withOpacity(0.1);
            flowIcon = Icons.cancel;
            break;
          default:
            flowColor = Colors.grey;
            flowBgColor = Colors.grey.withOpacity(0.1);
            flowIcon = Icons.pending;
        }
        
        return Container(
          margin: EdgeInsets.only(bottom: index < flows.length - 1 ? 12 : 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                flowBgColor,
                flowBgColor.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: flowColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: flowColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: flowColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(flowIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flow['approver']?['nama_lengkap'] ?? '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: flowColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        flowStatus.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (flow['approved_at'] != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateTime(flow['approved_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (flow['comment'] != null && flow['comment'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.comment, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                flow['comment']?.toString() ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontStyle: FontStyle.italic,
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
            ],
          ),
        );
      }).toList(),
      icon: Icons.account_tree,
    );
  }

  Widget _buildApprovalFlowItem(Map<String, dynamic> flow, bool isLast) {
    final status = (flow['status'] ?? 'pending').toString().toLowerCase();
    final approverName = flow['approver']?['nama_lengkap'] ?? 'N/A';
    final approvedAt = flow['approved_at'];
    final comment = flow['comment'];

    Color statusColor;
    IconData statusIcon;
    String statusText;
    Color backgroundColor;
    Color borderColor;

    if (status == 'approved') {
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
      statusText = 'Approved';
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (status == 'rejected') {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.cancel;
      statusText = 'Rejected';
      backgroundColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
    } else {
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.pending;
      statusText = 'Pending';
      backgroundColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
    }

    // Format sesuai dengan web: "Kam, 4 Des 2025" dan "12.15"
    final dateFormat = DateFormat('EEE, d MMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH.mm', 'id_ID');

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
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
                      Expanded(
                        child: Text(
                          approverName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (approvedAt != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(DateTime.parse(approvedAt)),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeFormat.format(DateTime.parse(approvedAt)),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (comment != null && comment.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.comment, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comment.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                height: 1.4,
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
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<dynamic> items) {
    final mode = _approvalData?['mode']?.toString().toLowerCase();
    // For payment_application, purchase_payment, and purchase_requisition modes, show grouped items
    bool isPaymentOrPurchase = mode == 'purchase_payment' || 
                               mode == 'payment_application' || 
                               mode == 'purchase_requisition';
    
    // Check if items have outlet_id (for legacy/null mode or purchase_requisition)
    if (!isPaymentOrPurchase && items.isNotEmpty) {
      try {
        final firstItem = items[0];
        if (firstItem is Map && firstItem['outlet_id'] != null) {
          isPaymentOrPurchase = true;
        }
      } catch (e) {
        // Ignore error, use default behavior
        print('Error checking item structure: $e');
      }
    }
    
    // Group items by outlet and category for payment/purchase modes
    if (isPaymentOrPurchase) {
      return _buildGroupedItemsSection(items);
    }
    
    // Regular items display for other modes
    return _buildSection(
      'Detail Items',
      items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: EdgeInsets.only(bottom: index < items.length - 1 ? 12 : 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFF10B981).withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildItemDetail('Quantity', item['qty']?.toString() ?? '-', Icons.inventory_2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildItemDetail('Unit', item['unit']?.toString() ?? '-', Icons.square_foot),
                  ),
                ],
              ),
              // Travel Application specific fields
              if (mode == 'travel_application') ...[
                const SizedBox(height: 12),
                if (item['allowance_recipient_name'] != null && item['allowance_recipient_name'].toString().isNotEmpty)
                  _buildItemDetail('Allowance Recipient', item['allowance_recipient_name'].toString(), Icons.person_outline),
                if (item['allowance_account_number'] != null && item['allowance_account_number'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildItemDetail('Account Number', item['allowance_account_number'].toString(), Icons.account_circle),
                ],
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      _formatCurrency(_parseDouble(item['subtotal'])),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      icon: Icons.shopping_cart,
    );
  }

  Widget _buildGroupedItemsSection(List<dynamic> items) {
    final mode = _approvalData?['mode']?.toString().toLowerCase();
    // Group items by outlet and category to show header
    final Map<String, Map<String, dynamic>> groupedItems = {};
    
    for (var item in items) {
      if (item is! Map<String, dynamic>) continue;
      
      final outletId = item['outlet_id']?.toString() ?? 'no_outlet';
      final outletObj = item['outlet'];
      final outletName = (outletObj is Map && outletObj['nama_outlet'] != null) 
          ? outletObj['nama_outlet'].toString()
          : (item['outlet_name']?.toString() ?? 'Unknown Outlet');
      
      final categoryId = item['category_id']?.toString() ?? 'no_category';
      final categoryObj = item['category'];
      final categoryName = (categoryObj is Map && categoryObj['name'] != null)
          ? categoryObj['name'].toString()
          : (item['category_name']?.toString() ?? 'Unknown Category');
      
      String divisionName = '';
      if (categoryObj is Map && categoryObj['division'] is Map) {
        divisionName = categoryObj['division']?['nama_divisi']?.toString() ?? '';
      }
      if (divisionName.isEmpty && item['division'] is Map) {
        divisionName = item['division']?['nama_divisi']?.toString() ?? '';
      }
      if (divisionName.isEmpty && categoryObj is Map) {
        divisionName = categoryObj['division_name']?.toString() ?? '';
      }
      
      final groupKey = '$outletId|$categoryId';
      
      if (!groupedItems.containsKey(groupKey)) {
        groupedItems[groupKey] = {
          'outlet_name': outletName,
          'category_name': categoryName,
          'division_name': divisionName,
          'items': <dynamic>[],
        };
      }
      final itemsList = groupedItems[groupKey]!['items'];
      if (itemsList is List) {
        itemsList.add(item);
      }
    }
    
    final List<Widget> widgets = [];
    int globalItemIndex = 0;
    bool isFirstGroup = true;
    
    groupedItems.forEach((key, groupData) {
      final outletName = groupData['outlet_name']?.toString() ?? 'Unknown Outlet';
      final categoryName = groupData['category_name']?.toString() ?? 'Unknown Category';
      final divisionName = groupData['division_name']?.toString() ?? '';
      final itemsData = groupData['items'];
      final groupItems = itemsData is List ? itemsData : <dynamic>[];
      
      // Outlet and Category Header (show once per group, before first item of group)
      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 12, top: isFirstGroup ? 0 : 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.store, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Outlet: $outletName',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Category: ${divisionName.isNotEmpty ? '$divisionName - ' : ''}$categoryName',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      
      // Items in this group (same card design as before)
      for (int i = 0; i < groupItems.length; i++) {
        final item = groupItems[i];
        final isLastItem = (globalItemIndex == items.length - 1);
        
        widgets.add(
          Container(
            margin: EdgeInsets.only(bottom: isLastItem ? 0 : 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  const Color(0xFF10B981).withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${globalItemIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildItemDetail('Quantity', item['qty']?.toString() ?? '-', Icons.inventory_2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildItemDetail('Unit', item['unit']?.toString() ?? '-', Icons.square_foot),
                    ),
                  ],
                ),
                // Travel Application specific fields
                if (mode == 'travel_application') ...[
                  const SizedBox(height: 12),
                  if (item['allowance_recipient_name'] != null && item['allowance_recipient_name'].toString().isNotEmpty)
                    _buildItemDetail('Allowance Recipient', item['allowance_recipient_name'].toString(), Icons.person_outline),
                  if (item['allowance_account_number'] != null && item['allowance_account_number'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildItemDetail('Account Number', item['allowance_account_number'].toString(), Icons.account_circle),
                  ],
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        _formatCurrency(_parseDouble(item['subtotal'])),
                        style: const TextStyle(
                          fontSize: 16,
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
        );
        globalItemIndex++;
      }
      
      isFirstGroup = false;
    });
    
    return _buildSection(
      'Detail Items',
      widgets,
      icon: Icons.shopping_cart,
    );
  }

  Widget _buildItemDetail(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCommentSection() {
    final comments = _approvalData?['comments'] as List<dynamic>? ?? [];
    
    return _buildSection(
      'Comments',
      [
        // Add Comment Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _newCommentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              // Internal Comment Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _isInternalComment,
                    onChanged: (value) {
                      setState(() {
                        _isInternalComment = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF10B981),
                  ),
                  const Text(
                    'Internal comment',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Add Comment Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isAddingComment ? null : _addComment,
                  icon: _isAddingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: const Text('Add Comment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Comments List
        if (comments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No comments yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          )
        else
          ...comments.reversed.map((comment) => _buildCommentItem(comment)).toList(),
      ],
      icon: Icons.comment,
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final userName = comment['user']?['nama_lengkap'] ?? 'Unknown';
    final commentText = comment['comment'] ?? '';
    final createdAt = comment['created_at'];
    final isInternal = comment['is_internal'] == true;
    
    DateTime? dateTime;
    if (createdAt != null) {
      try {
        dateTime = DateTime.parse(createdAt);
      } catch (e) {
        // Ignore parse error
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInternal ? Colors.purple.shade200 : Colors.grey.shade200,
          width: isInternal ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (dateTime != null)
                      Text(
                        DateFormat('d MMM yyyy HH.mm', 'id_ID').format(dateTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (isInternal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Internal',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            commentText,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    if (_newCommentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    setState(() {
      _isAddingComment = true;
    });

    try {
      final result = await _approvalService.addPrComment(
        widget.prId,
        _newCommentController.text.trim(),
        isInternal: _isInternalComment,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _newCommentController.clear();
        setState(() {
          _isInternalComment = false;
        });
        
        // Reload approval details to get updated comments
        await _loadApprovalDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to add comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingComment = false;
        });
      }
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _showRejectDialogMethod,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tolak',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Setujui',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(List<dynamic> attachments) {
    return _buildSection(
      'Attachments',
      [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: attachments.map((attachment) => _buildAttachmentItem(attachment)).toList(),
        ),
      ],
      icon: Icons.attach_file,
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment) {
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
      viewUrl = '$baseUrl/api/approval-app/purchase-requisitions/attachments/$attachmentId/view';
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
            child: Container(
              width: 96, // w-24 = 96px (same as web)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.5),
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
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              httpHeaders: headers,
                              placeholder: (context, url) => Container(
                                width: 96,
                                height: 96,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                print('Image load error: $error');
                                return Container(
                                  width: 96,
                                  height: 96,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            )
                          : Container(
                              width: 96,
                              height: 96,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
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
          constraints: const BoxConstraints(minWidth: 120),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(fileName),
                size: 32,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 120,
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
