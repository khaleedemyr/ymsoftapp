import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_stock_adjustment_models.dart';
import '../../services/outlet_stock_adjustment_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletStockAdjustmentDetailScreen extends StatefulWidget {
  final int adjustmentId;

  const OutletStockAdjustmentDetailScreen({super.key, required this.adjustmentId});

  @override
  State<OutletStockAdjustmentDetailScreen> createState() => _OutletStockAdjustmentDetailScreenState();
}

class _OutletStockAdjustmentDetailScreenState extends State<OutletStockAdjustmentDetailScreen> {
  final OutletStockAdjustmentService _service = OutletStockAdjustmentService();
  OutletStockAdjustmentDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _service.getAdjustment(widget.adjustmentId);
    if (mounted) {
      setState(() {
        if (result != null) {
          _detail = OutletStockAdjustmentDetail.fromJson(result);
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Stock Adjustment',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF6366F1)))
          : _detail == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final detail = _detail!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(detail),
          const SizedBox(height: 16),
          _buildInfoCard(detail),
          const SizedBox(height: 16),
          _buildReasonCard(detail.reason),
          const SizedBox(height: 16),
          Text(
            'Detail Item',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),
          ...detail.items.map(_buildItemCard).toList(),
          if (detail.approvalFlows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Approval History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 10),
            ...detail.approvalFlows.map(_buildApprovalCard).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(OutletStockAdjustmentDetail detail) {
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
                  detail.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              _buildTypeChip(detail.type),
              const SizedBox(width: 6),
              _buildStatusChip(detail.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(_formatDate(detail.date), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(OutletStockAdjustmentDetail detail) {
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
          _buildInfoRow('Outlet', detail.outletName ?? '-'),
          _buildInfoRow('Warehouse', detail.warehouseOutletName ?? '-'),
          _buildInfoRow('Dibuat Oleh', detail.creatorName ?? '-'),
          _buildInfoRow('Dibuat Pada', _formatDateTime(detail.createdAt)),
        ],
      ),
    );
  }

  Widget _buildReasonCard(String? reason) {
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
              reason?.isNotEmpty == true ? reason! : '-',
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
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

  Widget _buildItemCard(OutletStockAdjustmentItem item) {
    final qtyText = _formatNumber(item.qty);
    final unit = item.unit ?? '-';

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
            item.itemName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPill(Icons.scale_rounded, '$qtyText $unit'),
              if (item.note != null && item.note!.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildPill(Icons.note_outlined, item.note!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(OutletStockAdjustmentApprovalFlow flow) {
    final status = (flow.status ?? '').toUpperCase();
    Color bg;
    Color fg;

    switch (status) {
      case 'APPROVED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFF92400E);
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
                  flow.approverName ?? '-',
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
                  status.isNotEmpty ? status : '-',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          ),
          if (flow.approverTitle != null && flow.approverTitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(flow.approverTitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
          if (flow.comments != null && flow.comments!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(flow.comments!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
          if (flow.approvedAt != null && flow.approvedAt!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _formatDateTime(flow.approvedAt),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
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
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
      case 'waiting_cost_control':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
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
        _statusLabel(normalized),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_approval':
        return 'Waiting Approval';
      case 'waiting_cost_control':
        return 'Waiting Cost Control';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isNotEmpty ? status : '-';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(dateTime);
      return DateFormat('dd MMM yyyy HH:mm').format(parsed);
    } catch (e) {
      return dateTime ?? '-';
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Detail tidak ditemukan',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
