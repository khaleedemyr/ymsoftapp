import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/head_office_return_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class HeadOfficeReturnDetailScreen extends StatefulWidget {
  final int returnId;

  const HeadOfficeReturnDetailScreen({super.key, required this.returnId});

  @override
  State<HeadOfficeReturnDetailScreen> createState() => _HeadOfficeReturnDetailScreenState();
}

class _HeadOfficeReturnDetailScreenState extends State<HeadOfficeReturnDetailScreen> {
  final HeadOfficeReturnService _service = HeadOfficeReturnService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _approving = false;
  bool _rejecting = false;

  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.returnId);
    if (mounted) {
      setState(() {
        _data = result?['return'] != null ? Map<String, dynamic>.from(result!['return'] as Map) : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _approve() async {
    setState(() => _approving = true);
    final result = await _service.approve(widget.returnId);
    if (mounted) {
      setState(() => _approving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true ? (result['message']?.toString() ?? 'Berhasil disetujui') : (result['message']?.toString() ?? 'Gagal approve')),
          backgroundColor: result['success'] == true ? null : Colors.red,
        ),
      );
      if (result['success'] == true) Navigator.pop(context, true);
      else _loadDetail();
    }
  }

  Future<void> _rejectWithReason() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alasan Reject'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Masukkan alasan reject...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Alasan wajib diisi')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = controller.text.trim();
    setState(() => _rejecting = true);
    final result = await _service.reject(widget.returnId, reason);
    if (mounted) {
      setState(() => _rejecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true ? (result['message']?.toString() ?? 'Return ditolak') : (result['message']?.toString() ?? 'Gagal reject')),
          backgroundColor: result['success'] == true ? null : Colors.red,
        ),
      );
      if (result['success'] == true) Navigator.pop(context, true);
      else _loadDetail();
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _statusLabel(String? s) {
    if (s == 'pending') return 'Pending';
    if (s == 'approved') return 'Disetujui';
    if (s == 'rejected') return 'Ditolak';
    return s ?? '-';
  }

  Color _statusColor(String? s) {
    if (s == 'approved') return const Color(0xFF059669);
    if (s == 'rejected') return Colors.red;
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Kelola Return Outlet',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: _orange))
          : _data == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Data tidak ditemukan', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final t = _data!;
    final returnNumber = (t['return_number'] ?? '-').toString();
    final returnDate = t['return_date']?.toString();
    final grNumber = (t['gr_number'] ?? '-').toString();
    final outletName = (t['nama_outlet'] ?? '-').toString();
    final warehouseName = (t['warehouse_name'] ?? '-').toString();
    final status = t['status']?.toString();
    final createdByName = (t['created_by_name'] ?? '-').toString();
    final approvedByName = t['approved_by_name']?.toString();
    final rejectionByName = t['rejection_by_name']?.toString();
    final notes = t['notes']?.toString();
    final rejectionReason = t['rejection_reason']?.toString();
    final rawItems = t['items'];
    final items = rawItems is List
        ? rawItems.map((e) => Map<String, dynamic>.from(e is Map ? e : <String, dynamic>{})).toList()
        : <Map<String, dynamic>>[];
    final statusPending = status == 'pending';

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(returnNumber, returnDate, status),
            if (statusPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _approving ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _approving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(_approving ? 'Memproses...' : 'Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rejecting ? null : _rejectWithReason,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _rejecting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cancel_outlined, size: 20),
                      label: Text(_rejecting ? 'Memproses...' : 'Reject'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildInfoCard(
              grNumber: grNumber,
              outletName: outletName,
              warehouseName: warehouseName,
              createdByName: createdByName,
              approvedByName: approvedByName,
              rejectionByName: rejectionByName,
              notes: notes,
              rejectionReason: rejectionReason,
            ),
            const SizedBox(height: 16),
            _buildItemsCard(items),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String returnNumber, String? returnDate, String? status) {
    return Container(
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
              Expanded(
                child: Text(returnNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _statusColor(status))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Tanggal Return: ${_formatDate(returnDate)}', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String grNumber,
    required String outletName,
    required String warehouseName,
    required String createdByName,
    String? approvedByName,
    String? rejectionByName,
    String? notes,
    String? rejectionReason,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          _infoRow('No. GR', grNumber),
          _infoRow('Outlet', outletName),
          _infoRow('Gudang', warehouseName.isNotEmpty ? warehouseName : '-'),
          _infoRow('Dibuat Oleh', createdByName),
          if (approvedByName != null && approvedByName.isNotEmpty) _infoRow('Disetujui Oleh', approvedByName),
          if (rejectionByName != null && rejectionByName.isNotEmpty) _infoRow('Ditolak Oleh', rejectionByName),
          _infoRow('Keterangan', (notes != null && notes.isNotEmpty) ? notes : '-'),
          if (rejectionReason != null && rejectionReason.isNotEmpty) _infoRow('Alasan Reject', rejectionReason),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  Widget _buildItemsCard(List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Item Return', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Tidak ada item', style: TextStyle(color: Color(0xFF64748B))))
          else
            ...items.asMap().entries.map((e) {
              final i = e.value;
              final name = (i['item_name'] ?? '-').toString();
              final sku = (i['sku'] ?? '').toString();
              final qty = i['return_qty'];
              final unit = (i['unit_name'] ?? '').toString();
              final qtyStr = qty != null
                  ? NumberFormat('#,##0.##', 'id_ID').format(qty is num ? qty : double.tryParse(qty.toString()) ?? 0)
                  : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _orange.withOpacity(0.15),
                      child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _orange)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                          if (sku.isNotEmpty) Text('SKU: $sku', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text('$qtyStr $unit', style: const TextStyle(fontSize: 13, color: _orange, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
