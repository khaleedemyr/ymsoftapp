import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/overtime_submission_service.dart';
import '../../widgets/app_loading_indicator.dart';

class OvertimeSubmissionDetailScreen extends StatefulWidget {
  final int submissionId;

  const OvertimeSubmissionDetailScreen({super.key, required this.submissionId});

  @override
  State<OvertimeSubmissionDetailScreen> createState() => _OvertimeSubmissionDetailScreenState();
}

class _OvertimeSubmissionDetailScreenState extends State<OvertimeSubmissionDetailScreen> {
  static const Color _indigo = Color(0xFF4F46E5);

  final _service = OvertimeSubmissionService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDetail(widget.submissionId);
    if (!mounted) return;
    setState(() {
      _data = res?['submission'] is Map
          ? Map<String, dynamic>.from(res!['submission'] as Map)
          : null;
      _loading = false;
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    try {
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.parse(value.toString()).toLocal());
    } catch (_) {
      return value.toString();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from((_data?['items'] as List?) ?? []);
    final flows = List<Map<String, dynamic>>.from((_data?['approval_flows'] as List?) ?? []);
    flows.sort((a, b) => (a['approval_level'] ?? 0).compareTo(b['approval_level'] ?? 0));
    final status = _data?['status']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: const Text('Detail Pengajuan Lembur', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _data == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _data!['number']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _row('Tanggal', _formatDate(_data!['submission_date'])),
                          _row('Pembuat', _data!['creator']?['nama_lengkap']?.toString() ?? '-'),
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
                    _card(
                      title: 'Daftar Karyawan',
                      child: Column(
                        children: items.map((item) {
                          final itemNotes = (item['notes'] ?? '').toString().trim();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item['user']?['nama_lengkap']?.toString() ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatDate(item['overtime_date'])),
                                if (itemNotes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      itemNotes,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: itemNotes.isNotEmpty,
                            trailing: Text(
                              '${item['requested_hours'] ?? 0} jam',
                              style: const TextStyle(color: _indigo, fontWeight: FontWeight.w800),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: 'Approval Flow',
                      child: Column(
                        children: flows.map((flow) {
                          final flowStatus = flow['status']?.toString() ?? 'PENDING';
                          final color = _statusColor(flowStatus == 'PENDING' ? 'SUBMITTED' : flowStatus);
                          String when = 'Waiting';
                          if (flowStatus == 'APPROVED') when = _formatDateTime(flow['approved_at']);
                          if (flowStatus == 'REJECTED') when = _formatDateTime(flow['rejected_at']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text(
                                'L${flow['approval_level'] ?? '-'}',
                                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                            title: Text(flow['approver']?['nama_lengkap']?.toString() ?? '-'),
                            subtitle: Text(when),
                            trailing: Text(
                              flowStatus,
                              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _card({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
