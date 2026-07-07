import 'package:flutter/material.dart';
import '../../services/asset_inventory_adjustment_service.dart';
import '../../models/asset_inventory_adjustment_models.dart';
import '../../utils/asset_qty_format.dart';

class AssetInventoryAdjustmentDetailScreen extends StatefulWidget {
  final int adjustmentId;
  const AssetInventoryAdjustmentDetailScreen({super.key, required this.adjustmentId});

  @override
  State<AssetInventoryAdjustmentDetailScreen> createState() =>
      _AssetInventoryAdjustmentDetailScreenState();
}

class _AssetInventoryAdjustmentDetailScreenState
    extends State<AssetInventoryAdjustmentDetailScreen> {
  final _service = AssetInventoryAdjustmentService();
  AssetInventoryAdjustment? _adjustment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await _service.getAdjustment(widget.adjustmentId);
    if (data != null && mounted) {
      setState(() {
        _adjustment = AssetInventoryAdjustment.fromJson(data);
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING_APPROVAL':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'waiting_approval':
        return 'WAITING APPROVAL';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  Color _typeColor(String type) {
    return type.toLowerCase() == 'in' ? Colors.green : Colors.red;
  }

  String _typeLabel(String type) {
    return type.toLowerCase() == 'in' ? 'STOCK IN' : 'STOCK OUT';
  }

  Future<void> _handleApprove() async {
    final comments = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Approve Adjustment?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Komentar (opsional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (comments == null) return;

    final result = await _service.approve(
      widget.adjustmentId,
      comments: comments.isEmpty ? null : comments,
    );
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Berhasil di-approve.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    final comments = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Adjustment'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Alasan penolakan (wajib)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alasan wajib diisi.')),
                  );
                  return;
                }
                Navigator.pop(ctx, controller.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (comments == null) return;

    final result = await _service.reject(widget.adjustmentId, comments: comments);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Berhasil di-reject.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAdjustment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Adjustment?'),
        content: const Text('Data akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.deleteAdjustment(widget.adjustmentId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adjustment dihapus.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Asset Stock Adjustment'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_adjustment != null && _adjustment!.status.toLowerCase() == 'waiting_approval')
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteAdjustment,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _adjustment == null
              ? const Center(child: Text('Data tidak ditemukan.'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Card
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _adjustment!.number,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(_adjustment!.status).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusLabel(_adjustment!.status),
                                        style: TextStyle(
                                          color: _statusColor(_adjustment!.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _typeColor(_adjustment!.type).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _typeLabel(_adjustment!.type),
                                    style: TextStyle(
                                      color: _typeColor(_adjustment!.type),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _infoRow('Pemilik', _adjustment!.ownerOutletName ?? '-'),
                                _infoRow('Tanggal', _adjustment!.date),
                                _infoRow('Outlet', _adjustment!.outletName ?? '-'),
                                _infoRow('Warehouse', _adjustment!.warehouseOutletName ?? '-'),
                                _infoRow('Dibuat Oleh', _adjustment!.creatorName ?? '-'),
                                if (_adjustment!.reason != null && _adjustment!.reason!.isNotEmpty)
                                  _infoRow('Alasan', _adjustment!.reason!),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Approval Actions
                        if (_adjustment!.canApprove)
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.teal.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _handleApprove,
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _handleReject,
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_adjustment!.canApprove) const SizedBox(height: 12),

                        // Approval Flow
                        if (_adjustment!.approvalFlows.isNotEmpty)
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Approval Flow',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                  const SizedBox(height: 12),
                                  ..._adjustment!.approvalFlows.map((flow) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _statusColor(flow.status).withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(10),
                                        color: _statusColor(flow.status).withValues(alpha: 0.05),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: _statusColor(flow.status),
                                            child: Text(
                                              '${flow.approvalLevel}',
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  flow.approverName ?? '-',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                ),
                                                Text(
                                                  flow.approverJabatan ?? '-',
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                                if (flow.comments != null && flow.comments!.isNotEmpty)
                                                  Text(
                                                    '"${flow.comments}"',
                                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
                                                  ),
                                                if (flow.approvedAt != null)
                                                  Text('Approved: ${flow.approvedAt}',
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                if (flow.rejectedAt != null)
                                                  Text('Rejected: ${flow.rejectedAt}',
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _statusColor(flow.status).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              flow.status.toUpperCase(),
                                              style: TextStyle(
                                                color: _statusColor(flow.status),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Items
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Item Adjustment',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Item')),
                                      DataColumn(label: Text('Unit')),
                                      DataColumn(label: Text('Qty'), numeric: true),
                                      DataColumn(label: Text('Catatan')),
                                    ],
                                    rows: _adjustment!.items.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final item = entry.value;
                                      return DataRow(cells: [
                                        DataCell(Text('${idx + 1}')),
                                        DataCell(Text(item.itemName ?? '-')),
                                        DataCell(Text(item.unit ?? '-')),
                                        DataCell(Text(formatAssetQtyWithUnit(item.qty, null))),
                                        DataCell(Text(
                                          (item.note != null && item.note!.isNotEmpty) ? item.note! : '-',
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
