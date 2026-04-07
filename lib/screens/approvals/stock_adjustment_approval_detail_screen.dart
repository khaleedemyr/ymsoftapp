import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class StockAdjustmentApprovalDetailScreen extends StatefulWidget {
  final int adjustmentId;

  const StockAdjustmentApprovalDetailScreen({
    super.key,
    required this.adjustmentId,
  });

  @override
  State<StockAdjustmentApprovalDetailScreen> createState() => _StockAdjustmentApprovalDetailScreenState();
}

class _StockAdjustmentApprovalDetailScreenState extends State<StockAdjustmentApprovalDetailScreen> {
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

      final url = '${ApprovalService.baseUrl}/api/approval-app/outlet-food-inventory-adjustment/${widget.adjustmentId}/approval-details';
      print('Stock Adjustment Detail: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Stock Adjustment Detail: Status code = ${response.statusCode}');
      print('Stock Adjustment Detail: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Stock Adjustment Detail: Parsed data = $data');
        if (data['success'] == true && data['adjustment'] != null) {
          // Debug: Print items structure
          if (data['items'] != null && (data['items'] as List).isNotEmpty) {
            print('Stock Adjustment Detail: Items count = ${(data['items'] as List).length}');
            print('Stock Adjustment Detail: First item keys = ${(data['items'] as List)[0].keys.toList()}');
            print('Stock Adjustment Detail: First item = ${(data['items'] as List)[0]}');
          }
          setState(() {
            _approvalData = data; // Store full response data
            _isLoading = false;
          });
          print('Stock Adjustment Detail: Data loaded successfully');
          return;
        } else {
          print('Stock Adjustment Detail: success=false or adjustment is null');
          print('Stock Adjustment Detail: data = $data');
        }
      } else {
        print('Stock Adjustment Detail: Non-200 status code: ${response.statusCode}');
        print('Stock Adjustment Detail: Response body = ${response.body}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading Stock Adjustment details: $e');
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
        title: const Text('Setujui Stock Adjustment?'),
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
      final approvalFlowId = _approvalData?['current_approval_flow_id'];
      final result = await _approvalService.approveStockAdjustment(
        widget.adjustmentId,
        comment: null,
        approvalFlowId: approvalFlowId != null ? int.tryParse(approvalFlowId.toString()) : null,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Adjustment berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Gagal menyetujui Stock Adjustment')),
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
        });
      }
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Stock Adjustment?'),
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
      final approvalFlowId = _approvalData?['current_approval_flow_id'] ?? _approvalData?['adjustment']?['current_approval_flow_id'];
      final result = await _approvalService.rejectStockAdjustment(
        widget.adjustmentId,
        reason: _rejectReasonController.text.trim(),
        approvalFlowId: approvalFlowId != null ? int.tryParse(approvalFlowId.toString()) : null,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Adjustment berhasil ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Gagal menolak Stock Adjustment')),
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
      return '-';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return date;
    }
  }

  String _formatQuantity(dynamic qty) {
    if (qty == null || qty == '-') return '-';
    try {
      if (qty is num) {
        // If it's a whole number, show without decimals
        if (qty % 1 == 0) {
          return qty.toInt().toString();
        }
        // Otherwise show with 2 decimal places
        return qty.toStringAsFixed(2);
      }
      if (qty is String) {
        // Try to parse as number
        final numValue = double.tryParse(qty);
        if (numValue != null) {
          if (numValue % 1 == 0) {
            return numValue.toInt().toString();
          }
          return numValue.toStringAsFixed(2);
        }
        return qty;
      }
      return qty.toString();
    } catch (e) {
      return qty.toString();
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF14B8A6).withOpacity(0.1),
                  const Color(0xFF2DD4BF).withOpacity(0.05),
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
                        colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withOpacity(0.3),
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
                color: const Color(0xFF14B8A6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF14B8A6),
              ),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
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
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          title: const Text('Stock Adjustment Approval Detail'),
        ),
        body: const Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stock Adjustment Approval Detail'),
        ),
        body: const Center(
          child: Text('Data tidak ditemukan'),
        ),
      );
    }

    final adjustment = _approvalData!['adjustment'] ?? _approvalData!;
    final items = _approvalData!['items'] as List<dynamic>? ?? [];
    final approvalFlows = _approvalData!['approval_flows'] as List<dynamic>? ?? [];

    // Get status color
    final status = adjustment['status']?.toString().toLowerCase() ?? '';
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
      case 'waiting_approval':
      case 'waiting_cost_control':
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
          'Stock Adjustment #${adjustment['number'] ?? adjustment['id'] ?? ''}',
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
                const Color(0xFF14B8A6),
                const Color(0xFF2DD4BF),
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
                          status.toUpperCase().replaceAll('_', ' '),
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

            // Informasi Dasar
            _buildSection(
              'Informasi Dasar',
              [
                _buildInfoRow('Number', adjustment['number'] ?? adjustment['id']?.toString() ?? '-', icon: Icons.tag),
                _buildInfoRow('Type', adjustment['type'] ?? adjustment['adjustment_type'] ?? '-', icon: Icons.category),
                if (adjustment['nama_outlet'] != null)
                  _buildInfoRow('Outlet', adjustment['nama_outlet'] ?? '-', icon: Icons.store),
                if (adjustment['warehouse_outlet_name'] != null)
                  _buildInfoRow('Warehouse Outlet', adjustment['warehouse_outlet_name'] ?? '-', icon: Icons.warehouse),
                if (adjustment['notes'] != null && adjustment['notes'].toString().isNotEmpty)
                  _buildInfoRow('Notes', adjustment['notes'] ?? '-', icon: Icons.note),
                if (adjustment['creator_name'] != null)
                  _buildInfoRow('Created By', adjustment['creator_name'] ?? '-', icon: Icons.person_outline),
                if (adjustment['created_at'] != null)
                  _buildInfoRow('Created At', _formatDateTime(adjustment['created_at']), icon: Icons.access_time),
              ],
              icon: Icons.info_outline,
            ),

            // Detail Items
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
                          const Color(0xFF14B8A6).withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withOpacity(0.1),
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
                                  colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
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
                        // Qty Before - check multiple possible field names
                        _buildItemDetail(
                          'Qty Before', 
                          _formatQuantity(
                            item['quantity_before'] ?? 
                            item['qty_before'] ?? 
                            item['qty_before_adjustment'] ?? 
                            item['before_qty'] ?? 
                            item['qty_before_system'] ??
                            item['system_qty'] ??
                            '-'
                          ), 
                          Icons.inventory_2,
                        ),
                        const SizedBox(height: 8),
                        // Qty After - check multiple possible field names
                        _buildItemDetail(
                          'Qty After', 
                          _formatQuantity(
                            item['quantity_after'] ?? 
                            item['qty_after'] ?? 
                            item['qty_after_adjustment'] ?? 
                            item['after_qty'] ?? 
                            item['qty'] ??  // Fallback to qty if before/after not available
                            '-'
                          ), 
                          Icons.inventory,
                        ),
                        const SizedBox(height: 8),
                        // Difference - calculate if not available
                        _buildItemDetail(
                          'Difference', 
                          () {
                            // Try to get difference directly
                            final diff = item['difference'] ?? item['qty_difference'] ?? item['diff'];
                            if (diff != null) {
                              return _formatQuantity(diff);
                            }
                            
                            // Calculate difference if before and after are available
                            final before = item['quantity_before'] ?? 
                                         item['qty_before'] ?? 
                                         item['qty_before_adjustment'] ?? 
                                         item['before_qty'] ??
                                         item['qty_before_system'] ??
                                         item['system_qty'];
                            final after = item['quantity_after'] ?? 
                                        item['qty_after'] ?? 
                                        item['qty_after_adjustment'] ?? 
                                        item['after_qty'] ?? 
                                        item['qty'];
                            
                            if (before != null && after != null) {
                              try {
                                final beforeNum = before is num ? before : double.tryParse(before.toString());
                                final afterNum = after is num ? after : double.tryParse(after.toString());
                                if (beforeNum != null && afterNum != null) {
                                  return _formatQuantity(afterNum - beforeNum);
                                }
                              } catch (e) {
                                print('Error calculating difference: $e');
                              }
                            }
                            
                            return '-';
                          }(), 
                          Icons.trending_up, 
                          valueColor: () {
                            final diff = item['difference'] ?? item['qty_difference'] ?? item['diff'];
                            if (diff == null) {
                              // Try to calculate
                              final before = item['quantity_before'] ?? 
                                           item['qty_before'] ?? 
                                           item['qty_before_adjustment'] ?? 
                                           item['before_qty'] ??
                                           item['qty_before_system'] ??
                                           item['system_qty'];
                              final after = item['quantity_after'] ?? 
                                          item['qty_after'] ?? 
                                          item['qty_after_adjustment'] ?? 
                                          item['after_qty'] ?? 
                                          item['qty'];
                              if (before != null && after != null) {
                                try {
                                  final beforeNum = before is num ? before : double.tryParse(before.toString());
                                  final afterNum = after is num ? after : double.tryParse(after.toString());
                                  if (beforeNum != null && afterNum != null) {
                                    final calculatedDiff = afterNum - beforeNum;
                                    if (calculatedDiff > 0) return const Color(0xFF10B981);
                                    if (calculatedDiff < 0) return const Color(0xFFEF4444);
                                  }
                                } catch (e) {
                                  // Ignore
                                }
                              }
                              return null;
                            }
                            if (diff is num) {
                              if (diff > 0) return const Color(0xFF10B981);
                              if (diff < 0) return const Color(0xFFEF4444);
                            }
                            return null;
                          }(),
                        ),
                        if (item['unit_name'] != null || item['unit'] != null)
                          _buildItemDetail('Unit', item['unit_name'] ?? item['unit'] ?? '-', Icons.scale),
                      ],
                    ),
                  );
                }).toList(),
                icon: Icons.inventory_2,
              ),

            // Approval Flow
            if (approvalFlows.isNotEmpty)
              _buildSection(
                'Approval Flow',
                approvalFlows.map((flow) {
                  final flowStatus = flow['status']?.toString().toUpperCase() ?? 'PENDING';
                  Color flowStatusColor;
                  IconData flowStatusIcon;
                  
                  switch (flowStatus) {
                    case 'APPROVED':
                      flowStatusColor = const Color(0xFF10B981);
                      flowStatusIcon = Icons.check_circle;
                      break;
                    case 'REJECTED':
                      flowStatusColor = const Color(0xFFEF4444);
                      flowStatusIcon = Icons.cancel;
                      break;
                    default:
                      flowStatusColor = const Color(0xFFF59E0B);
                      flowStatusIcon = Icons.pending;
                  }
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: flowStatusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: flowStatusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(flowStatusIcon, size: 12, color: flowStatusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    flowStatus,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: flowStatusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (flow['approved_at'] != null)
                              Text(
                                _formatDateTime(flow['approved_at']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            if (flow['rejected_at'] != null)
                              Text(
                                _formatDateTime(flow['rejected_at']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (flow['nama_lengkap'] != null)
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                flow['nama_lengkap'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        if (flow['comments'] != null && flow['comments'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.comment, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  flow['comments'] ?? '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                icon: Icons.timeline,
              ),

            // Action Buttons - Only show if status is waiting_approval and user is current approver
            if ((status == 'waiting_approval' || status == 'waiting_cost_control') && 
                (_approvalData?['current_approval_flow_id'] != null || 
                 _approvalData?['adjustment']?['current_approval_flow_id'] != null)) ...[
              const SizedBox(height: 8),
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
                        elevation: 2,
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
                      elevation: 2,
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

  Widget _buildItemDetail(String label, String value, IconData icon, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
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
                    color: valueColor ?? Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
