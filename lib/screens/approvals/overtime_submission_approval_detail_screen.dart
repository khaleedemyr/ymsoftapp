import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';

class OvertimeSubmissionApprovalDetailScreen extends StatefulWidget {
  final int submissionId;

  const OvertimeSubmissionApprovalDetailScreen({
    super.key,
    required this.submissionId,
  });

  @override
  State<OvertimeSubmissionApprovalDetailScreen> createState() =>
      _OvertimeSubmissionApprovalDetailScreenState();
}

class _OvertimeSubmissionApprovalDetailScreenState
    extends State<OvertimeSubmissionApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  final TextEditingController _rejectReasonController = TextEditingController();

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final result = await _approvalService.getOvertimeSubmissionApprovalDetails(widget.submissionId);
      if (!mounted) return;
      if (result['success'] == true && result['submission'] != null) {
        setState(() {
          _data = Map<String, dynamic>.from(result['submission'] as Map);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Gagal memuat detail')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _handleApprove() async {
    if (_isProcessing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Pengajuan Lembur?'),
        content: const Text('Approval akan diteruskan ke level berikutnya jika masih ada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final result = await _approvalService.approveOvertimeSubmission(widget.submissionId);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil disetujui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Gagal approve')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pengajuan Lembur'),
        content: TextField(
          controller: _rejectReasonController,
          decoration: const InputDecoration(
            hintText: 'Alasan penolakan',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
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
    setState(() => _isProcessing = true);
    try {
      final result = await _approvalService.rejectOvertimeSubmission(
        widget.submissionId,
        rejectionReason: _rejectReasonController.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan lembur ditolak')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Gagal reject')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _rejectReasonController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApprove = _data?['can_approve'] == true;
    final items = (_data?['items'] as List?) ?? [];
    final flows = List<Map<String, dynamic>>.from((_data?['approval_flows'] as List?) ?? []);
    flows.sort((a, b) => (a['approval_level'] ?? 0).compareTo(b['approval_level'] ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Overtime Submission'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _data == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _section(
                            title: 'Informasi',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _row('Nomor', (_data!['number'] ?? '-').toString()),
                                _row('Tanggal', _formatDate(_data!['submission_date'])),
                                _row('Pembuat', (_data!['creator']?['nama_lengkap'] ?? '-').toString()),
                                _row('Status', (_data!['status'] ?? '-').toString()),
                                _row(
                                  'Alasan',
                                  (_data!['notes'] ?? '').toString().trim().isEmpty
                                      ? '-'
                                      : _data!['notes'].toString(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _section(
                            title: 'Daftar Karyawan',
                            child: Column(
                              children: items.map((raw) {
                                final item = Map<String, dynamic>.from(raw as Map);
                                final itemNotes = (item['notes'] ?? '').toString().trim();
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text((item['user']?['nama_lengkap'] ?? '-').toString()),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_formatDate(item['overtime_date'])),
                                      if (itemNotes.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            itemNotes,
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                        ),
                                    ],
                                  ),
                                  isThreeLine: itemNotes.isNotEmpty,
                                  trailing: Text(
                                    '${item['requested_hours'] ?? 0} jam',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _section(
                            title: 'Approval Flow',
                            child: Column(
                              children: flows.map((flow) {
                                final status = (flow['status'] ?? 'PENDING').toString();
                                Color color = Colors.orange;
                                if (status == 'APPROVED') color = Colors.green;
                                if (status == 'REJECTED') color = Colors.red;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text((flow['approver']?['nama_lengkap'] ?? '-').toString()),
                                  subtitle: Text('Level ${flow['approval_level'] ?? '-'}'),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canApprove)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isProcessing ? null : _showRejectDialog,
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Tolak'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isProcessing ? null : _handleApprove,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                                  child: Text(_isProcessing ? 'Memproses...' : 'Setujui'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SafeArea(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Menunggu persetujuan level sebelumnya.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ),
                    const AppFooter(),
                  ],
                ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
