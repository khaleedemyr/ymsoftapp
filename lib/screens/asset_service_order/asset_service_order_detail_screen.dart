import 'package:flutter/material.dart';
import '../../services/asset_service_order_service.dart';
import '../../models/asset_service_order_models.dart';

class AssetServiceOrderDetailScreen extends StatefulWidget {
  final int orderId;
  const AssetServiceOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AssetServiceOrderDetailScreen> createState() =>
      _AssetServiceOrderDetailScreenState();
}

class _AssetServiceOrderDetailScreenState
    extends State<AssetServiceOrderDetailScreen> {
  final _service = AssetServiceOrderService();
  AssetServiceOrder? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await _service.getOrder(widget.orderId);
    if (data != null && mounted) {
      setState(() {
        _order = AssetServiceOrder.fromJson(data);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting_approval':
        return Colors.orange;
      case 'in_service':
        return Colors.blue;
      case 'partially_returned':
        return Colors.deepOrange;
      case 'returned':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_approval':
        return 'WAITING';
      case 'in_service':
        return 'IN SERVICE';
      case 'partially_returned':
        return 'PARTIAL RETURN';
      case 'returned':
        return 'RETURNED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  Color _flowColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(double val) {
    return 'Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ── Approve ──
  Future<void> _doApprove() async {
    final comments = await _showInputDialog('Approve Service Order',
        hintText: 'Komentar (opsional)', required: false);
    if (comments == null) return;

    final result = await _service.approve(widget.orderId, comments: comments);
    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Approved', Colors.green);
      _loadDetail();
    } else {
      _showSnack(result['message'] ?? 'Gagal approve', Colors.red);
    }
  }

  // ── Reject ──
  Future<void> _doReject() async {
    final comments = await _showInputDialog('Reject Service Order',
        hintText: 'Alasan penolakan (wajib)', required: true);
    if (comments == null || comments.isEmpty) return;

    final result =
        await _service.reject(widget.orderId, comments: comments);
    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Rejected', Colors.orange);
      _loadDetail();
    } else {
      _showSnack(result['message'] ?? 'Gagal reject', Colors.red);
    }
  }

  // ── Receive Return ──
  Future<void> _doReceiveReturn() async {
    if (_order == null) return;

    final returnableItems = _order!.items
        .where((i) => i.qtyReturned < i.qtyOut)
        .toList();
    if (returnableItems.isEmpty) {
      _showSnack('Semua item sudah dikembalikan', Colors.grey);
      return;
    }

    final qtyControllers = <int, TextEditingController>{};
    final noteControllers = <int, TextEditingController>{};
    final costController = TextEditingController(
        text: _order!.actualCost > 0
            ? _order!.actualCost.toStringAsFixed(0)
            : '');

    for (final item in returnableItems) {
      qtyControllers[item.itemId] = TextEditingController();
      noteControllers[item.itemId] = TextEditingController();
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Terima Kembali', style: TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...returnableItems.map((item) {
                  final remaining = (item.qtyOut - item.qtyReturned);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.itemName ?? 'Item #${item.itemId}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                            '${item.unit} • Sisa: ${remaining.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: qtyControllers[item.itemId],
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Qty Return (max ${remaining.toStringAsFixed(2)})',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: noteControllers[item.itemId],
                          decoration: const InputDecoration(
                            hintText: 'Catatan return...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                TextField(
                  controller: costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Biaya Aktual',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child:
                  const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final itemsPayload = <Map<String, dynamic>>[];
    for (final item in returnableItems) {
      final qtyText = qtyControllers[item.itemId]?.text ?? '';
      final qty = double.tryParse(qtyText) ?? 0;
      if (qty > 0) {
        itemsPayload.add({
          'item_id': item.itemId,
          'qty_returned': qty,
          'return_note': noteControllers[item.itemId]?.text ?? '',
        });
      }
    }

    if (itemsPayload.isEmpty) {
      _showSnack('Isi minimal 1 qty return', Colors.red);
      return;
    }

    final actualCost = double.tryParse(costController.text);

    final result = await _service.receiveReturn(
      widget.orderId,
      items: itemsPayload,
      actualCost: actualCost,
    );

    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Berhasil', Colors.green);
      _loadDetail();
    } else {
      _showSnack(result['message'] ?? 'Gagal', Colors.red);
    }
  }

  // ── Delete ──
  Future<void> _doDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Service Order?'),
        content: const Text('Data akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.deleteOrder(widget.orderId);
    if (result['success'] == true) {
      _showSnack('Berhasil dihapus', Colors.green);
      if (mounted) Navigator.pop(context, true);
    } else {
      _showSnack(result['message'] ?? 'Gagal', Colors.red);
    }
  }

  Future<String?> _showInputDialog(String title,
      {String? hintText, bool required = false}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Wajib diisi')),
                );
                return;
              }
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Service Order'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 16),
                        _buildApprovalFlow(),
                        const SizedBox(height: 16),
                        _buildItems(),
                        const SizedBox(height: 16),
                        _buildActions(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final o = _order!;
    return Card(
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
                  child: Text(o.number,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(o.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(o.status),
                    style: TextStyle(
                      color: _statusColor(o.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _infoRow('Tipe', o.serviceType == 'internal' ? 'Internal' : 'External'),
            _infoRow('Tanggal', o.date),
            _infoRow('Supplier', o.serviceType == 'internal' ? '—' : (o.supplierName ?? '-')),
            _infoRow('Outlet', o.outletName ?? '-'),
            _infoRow('Warehouse', o.warehouseOutletName ?? '-'),
            _infoRow('Dibuat Oleh', o.creatorName ?? '-'),
            _infoRow('Deskripsi', o.description ?? '-'),
            _infoRow('Est. Biaya', _formatCurrency(o.estimatedCost)),
            _infoRow('Biaya Aktual', _formatCurrency(o.actualCost)),
            if (o.sentDate != null) _infoRow('Tgl Kirim', o.sentDate!),
            if (o.returnDate != null) _infoRow('Tgl Kembali', o.returnDate!),
          ],
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
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child:
                Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalFlow() {
    final flows = _order!.approvalFlows;
    if (flows.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approval Flow',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...flows.map((flow) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _flowColor(flow.status),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 30,
                          color: Colors.grey.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Level ${flow.approvalLevel}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      _flowColor(flow.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(flow.status,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _flowColor(flow.status))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(flow.approverName ?? '-',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          if (flow.approverJabatan != null)
                            Text(flow.approverJabatan!,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          if (flow.approvedAt != null)
                            Text('Approved: ${flow.approvedAt}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.green)),
                          if (flow.rejectedAt != null)
                            Text('Rejected: ${flow.rejectedAt}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.red)),
                          if (flow.comments != null &&
                              flow.comments!.isNotEmpty)
                            Text('"${flow.comments}"',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontStyle: FontStyle.italic)),
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
    );
  }

  Widget _buildItems() {
    final items = _order!.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Item Service',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final progress = item.qtyOut > 0
                  ? (item.qtyReturned / item.qtyOut).clamp(0.0, 1.0)
                  : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${idx + 1}. ${item.itemName ?? '-'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${item.unit ?? '-'}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const Spacer(),
                        Text(
                            'Out: ${item.qtyOut}  |  Returned: ${item.qtyReturned}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0
                                      ? Colors.green
                                      : Colors.teal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(progress * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Catatan: ${item.note}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                      ),
                    if (item.returnNote != null && item.returnNote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Return note: ${item.returnNote}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_order == null) return const SizedBox.shrink();
    final o = _order!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o.canApprove) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _doApprove,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Approve',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _doReject,
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('Reject',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (o.canReceiveReturn)
          ElevatedButton.icon(
            onPressed: _doReceiveReturn,
            icon: const Icon(Icons.assignment_return, color: Colors.white),
            label: const Text('Terima Kembali',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        if (o.status == 'waiting_approval') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _doDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label:
                const Text('Hapus', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      ],
    );
  }
}
