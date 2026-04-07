import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_rejection_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'outlet_rejection_create_screen.dart';

class OutletRejectionDetailScreen extends StatefulWidget {
  final int rejectionId;

  const OutletRejectionDetailScreen({super.key, required this.rejectionId});

  @override
  State<OutletRejectionDetailScreen> createState() => _OutletRejectionDetailScreenState();
}

class _OutletRejectionDetailScreenState extends State<OutletRejectionDetailScreen> {
  final OutletRejectionService _service = OutletRejectionService();
  Map<String, dynamic>? _rejection;
  bool _isLoading = true;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  T? _get<T>(Map<String, dynamic> m, String snakeKey, String camelKey) {
    final v = m[camelKey] ?? m[snakeKey];
    return v is T ? v : null;
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.rejectionId);
    if (mounted) {
      setState(() {
        _rejection = result?['rejection'];
        _canDelete = result?['can_delete'] == true;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'draft': return 'Draft';
      case 'submitted': return 'Submitted';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Dibatalkan';
      case 'rejected': return 'Ditolak';
      default: return s ?? '-';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed': return const Color(0xFF16A34A);
      case 'draft': return const Color(0xFFCA8A04);
      case 'cancelled': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return const Color(0xFF0EA5E9);
    }
  }

  String _conditionLabel(String? c) {
    switch (c) {
      case 'good': return 'Baik';
      case 'damaged': return 'Rusak';
      case 'expired': return 'Kadaluarsa';
      case 'other': return 'Lainnya';
      default: return c ?? '-';
    }
  }

  Future<void> _confirmCancel() async {
    final number = _rejection?['number']?.toString() ?? '-';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Outlet Rejection?'),
        content: Text('Lanjutkan batalkan $number?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Batalkan')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _service.cancel(widget.rejectionId);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil dibatalkan'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final number = _rejection?['number']?.toString() ?? '-';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Outlet Rejection?'),
        content: Text('Hapus $number? Hanya draft yang dapat dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _service.delete(widget.rejectionId);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil dihapus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Outlet Rejection',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9)))
          : _rejection == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final r = _rejection!;
    final number = r['number']?.toString() ?? '-';
    final dateText = _formatDate(r['rejection_date']?.toString());
    final status = r['status']?.toString();
    final outlet = _get<Map<String, dynamic>>(r, 'outlet', 'outlet');
    final warehouse = _get<Map<String, dynamic>>(r, 'warehouse', 'warehouse');
    final outletName = outlet?['nama_outlet']?.toString() ?? '-';
    final warehouseName = warehouse?['name']?.toString() ?? '-';
    final notes = r['notes']?.toString();
    final itemsRaw = r['items'];
    final items = (itemsRaw is List) ? itemsRaw.map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    final canCancel = status == 'draft' || status == 'submitted';
    final isDraft = status == 'draft';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _row('Outlet', outletName),
                _row('Gudang', warehouseName),
                _row('Catatan', (notes != null && notes.isNotEmpty) ? notes : '-'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...items.map(_buildItemCard),
          const SizedBox(height: 16),
          if (canCancel || (isDraft && _canDelete) || isDraft)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isDraft)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OutletRejectionCreateScreen(editId: widget.rejectionId),
                        ),
                      );
                      if (result == true && mounted) _loadDetail();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: _confirmCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Batalkan'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                if (isDraft && _canDelete)
                  ElevatedButton.icon(
                    onPressed: _confirmDelete,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                  ),
              ],
            ),
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemData = item['item'] is Map ? item['item'] as Map<String, dynamic>? : null;
    final unitData = item['unit'] is Map ? item['unit'] as Map<String, dynamic>? : null;
    final name = itemData?['name']?.toString() ?? '-';
    final unitName = unitData?['name']?.toString() ?? '-';
    final qtyRejected = (item['qty_rejected'] is num) ? (item['qty_rejected'] as num).toDouble() : double.tryParse(item['qty_rejected']?.toString() ?? '') ?? 0;
    final condition = item['item_condition']?.toString();
    final reason = item['rejection_reason']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Qty: $qtyRejected $unitName', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _conditionColor(condition).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_conditionLabel(condition), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _conditionColor(condition))),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Alasan: $reason', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
        ],
      ),
    );
  }

  Color _conditionColor(String? c) {
    switch (c) {
      case 'good': return const Color(0xFF16A34A);
      case 'damaged': return Colors.red;
      case 'expired': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
