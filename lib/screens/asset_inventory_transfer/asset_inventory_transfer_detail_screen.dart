import 'package:flutter/material.dart';
import '../../services/asset_inventory_transfer_service.dart';
import '../../models/asset_inventory_transfer_models.dart';

class AssetInventoryTransferDetailScreen extends StatefulWidget {
  final int transferId;
  const AssetInventoryTransferDetailScreen({super.key, required this.transferId});

  @override
  State<AssetInventoryTransferDetailScreen> createState() =>
      _AssetInventoryTransferDetailScreenState();
}

class _AssetInventoryTransferDetailScreenState
    extends State<AssetInventoryTransferDetailScreen> {
  final _service = AssetInventoryTransferService();
  AssetInventoryTransfer? _transfer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await _service.getTransfer(widget.transferId);
    if (data != null && mounted) {
      setState(() {
        _transfer = AssetInventoryTransfer.fromJson(data);
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return Colors.grey;
      case 'SUBMITTED':
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleApproval(String action) async {
    String? comments;

    if (action == 'reject') {
      comments = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Reject Transfer'),
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
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve Transfer?'),
          content: const Text('Anda yakin ingin menyetujui transfer ini?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final result = await _service.approve(
      widget.transferId,
      action: action,
      comments: comments,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Berhasil.'),
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

  Future<void> _deleteTransfer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transfer?'),
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

    final result = await _service.deleteTransfer(widget.transferId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer dihapus.'), backgroundColor: Colors.green),
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
        title: const Text('Detail Asset Transfer'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_transfer != null && _transfer!.status == 'draft')
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteTransfer,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transfer == null
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
                                    Text(
                                      _transfer!.transferNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(_transfer!.status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _transfer!.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(_transfer!.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _infoRow('Tanggal', _transfer!.transferDate),
                                _infoRow('Dari', '${_transfer!.outletFromName ?? '-'} - ${_transfer!.warehouseOutletFromName ?? '-'}'),
                                _infoRow('Ke', '${_transfer!.outletToName ?? '-'} - ${_transfer!.warehouseOutletToName ?? '-'}'),
                                _infoRow('Dibuat Oleh', _transfer!.creatorName ?? '-'),
                                if (_transfer!.notes != null && _transfer!.notes!.isNotEmpty)
                                  _infoRow('Catatan', _transfer!.notes!),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Approval Actions
                        if (_transfer!.canApprove)
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.teal.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _handleApproval('approve'),
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
                                      onPressed: () => _handleApproval('reject'),
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
                        if (_transfer!.canApprove) const SizedBox(height: 12),

                        // Approval Flow
                        if (_transfer!.approvalFlows.isNotEmpty)
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
                                  ..._transfer!.approvalFlows.map((flow) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _statusColor(flow.status).withOpacity(0.3)),
                                        borderRadius: BorderRadius.circular(10),
                                        color: _statusColor(flow.status).withOpacity(0.05),
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
                                              color: _statusColor(flow.status).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              flow.status,
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
                                const Text('Item Transfer',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                const SizedBox(height: 12),
                                ..._transfer!.items.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final item = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.teal.shade100,
                                          child: Text('${idx + 1}',
                                              style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.itemName ?? '-',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                              Text(
                                                'Qty: ${item.qty} ${item.unitName ?? ''}',
                                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              ),
                                              if (item.note != null && item.note!.isNotEmpty)
                                                Text(item.note!,
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
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
