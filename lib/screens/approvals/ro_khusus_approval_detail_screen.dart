import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class ROKhususApprovalDetailScreen extends StatefulWidget {
  final int roKhususId;

  const ROKhususApprovalDetailScreen({
    super.key,
    required this.roKhususId,
  });

  @override
  State<ROKhususApprovalDetailScreen> createState() => _ROKhususApprovalDetailScreenState();
}

class _ROKhususApprovalDetailScreenState extends State<ROKhususApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  Map<String, dynamic>? _approvalData;
  bool _isLoading = true;
  bool _isProcessing = false;
  final TextEditingController _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApprovalDetails();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovalDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _approvalService.getToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final url = '${ApprovalService.baseUrl}/api/approval-app/ro-khusus/${widget.roKhususId}';
      print('RO Khusus Detail: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('RO Khusus Detail: Status code = ${response.statusCode}');
      print('RO Khusus Detail: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('RO Khusus Detail: Parsed data = $data');
        if (data['success'] == true && data['ro_khusus'] != null) {
          setState(() {
            _approvalData = data['ro_khusus'];
            _isLoading = false;
          });
          print('RO Khusus Detail: Data loaded successfully');
          print('RO Khusus Items: ${_approvalData!['items']}');
          return;
        } else {
          print('RO Khusus Detail: success=false or ro_khusus is null');
          print('RO Khusus Detail: data = $data');
        }
      } else {
        print('RO Khusus Detail: Non-200 status code: ${response.statusCode}');
        print('RO Khusus Detail: Response body = ${response.body}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading RO Khusus details: $e');
      print('Error stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui RO Khusus?'),
        content: const Text('Tindakan ini akan meneruskan ke approver berikutnya.'),
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

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _approvalService.approveROKhusus(
        widget.roKhususId,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RO Khusus berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        // Show budget violation dialog if violations exist
        if (result['violations'] != null && result['violations'] is List) {
          _showBudgetViolationDialog(result['message'] ?? 'Budget limit terlampaui', result['violations']);
        } else {
          // Show regular error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? result['error'] ?? 'Gagal menyetujui RO Khusus'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showBudgetViolationDialog(String message, List<dynamic> violations) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Budget Limit Terlampaui',
                style: TextStyle(
                  fontSize: 18,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...violations.map((violation) {
                final budgetAmount = violation['budget_amount'] ?? 0;
                final retailFoodTotal = violation['retail_food_total'] ?? 0;
                final foodFloorOrderTotal = violation['food_floor_order_total'] ?? 0;
                final monthlyTotal = violation['monthly_total'] ?? 0;
                final newItemSubtotal = violation['new_item_subtotal'] ?? 0;
                final totalAfterNewItem = violation['total_after_new_item'] ?? 0;
                final excessAmount = violation['excess_amount'] ?? 0;
                final subCategoryName = violation['sub_category_name'] ?? 'N/A';
                final categoryName = violation['category_name'] ?? 'N/A';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category, color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subCategoryName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (categoryName != 'N/A') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kategori: $categoryName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildBudgetRow('Budget yang ditetapkan', budgetAmount),
                      _buildBudgetRow('Total Retail Food (bulan ini)', retailFoodTotal),
                      _buildBudgetRow('Total Food Floor Order (bulan ini)', foodFloorOrderTotal),
                      _buildBudgetRow('Total Gabungan', monthlyTotal),
                      _buildBudgetRow('Item baru', newItemSubtotal),
                      _buildBudgetRow('Total setelah item baru', totalAfterNewItem, isHighlight: true),
                      const Divider(height: 20),
                      _buildBudgetRow('Kelebihan', excessAmount, isExcess: true),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow(String label, dynamic amount, {bool isHighlight = false, bool isExcess = false}) {
    final amountValue = amount is num ? amount.toDouble() : (double.tryParse(amount.toString()) ?? 0.0);
    final formattedAmount = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0).format(amountValue);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: isHighlight || isExcess ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            formattedAmount,
            style: TextStyle(
              fontSize: 13,
              color: isExcess ? Colors.red.shade700 : (isHighlight ? Colors.orange.shade700 : Colors.grey.shade800),
              fontWeight: FontWeight.bold,
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
        title: const Text('Tolak RO Khusus?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Alasan penolakan:'),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectReasonController,
              decoration: const InputDecoration(
                hintText: 'Masukkan alasan penolakan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _rejectReasonController.clear();
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan penolakan wajib diisi')),
                );
                return;
              }
              Navigator.pop(context);
              _handleReject();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _approvalService.rejectROKhusus(
        widget.roKhususId,
        notes: _rejectReasonController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RO Khusus berhasil ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Gagal menolak RO Khusus')),
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
          _isProcessing = false;
          _rejectReasonController.clear();
        });
      }
    }
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepOrange.shade400.withOpacity(0.1),
                  Colors.deepOrange.shade600.withOpacity(0.05),
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
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepOrange.shade400,
                          Colors.deepOrange.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.shade400.withOpacity(0.3),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, IconData? icon}) {
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
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.deepOrange.shade400,
              ),
            ),
            const SizedBox(width: 12),
          ],
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
                ),
              ],
            ),
          ),
        ],
      ),
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
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
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
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rp 0';
    final formatter = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  String _formatQuantity(dynamic qty) {
    if (qty == null) return '-';
    if (qty is num) {
      return qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
    }
    if (qty is String) {
      try {
        final numValue = double.parse(qty);
        return numValue.toStringAsFixed(numValue % 1 == 0 ? 0 : 2);
      } catch (e) {
        return qty;
      }
    }
    return qty.toString();
  }

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

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime).toLocal();
      } else if (dateTime is DateTime) {
        dt = dateTime.toLocal();
      } else {
        return '-';
      }
      return DateFormat('EEE, d MMM yyyy HH.mm', 'id_ID').format(dt);
    } catch (e) {
      print('Error formatting date: $e');
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RO Khusus Approval Detail'),
        ),
        body: const Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RO Khusus Approval Detail'),
        ),
        body: const Center(
          child: Text('Data tidak ditemukan'),
        ),
      );
    }

    final roKhusus = _approvalData!;
    final items = roKhusus['items'] as List<dynamic>? ?? [];
    final approvalFlows = roKhusus['approval_flows'] as List<dynamic>? ?? [];

    // Get status color
    final status = roKhusus['status']?.toString().toLowerCase() ?? '';
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
      case 'submitted':
        statusColor = const Color(0xFFF59E0B);
        statusBgColor = const Color(0xFFF59E0B).withOpacity(0.1);
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.withOpacity(0.1);
        statusIcon = Icons.info;
    }

    // Get creator name
    String creatorName = '-';
    if (roKhusus['creator'] != null && roKhusus['creator']['nama_lengkap'] != null) {
      creatorName = roKhusus['creator']['nama_lengkap'];
    } else if (roKhusus['requester'] != null && roKhusus['requester']['nama_lengkap'] != null) {
      creatorName = roKhusus['requester']['nama_lengkap'];
    }

    // Get warehouse outlet name
    String warehouseName = '-';
    if (roKhusus['warehouse_outlet'] != null && roKhusus['warehouse_outlet']['name'] != null) {
      warehouseName = roKhusus['warehouse_outlet']['name'];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'RO Khusus ${roKhusus['order_number'] ?? roKhusus['number'] ?? ''}',
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
                Colors.deepOrange.shade400,
                Colors.deepOrange.shade600,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontSize: 16,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Basic Info
            _buildSection(
              'Informasi Dasar',
              [
                _buildInfoRow('Number', roKhusus['order_number'] ?? roKhusus['number'] ?? '-', icon: Icons.numbers),
                if (roKhusus['outlet'] != null)
                  _buildInfoRow('Outlet', roKhusus['outlet']['nama_outlet'] ?? '-', icon: Icons.store),
                if (warehouseName != '-')
                  _buildInfoRow('Warehouse Outlet', warehouseName, icon: Icons.warehouse),
                _buildInfoRow('Total Amount', _formatCurrency(_parseDouble(roKhusus['total_amount'])), icon: Icons.attach_money, valueColor: const Color(0xFF10B981)),
                _buildInfoRow('Status', roKhusus['status'] ?? '-', icon: Icons.info),
                if (roKhusus['date'] != null)
                  _buildInfoRow('Date', DateFormat('dd MMM yyyy').format(DateTime.parse(roKhusus['date'])), icon: Icons.calendar_today),
                if (creatorName != '-')
                  _buildInfoRow('Created By', creatorName, icon: Icons.person),
                if (roKhusus['created_at'] != null)
                  _buildInfoRow('Created At', _formatDateTime(roKhusus['created_at']), icon: Icons.access_time),
              ],
              icon: Icons.info_outline,
            ),

            // Items
            if (items.isNotEmpty)
              _buildSection(
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
                          Colors.deepOrange.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepOrange.withOpacity(0.1),
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
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepOrange.shade400,
                                    Colors.deepOrange.shade600,
                                  ],
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
                                item['item']?['name'] ?? 'Item',
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
                              flex: 2,
                              child: _buildItemDetail(
                                'Quantity',
                                _formatQuantity(item['qty'] ?? item['quantity']),
                                Icons.inventory_2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildItemDetail(
                                'Unit',
                                item['unit'] ?? '-',
                                Icons.straighten,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildItemDetail('Price', _formatCurrency(_parseDouble(item['price'])), Icons.price_check),
                            ),
                          ],
                        ),
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
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                _formatCurrency(_parseDouble(item['subtotal'] ?? (item['qty'] ?? item['quantity']) * (item['price'] ?? 0))),
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
              ),

            // Approval Flow
            if (approvalFlows.isNotEmpty)
              _buildSection(
                'Approval Flow',
                approvalFlows.map((flow) {
                  final isApproved = flow['approved'] == true;
                  final isRejected = flow['approved'] == false;
                  final isPending = flow['approved'] == null;
                  
                  Color statusColor;
                  IconData statusIcon;
                  String statusText;
                  
                  if (isApproved) {
                    statusColor = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle;
                    statusText = 'Approved';
                  } else if (isRejected) {
                    statusColor = const Color(0xFFEF4444);
                    statusIcon = Icons.cancel;
                    statusText = 'Rejected';
                  } else {
                    statusColor = Colors.grey;
                    statusIcon = Icons.pending;
                    statusText = 'Pending';
                  }
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.1),
                          statusColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(statusIcon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flow['role'] ?? flow['approver_role'] ?? 'Approver',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              if (flow['approver'] != null && flow['approver']['nama_lengkap'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  flow['approver']['nama_lengkap'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
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
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                icon: Icons.assignment_turned_in,
              ),

            // Action Buttons - Only show if status is submitted
            if (status == 'submitted') ...[
              const SizedBox(height: 24),
              Row(
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
                        elevation: 4,
                        shadowColor: Colors.red.withOpacity(0.3),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close, size: 20),
                                SizedBox(width: 8),
                                Text('Tolak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
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
                        elevation: 4,
                        shadowColor: Colors.green.withOpacity(0.3),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 20),
                                SizedBox(width: 8),
                                Text('Setujui', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
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
}
