import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class EmployeeResignationApprovalDetailScreen extends StatefulWidget {
  final int resignationId;

  const EmployeeResignationApprovalDetailScreen({
    super.key,
    required this.resignationId,
  });

  @override
  State<EmployeeResignationApprovalDetailScreen> createState() => _EmployeeResignationApprovalDetailScreenState();
}

class _EmployeeResignationApprovalDetailScreenState extends State<EmployeeResignationApprovalDetailScreen> {
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

      final url = '${ApprovalService.baseUrl}/api/approval-app/employee-resignation/${widget.resignationId}';
      print('Employee Resignation Detail: Calling $url');
      print('Employee Resignation Detail: Resignation ID = ${widget.resignationId}');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Employee Resignation Detail: Status code = ${response.statusCode}');
      print('Employee Resignation Detail: Response body = ${response.body}');
      
      // Check if response is empty or error
      if (response.body.isEmpty) {
        print('Employee Resignation Detail: Response body is empty!');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Employee Resignation Detail: Parsed data = $data');
        print('Employee Resignation Detail: success = ${data['success']}');
        print('Employee Resignation Detail: resignation = ${data['resignation']}');
        
        // Try to get resignation data - handle different response structures
        Map<String, dynamic>? resignationData;
        if (data['success'] == true && data['resignation'] != null) {
          resignationData = data['resignation'] as Map<String, dynamic>?;
        } else if (data['resignation'] != null) {
          // Fallback: if resignation exists but success is not true
          resignationData = data['resignation'] as Map<String, dynamic>?;
        } else if (data is Map<String, dynamic> && data.containsKey('id')) {
          // Fallback: if response is directly the resignation object
          resignationData = data;
        }
        
        if (resignationData != null) {
          print('Employee Resignation Detail: Resignation ID = ${resignationData['id']}');
          print('Employee Resignation Detail: Resignation Number = ${resignationData['resignation_number']}');
          print('Employee Resignation Detail: Status = ${resignationData['status']}');
          print('Employee Resignation Detail: Current Approval Flow ID = ${resignationData['current_approval_flow_id']}');
          print('Employee Resignation Detail: Employee = ${resignationData['employee']}');
          print('Employee Resignation Detail: Outlet = ${resignationData['outlet']}');
          
          setState(() {
            _approvalData = resignationData;
            _isLoading = false;
          });
          print('Employee Resignation Detail: Data loaded successfully');
          return;
        } else {
          print('Employee Resignation Detail: Could not extract resignation data');
          print('Employee Resignation Detail: data = $data');
          if (data['resignation'] == null) {
            print('Employee Resignation Detail: resignation is null in response');
          }
          if (data['success'] != true) {
            print('Employee Resignation Detail: success is not true');
          }
        }
      } else {
        print('Employee Resignation Detail: Non-200 status code: ${response.statusCode}');
        print('Employee Resignation Detail: Response body = ${response.body}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading Employee Resignation details: $e');
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
        title: const Text('Setujui Employee Resignation?'),
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
      final result = await _approvalService.approveEmployeeResignation(
        widget.resignationId,
        approvalFlowId: approvalFlowId != null ? int.tryParse(approvalFlowId.toString()) : null,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee Resignation berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Gagal menyetujui Employee Resignation')),
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
        title: const Text('Tolak Employee Resignation?'),
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
      final approvalFlowId = _approvalData?['current_approval_flow_id'];
      final result = await _approvalService.rejectEmployeeResignation(
        widget.resignationId,
        note: _rejectReasonController.text.trim(),
        approvalFlowId: approvalFlowId != null ? int.tryParse(approvalFlowId.toString()) : null,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee Resignation berhasil ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Gagal menolak Employee Resignation')),
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

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      String dateStr = date.toString();
      if (dateStr.isEmpty) return '-';
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return date.toString();
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
                  const Color(0xFFEF4444).withOpacity(0.1),
                  const Color(0xFFF87171).withOpacity(0.05),
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
                        colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
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
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFFEF4444),
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
          title: const Text('Employee Resignation Approval Detail'),
        ),
        body: const Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Employee Resignation Approval Detail'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Data tidak ditemukan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan coba refresh atau hubungi administrator',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _loadApprovalDetails();
                },
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    final resignation = _approvalData!;
    final approvalFlows = resignation['approval_flows'] as List<dynamic>? ?? [];

    // Get status color - handle both lowercase and uppercase
    final statusRaw = resignation['status']?.toString() ?? '';
    final status = statusRaw.toUpperCase();
    final currentApprovalFlowId = resignation['current_approval_flow_id'];
    
