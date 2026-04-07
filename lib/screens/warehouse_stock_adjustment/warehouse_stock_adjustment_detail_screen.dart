import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseStockAdjustmentDetailScreen extends StatefulWidget {
  final int adjustmentId;

  const WarehouseStockAdjustmentDetailScreen({
    super.key,
    required this.adjustmentId,
  });

  @override
  State<WarehouseStockAdjustmentDetailScreen> createState() =>
      _WarehouseStockAdjustmentDetailScreenState();
}

class _WarehouseStockAdjustmentDetailScreenState
    extends State<WarehouseStockAdjustmentDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  final TextEditingController _noteController = TextEditingController();

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await _approvalService.getWarehouseStockAdjustmentApprovalDetails(widget.adjustmentId);
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  String _formatDateTime(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (s.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(s);
      return DateFormat('dd MMM yyyy HH:mm').format(parsed);
    } catch (_) {
      return s;
    }
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _statusLabel(String? status) {
    final s = (status ?? '').toLowerCase();
    switch (s) {
      case 'waiting_approval':
        return 'Waiting Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return s.isNotEmpty ? s : '-';
    }
  }

  Widget _buildStatusChip(String? status) {
    final normalized = (status ?? '').toLowerCase();
    Color bg;
    Color fg;
    switch (normalized) {
      case 'waiting_approval':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFF92400E);
        break;
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildTypeChip(String? type) {
    final normalized = (type ?? '').toLowerCase();
    final isIn = normalized == 'in';
    final bg = isIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = isIn ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final label = isIn ? 'Stock In' : 'Stock Out';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Future<void> _showNoteDialog({
    required String title,
    required String actionLabel,
    required Color actionColor,
    required Future<Map<String, dynamic>> Function(String? note) action,
  }) async {
    _noteController.clear();
    final note = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _noteController.text.trim()),
              child: Text(actionLabel, style: TextStyle(color: actionColor, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (note == null) return; // user cancelled
    setState(() => _actionLoading = true);
    try {
      final result = await action(note?.isEmpty == true ? null : note);
      if (!mounted) return;
      setState(() => _actionLoading = false);
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? (result['message'] ?? 'Berhasil') : (result['message'] ?? 'Gagal')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onApprove() {
    _showNoteDialog(
      title: 'Approve Penyesuaian Stok',
      actionLabel: 'Approve',
      actionColor: Colors.green,
      action: (note) => _approvalService.approveWarehouseStockAdjustment(widget.adjustmentId, note: note),
    );
  }

  void _onReject() {
    _showNoteDialog(
      title: 'Tolak Penyesuaian Stok',
      actionLabel: 'Tolak',
      actionColor: Colors.red,
      action: (note) => _approvalService.rejectWarehouseStockAdjustment(widget.adjustmentId, note: note),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Stock Adjustment',
      showDrawer: false,
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(size: 26, color: Color(0xFF6366F1)),
            )
          : _data == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Detail tidak ditemukan',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final adjustment = _data!['adjustment'] as Map<String, dynamic>?;
    final items = _data!['items'] as List<dynamic>? ?? [];
    final approvers = _data!['approvers'] as List<dynamic>? ?? [];
    if (adjustment == null) return _buildEmpty();

    final number = adjustment['number']?.toString() ?? '-';
    final date = adjustment['date']?.toString();
    final type = adjustment['type']?.toString();
    final reason = adjustment['reason']?.toString();
    final status = adjustment['status']?.toString();
    final warehouse = adjustment['warehouse'];
    final warehouseName = warehouse is Map ? warehouse['name']?.toString() : null;
    final creator = adjustment['creator'];
    final creatorName = creator is Map ? (creator['nama_lengkap'] ?? creator['name'])?.toString() : null;
    final createdAt = adjustment['created_at']?.toString();
    final canAct = status?.toLowerCase() == 'waiting_approval';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(number, date, type, status),
              const SizedBox(height: 16),
              _buildInfoCard(warehouseName, creatorName, createdAt),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildReasonCard(reason),
              ],
              const SizedBox(height: 16),
              Text(
                'Detail Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 10),
              ...items.map((e) => _buildItemCard(e as Map<String, dynamic>)),
              if (approvers.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Approval History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 10),
                ...approvers.map((e) => _buildApproverCard(e as Map<String, dynamic>)),
              ],
            ],
          ),
        ),
        if (canAct)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _actionLoading ? null : _onReject,
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _actionLoading ? null : _onApprove,
                        icon: const Icon(Icons.check, size: 20, color: Colors.white),
                        label: const Text('Approve', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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

  Widget _buildHeaderCard(String number, String? date, String? type, String? status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                  number,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _buildTypeChip(type),
              const SizedBox(width: 6),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                _formatDate(date),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String? warehouseName, String? creatorName, String? createdAt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Adjustment',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Gudang', warehouseName ?? '-'),
          _buildInfoRow('Dibuat Oleh', creatorName ?? '-'),
          _buildInfoRow('Dibuat Pada', _formatDateTime(createdAt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard(String reason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final rel = item['item'];
    final itemName = rel is Map ? (rel['name'] ?? rel['nama'] ?? '-') : '-';
    final qty = _parseDouble(item['qty']);
    final qtyStr = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);
    final unit = rel is Map ? (rel['small_unit'] ?? rel['unit'] ?? '-') : '-';
    final unitName = unit is Map ? unit['name']?.toString() : unit?.toString();
    final note = item['note']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            itemName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPill(Icons.scale_rounded, '$qtyStr ${unitName ?? '-'}'),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildPill(Icons.note_outlined, note),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproverCard(Map<String, dynamic> a) {
    final approver = a['approver'];
    final name = approver is Map ? (approver['nama_lengkap'] ?? approver['name'])?.toString() : '-';
    final role = a['role']?.toString() ?? '-';
    final approvedAt = a['approved_at'];
    final note = a['note']?.toString();
    final hasApproved = approvedAt != null && approvedAt.toString().isNotEmpty;
    Color bg;
    Color fg;
    String statusLabel;
    if (hasApproved) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      statusLabel = 'APPROVED';
    } else {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFF92400E);
      statusLabel = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  name ?? '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(role, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
          if (hasApproved) ...[
            const SizedBox(height: 6),
            Text(
              _formatDateTime(approvedAt),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}
