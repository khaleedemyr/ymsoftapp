import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class CorrectionApprovalDetailScreen extends StatefulWidget {
  final int correctionId;

  const CorrectionApprovalDetailScreen({
    super.key,
    required this.correctionId,
  });

  @override
  State<CorrectionApprovalDetailScreen> createState() => _CorrectionApprovalDetailScreenState();
}

class _CorrectionApprovalDetailScreenState extends State<CorrectionApprovalDetailScreen> {
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

      final url = '${ApprovalService.baseUrl}/api/approval-app/schedule-attendance-correction/${widget.correctionId}';
      print('Correction Detail: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Correction Detail: Status code = ${response.statusCode}');
      print('Correction Detail: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Correction Detail: Parsed data = $data');
        if (data['success'] == true && data['correction'] != null) {
          setState(() {
            _approvalData = data['correction'];
            _isLoading = false;
          });
          print('Correction Detail: Data loaded successfully');
          return;
        } else {
          print('Correction Detail: success=false or correction is null');
          print('Correction Detail: data = $data');
        }
      } else {
        print('Correction Detail: Non-200 status code: ${response.statusCode}');
        print('Correction Detail: Response body = ${response.body}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading Correction details: $e');
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
        title: const Text('Setujui Correction?'),
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
      final result = await _approvalService.approveCorrection(
        widget.correctionId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correction berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal menyetujui Correction')),
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
        title: const Text('Tolak Correction?'),
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
      final result = await _approvalService.rejectCorrection(
        widget.correctionId,
        rejection_reason: _rejectReasonController.text.trim().isEmpty ? null : _rejectReasonController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correction berhasil ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal menolak Correction')),
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

  String _getTypeDisplay(String? type) {
    switch (type?.toLowerCase()) {
      case 'schedule':
        return 'Schedule Correction';
      case 'manual_attendance':
        return 'Manual Attendance';
      case 'attendance':
        return 'Attendance Correction';
      default:
        return type ?? '-';
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return dateTime;
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

  String _formatOldValue(dynamic oldValue, String? type) {
    if (oldValue == null) return '-';
    
    String oldValueStr = oldValue.toString();
    
    // For schedule type, just return the shift name
    if (type?.toLowerCase() == 'schedule') {
      return oldValueStr == 'OFF' ? 'OFF' : oldValueStr;
    }
    
    // For manual_attendance, try to parse JSON
    if (type?.toLowerCase() == 'manual_attendance') {
      try {
        final json = jsonDecode(oldValueStr);
        final scanDate = json['scan_date'] ?? '';
        final inoutMode = json['inoutmode'] ?? '';
        final inoutText = inoutMode == 1 ? 'IN' : inoutMode == 2 ? 'OUT' : 'Unknown';
        return '$inoutText - ${_formatDateTime(scanDate)}';
      } catch (e) {
        return oldValueStr;
      }
    }
    
    return oldValueStr;
  }

  Widget _buildNewValueWidget(dynamic newValue, String? type) {
    if (newValue == null) {
      return Text('-', style: TextStyle(fontSize: 15, color: Colors.grey.shade800, fontWeight: FontWeight.w600));
    }
    
    String newValueStr = newValue.toString();
    
    // For schedule type, just return the shift name
    if (type?.toLowerCase() == 'schedule') {
      return Text(
        newValueStr == 'OFF' ? 'OFF' : newValueStr,
        style: const TextStyle(fontSize: 15, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
      );
    }
    
    // For manual_attendance, parse JSON and display in a structured way
    if (type?.toLowerCase() == 'manual_attendance') {
      try {
        final json = jsonDecode(newValueStr);
        final scanDate = json['scan_date'] ?? '';
        final pin = json['pin'] ?? '';
        final inoutMode = json['inoutmode'] ?? '';
        final verifyMode = json['verifymode'] ?? '';
        final deviceIp = json['device_ip'] ?? '';
        final sn = json['sn'] ?? '';
        
        final inoutText = inoutMode == 1 ? 'IN' : inoutMode == 2 ? 'OUT' : 'Unknown';
        final verifyText = verifyMode == 1 ? 'Fingerprint' : verifyMode == 2 ? 'PIN' : verifyMode == 3 ? 'RFID' : 'Unknown';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Scan Date', _formatDateTime(scanDate), Icons.access_time),
                  const SizedBox(height: 8),
                  _buildDetailRow('PIN', pin, Icons.person_pin),
                  const SizedBox(height: 8),
                  _buildDetailRow('In/Out Mode', inoutText, Icons.swap_horiz),
                  const SizedBox(height: 8),
                  _buildDetailRow('Verify Mode', verifyText, Icons.verified_user),
                  if (deviceIp.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Device IP', deviceIp, Icons.devices),
                  ],
                  if (sn.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Serial Number', sn, Icons.tag),
                  ],
                ],
              ),
            ),
          ],
        );
      } catch (e) {
        return Text(
          newValueStr,
          style: const TextStyle(fontSize: 15, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
        );
      }
    }
    
    return Text(
      newValueStr,
      style: const TextStyle(fontSize: 15, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade400.withOpacity(0.1),
                  Colors.orange.shade600.withOpacity(0.05),
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
                        colors: [Colors.orange.shade600, Colors.orange.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.shade600.withOpacity(0.3),
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

  Widget _buildInfoRow(String label, String value, {IconData? icon, Color? valueColor, Widget? customValue}) {
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
                color: Colors.orange.shade600.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.orange.shade600,
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
                customValue ?? Text(
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Correction Approval Detail'),
        ),
        body: const Center(
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (_approvalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Correction Approval Detail'),
        ),
        body: const Center(
          child: Text('Data tidak ditemukan'),
        ),
      );
    }

    final correction = _approvalData!;
    final status = correction['status']?.toString().toLowerCase() ?? 'pending';
    
    // Get status color
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
        title: const Text(
          'Correction Approval Detail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade600,
                Colors.orange.shade800,
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

                    // Informasi Dasar
                    _buildSection(
                      'Informasi Dasar',
                      [
                        _buildInfoRow('ID', correction['id']?.toString() ?? '-', icon: Icons.tag),
                        _buildInfoRow('Type', _getTypeDisplay(correction['type']), icon: Icons.category),
                        if (correction['employee'] != null)
                          _buildInfoRow('Employee', correction['employee']['nama_lengkap'] ?? '-', icon: Icons.person),
                        if (correction['outlet'] != null)
                          _buildInfoRow('Outlet', correction['outlet']['nama_outlet'] ?? '-', icon: Icons.store),
                        if (correction['division'] != null)
                          _buildInfoRow('Division', correction['division']['nama_divisi'] ?? '-', icon: Icons.business),
                        if (correction['tanggal'] != null)
                          _buildInfoRow('Date', _formatDate(correction['tanggal']), icon: Icons.calendar_today),
                        if (correction['old_value'] != null)
                          _buildInfoRow(
                            'Old Value',
                            _formatOldValue(correction['old_value'], correction['type']),
                            icon: Icons.arrow_back,
                          ),
                        if (correction['new_value'] != null)
                          _buildInfoRow(
                            'New Value',
                            '',
                            icon: Icons.arrow_forward,
                            customValue: _buildNewValueWidget(correction['new_value'], correction['type']),
                          ),
                        if (correction['reason'] != null && correction['reason'].toString().isNotEmpty)
                          _buildInfoRow('Reason', correction['reason'] ?? '-', icon: Icons.description),
                        if (correction['requester'] != null)
                          _buildInfoRow('Requested By', correction['requester']['nama_lengkap'] ?? '-', icon: Icons.person_outline),
                        if (correction['created_at'] != null)
                          _buildInfoRow('Created At', _formatDateTime(correction['created_at']), icon: Icons.access_time),
                      ],
                      icon: Icons.info_outline,
                    ),

                    // Approval Flow
                    if (correction['approval_flows'] != null && (correction['approval_flows'] as List).isNotEmpty)
                      _buildSection(
                        'Approval Flow',
                        [
                          ...(correction['approval_flows'] as List).asMap().entries.map((entry) {
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
                              margin: EdgeInsets.only(bottom: index < (correction['approval_flows'] as List).length - 1 ? 12 : 0),
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
                                        if (flow['comments'] != null && flow['comments'].toString().isNotEmpty) ...[
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
                                                    flow['comments'] ?? '-',
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
                        ],
                        icon: Icons.account_tree,
                      ),

                    // Action Buttons - Only show if status is pending
                    if (status == 'pending') ...[
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
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _handleApprove,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
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
