import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class POFoodApprovalDetailScreen extends StatefulWidget {
  final int poFoodId;

  const POFoodApprovalDetailScreen({
    super.key,
    required this.poFoodId,
  });

  @override
  State<POFoodApprovalDetailScreen> createState() => _POFoodApprovalDetailScreenState();
}

class _POFoodApprovalDetailScreenState extends State<POFoodApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  Map<String, dynamic>? _approvalData;
  String? _currentApprovalLevel;
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

      final response = await http.get(
        Uri.parse('${ApprovalService.baseUrl}/api/approval-app/po-food/${widget.poFoodId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('PO Food Detail: Status code = ${response.statusCode}');
      print('PO Food Detail: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('PO Food Detail: Parsed data = $data');
        if (data['success'] == true && data['po_food'] != null) {
          final poFoodData = data['po_food'] as Map<String, dynamic>;
          
          // Fetch stock for each item
          if (poFoodData['items'] != null && poFoodData['warehouse_outlet_id'] != null) {
            final items = poFoodData['items'] as List<dynamic>;
            final warehouseId = poFoodData['warehouse_outlet_id'];
            
            print('Fetching stock for ${items.length} items with warehouse_id: $warehouseId');
            
            // Fetch stock for all items
            final itemsWithStock = await Future.wait(
              items.map((item) async {
                if (item['item_id'] == null) return item;
                
                try {
                  final stockResponse = await http.get(
                    Uri.parse('${ApprovalService.baseUrl}/api/approval-app/inventory/stock?item_id=${item['item_id']}&warehouse_id=$warehouseId'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Accept': 'application/json',
                    },
                  );
                  
                  if (stockResponse.statusCode == 200) {
                    final stockData = jsonDecode(stockResponse.body);
                    item['stock'] = stockData;
                    print('Stock for item ${item['item_id']}: $stockData');
                  } else {
                    print('Failed to fetch stock for item ${item['item_id']}: ${stockResponse.statusCode} - ${stockResponse.body}');
                  }
                } catch (e) {
                  print('Error fetching stock for item ${item['item_id']}: $e');
                }
                
                return item;
              }),
            );
            
            poFoodData['items'] = itemsWithStock;
          }
          
          setState(() {
            _approvalData = poFoodData;
            _currentApprovalLevel = data['current_approval_level'];
            _isLoading = false;
          });
          print('PO Food Detail: Data loaded successfully');
          print('PO Food Status: ${poFoodData['status']}');
          print('PO Food Current Approval Level: $_currentApprovalLevel');
          print('PO Food Current Approver ID: ${data['current_approver_id']}');
          return;
        } else {
          print('PO Food Detail: success=false or po_food is null');
        }
      } else {
        print('PO Food Detail: Non-200 status code: ${response.statusCode}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading PO Food details: $e');
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
        title: const Text('Setujui PO Food?'),
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
      final result = await _approvalService.approvePoFood(
        widget.poFoodId,
        comment: null,
        approvalLevel: _currentApprovalLevel,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PO Food berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? result['error'] ?? 'Gagal menyetujui PO Food'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
          _isProcessing = false;
        });
      }
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak PO Food?'),
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
      final result = await _approvalService.rejectPoFood(
        widget.poFoodId,
        note: _rejectReasonController.text.trim(),
        approvalLevel: _currentApprovalLevel,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PO Food berhasil ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? result['error'] ?? 'Gagal menolak PO Food'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
                  Colors.brown.shade100.withOpacity(0.5),
                  Colors.brown.shade50.withOpacity(0.3),
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
                        colors: [Colors.brown.shade600, Colors.brown.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.withOpacity(0.3),
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
                color: Colors.brown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.brown.shade700,
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

  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rp 0';
    final formatter = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
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

  String _formatStockDisplay(Map<String, dynamic>? stock) {
    if (stock == null) return 'Stok: 0';
    
    final parts = <String>[];
    
    if (stock['qty_small'] != null && _parseDouble(stock['qty_small']) != null && _parseDouble(stock['qty_small'])! > 0) {
      final qty = _parseDouble(stock['qty_small'])!;
      final unit = stock['unit_small']?.toString() ?? '';
      parts.add('${qty.toStringAsFixed(2)} $unit');
    }
    
    if (stock['qty_medium'] != null && _parseDouble(stock['qty_medium']) != null && _parseDouble(stock['qty_medium'])! > 0) {
      final qty = _parseDouble(stock['qty_medium'])!;
      final unit = stock['unit_medium']?.toString() ?? '';
      parts.add('${qty.toStringAsFixed(2)} $unit');
    }
    
    if (stock['qty_large'] != null && _parseDouble(stock['qty_large']) != null && _parseDouble(stock['qty_large'])! > 0) {
      final qty = _parseDouble(stock['qty_large'])!;
      final unit = stock['unit_large']?.toString() ?? '';
      parts.add('${qty.toStringAsFixed(2)} $unit');
    }
    
    return parts.isNotEmpty ? 'Stok: ${parts.join(' | ')}' : 'Stok: 0';
  }

  String _formatQuantity(dynamic qty) {
    if (qty == null) return '-';
    if (qty is num) {
      if (qty % 1 == 0) {
        return qty.toInt().toString();
      } else {
        return qty.toStringAsFixed(2);
      }
    }
    return qty.toString();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PO Food Approval Detail'),
        ),
        body: const Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PO Food Approval Detail'),
        ),
        body: const Center(
          child: Text('Data tidak ditemukan'),
        ),
      );
    }

    final poFood = _approvalData!;
    final items = poFood['items'] as List<dynamic>? ?? [];
    final approvalFlows = poFood['approval_flows'] as List<dynamic>? ?? [];

    // Get status color
    final status = poFood['status']?.toString().toLowerCase() ?? '';
    
    // Calculate canApprove before building widgets
    final canApprove = (status == 'draft' || status == 'pending') && _currentApprovalLevel != null;
    
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
      case 'draft':
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
          'PO Food ${poFood['number'] ?? ''}',
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
                Colors.brown.shade600,
                Colors.brown.shade800,
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

            // Basic Info
            _buildSection(
              'Informasi Dasar',
              [
                _buildInfoRow('Number', poFood['number'] ?? '-', icon: Icons.tag),
                if (poFood['supplier'] != null)
                  _buildInfoRow('Supplier', poFood['supplier']['name'] ?? '-', icon: Icons.business),
                _buildInfoRow(
                  'Total Amount',
                  _formatCurrency(_parseDouble(poFood['grand_total'] ?? poFood['total_amount'])),
                  valueColor: const Color(0xFF10B981),
                  icon: Icons.attach_money,
                ),
                _buildInfoRow('Status', poFood['status'] ?? '-', icon: Icons.info_outline),
                if (poFood['date'] != null)
                  _buildInfoRow('Date', DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(poFood['date'])), icon: Icons.calendar_today),
                if (poFood['creator'] != null)
                  _buildInfoRow('Created By', poFood['creator']['nama_lengkap'] ?? '-', icon: Icons.person),
                if (poFood['created_at'] != null)
                  _buildInfoRow('Created At', _formatDateTime(poFood['created_at']), icon: Icons.access_time),
              ],
              icon: Icons.info_outline,
            ),

            // Items
            if (items.isNotEmpty) ...[
              _buildSection(
                'Detail Items',
                items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final stock = item['stock'];
                  print('Item ${item['item_id']} stock: $stock (type: ${stock?.runtimeType})');
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: index < items.length - 1 ? 12 : 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.brown.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.brown.withOpacity(0.1),
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
                                  colors: [Colors.brown.shade600, Colors.brown.shade800],
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
                              child: _buildItemDetail(
                                'Quantity',
                                _formatQuantity(item['quantity'] ?? item['qty']),
                                Icons.inventory_2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildItemDetail('Price', _formatCurrency(_parseDouble(item['price'])), Icons.price_check),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (stock != null && stock is Map) ...[
                          _buildItemDetail('Last Stock', _formatStockDisplay(stock as Map<String, dynamic>), Icons.inventory),
                          const SizedBox(height: 12),
                        ],
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
                                _formatCurrency(_parseDouble(item['total'] ?? item['subtotal'])),
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
            ],

            // Approval Flow
            if (approvalFlows.isNotEmpty) ...[
              _buildSection(
                'Approval Flow',
                approvalFlows.asMap().entries.map((entry) {
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
                    margin: EdgeInsets.only(bottom: index < approvalFlows.length - 1 ? 12 : 0),
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
              ),
            ],

            // Action Buttons - Only show if status is draft and user is current approver
            if (canApprove) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _showRejectDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.close, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tolak',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
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
                            color: Colors.brown.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Setujui',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
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