    // Calculate canApprove before building widgets
    final canApprove = (status == 'SUBMITTED' || statusRaw.toLowerCase() == 'submitted') && 
                      currentApprovalFlowId != null;
    
    print('Employee Resignation Detail: Status = $status (raw: $statusRaw)');
    print('Employee Resignation Detail: Current Approval Flow ID = $currentApprovalFlowId');
    print('Employee Resignation Detail: Approval Flows count = ${approvalFlows.length}');
    print('Employee Resignation Detail: Can Approve = $canApprove');
    print('Employee Resignation Detail: Full data = $resignation');
    
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    
    switch (status) {
      case 'APPROVED':
        statusColor = const Color(0xFF10B981);
        statusBgColor = const Color(0xFF10B981).withOpacity(0.1);
        statusIcon = Icons.check_circle;
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        statusBgColor = const Color(0xFFEF4444).withOpacity(0.1);
        statusIcon = Icons.cancel;
        break;
      case 'SUBMITTED':
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
          'Resignation #${resignation['resignation_number'] ?? resignation['id'] ?? ''}',
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
                const Color(0xFFEF4444),
                const Color(0xFFF87171),
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
                          status.replaceAll('_', ' '),
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
                _buildInfoRow('ID', resignation['id']?.toString() ?? '-', icon: Icons.tag),
                _buildInfoRow('Resignation Number', resignation['resignation_number']?.toString() ?? '-', icon: Icons.numbers),
                _buildInfoRow(
                  'Employee', 
                  resignation['employee'] != null 
                    ? (resignation['employee']['nama_lengkap']?.toString() ?? '-')
                    : '-', 
                  icon: Icons.person
                ),
                if (resignation['employee'] != null && resignation['employee']['nik'] != null)
                  _buildInfoRow('NIK', resignation['employee']['nik']?.toString() ?? '-', icon: Icons.badge),
                if (resignation['employee'] != null && resignation['employee']['email'] != null)
                  _buildInfoRow('Employee Email', resignation['employee']['email']?.toString() ?? '-', icon: Icons.email),
                _buildInfoRow(
                  'Outlet', 
                  resignation['outlet'] != null 
                    ? (resignation['outlet']['nama_outlet']?.toString() ?? '-')
                    : '-', 
                  icon: Icons.store
                ),
                _buildInfoRow(
                  'Resignation Date', 
                  resignation['resignation_date'] != null
                    ? _formatDate(resignation['resignation_date']?.toString())
                    : '-', 
                  icon: Icons.calendar_today
                ),
                _buildInfoRow(
                  'Type', 
                  resignation['resignation_type'] != null
                    ? (resignation['resignation_type']?.toString().toUpperCase().replaceAll('_', ' ') ?? '-')
                    : '-', 
                  icon: Icons.category
                ),
                if (resignation['notes'] != null && resignation['notes'].toString().isNotEmpty)
                  _buildInfoRow('Notes', resignation['notes']?.toString() ?? '-', icon: Icons.note),
                _buildInfoRow(
                  'Created By', 
                  resignation['creator'] != null 
                    ? (resignation['creator']['nama_lengkap']?.toString() ?? '-')
                    : '-', 
                  icon: Icons.person_outline
                ),
                if (resignation['creator'] != null && resignation['creator']['email'] != null)
                  _buildInfoRow('Creator Email', resignation['creator']['email']?.toString() ?? '-', icon: Icons.email_outlined),
                _buildInfoRow(
                  'Created At', 
                  resignation['created_at'] != null
                    ? _formatDateTime(resignation['created_at'])
                    : '-', 
                  icon: Icons.access_time
                ),
              ],
              icon: Icons.info_outline,
            ),

            // Approval Flow
            if (approvalFlows.isNotEmpty)
              _buildSection(
                'Approval Flow',
                approvalFlows.map((flow) {
                  final flowStatus = flow['status']?.toString().toUpperCase() ?? 'PENDING';
                  final approvalLevel = flow['approval_level']?.toString() ?? '-';
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: flowStatusColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: flowStatusColor.withOpacity(0.1),
                          blurRadius: 4,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.layers, size: 14, color: const Color(0xFF3B82F6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Level $approvalLevel',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
                        const SizedBox(height: 12),
                        if (flow['approver'] != null && flow['approver']['nama_lengkap'] != null) ...[
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      flow['approver']['nama_lengkap'] ?? '-',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    if (flow['approver']['email'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        flow['approver']['email'] ?? '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (flow['comments'] != null && flow['comments'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.comment, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Comments:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        flow['comments'] ?? '-',
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
                      ],
                    ),
                  );
                }).toList(),
                icon: Icons.timeline,
              ),

            // Action Buttons - Only show if status is submitted and user is current approver
            if (canApprove) ...[
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
}
