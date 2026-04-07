import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stock_opname_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'stock_opname_form_screen.dart';

class StockOpnameDetailScreen extends StatefulWidget {
  final int opnameId;

  const StockOpnameDetailScreen({super.key, required this.opnameId});

  @override
  State<StockOpnameDetailScreen> createState() => _StockOpnameDetailScreenState();
}

class _StockOpnameDetailScreenState extends State<StockOpnameDetailScreen> {
  final StockOpnameService _service = StockOpnameService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.opnameId);
    if (mounted) {
      setState(() {
        _data = result;
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

  Color _statusColor(String? s) {
    if (s == null) return Colors.grey;
    switch (s) {
      case 'DRAFT': return const Color(0xFF94A3B8);
      case 'SUBMITTED': return const Color(0xFFF59E0B);
      case 'APPROVED': return const Color(0xFF059669);
      case 'REJECTED': return const Color(0xFFDC2626);
      case 'COMPLETED': return const Color(0xFF2563EB);
      default: return Colors.grey;
    }
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _submitForApproval() async {
    final so = _data?['stock_opname'];
    if (so == null) return;
    final approvers = (_data?['approvers'] as List?)?.map((a) => a['approver_id'] as int?).whereType<int>().toList() ?? [];
    if (approvers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal 1 approver'), backgroundColor: Colors.orange));
      return;
    }
    final result = await _service.submitForApproval(id: widget.opnameId, approvers: approvers);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil submit untuk approval'), backgroundColor: Color(0xFF059669)));
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showApproveDialog() async {
    String? comments;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('Approve / Reject'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih aksi:'),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Komentar (opsional)', border: OutlineInputBorder()),
                  maxLines: 2,
                  onChanged: (v) => comments = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'reject'),
                child: const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'approve'),
                child: const Text('Approve'),
              ),
            ],
          );
        },
      ),
    );
    if (action == null || !mounted) return;
    final result = await _service.approve(id: widget.opnameId, action: action, comments: comments);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? 'Berhasil di-approve' : 'Telah di-reject'), backgroundColor: const Color(0xFF059669)));
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _process() async {
    final result = await _service.process(widget.opnameId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock opname berhasil di-process'), backgroundColor: Color(0xFF059669)));
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Stock Opname'),
        content: const Text('Yakin ingin menghapus stock opname ini? Hanya bisa dihapus jika status DRAFT.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _service.delete(widget.opnameId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil dihapus'), backgroundColor: Color(0xFF059669)));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Stock Opname',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB)))
          : _data == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 16),
                        _buildInfoCard(),
                        const SizedBox(height: 16),
                        _buildApproversCard(),
                        const SizedBox(height: 16),
                        _buildItemsCard(),
                        const SizedBox(height: 24),
                        _buildActions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final so = _data!['stock_opname'] as Map<String, dynamic>? ?? {};
    final number = (so['opname_number'] ?? '-').toString();
    final status = so['status']?.toString();
    final date = so['opname_date']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(status ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _statusColor(status))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Tanggal Opname: ${_formatDate(date)}', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final so = _data!['stock_opname'] as Map<String, dynamic>? ?? {};
    final outlet = so['outlet'] as Map?;
    final warehouse = so['warehouse_outlet'] as Map?;
    final notes = so['notes']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          _row('Outlet', outlet?['nama_outlet']?.toString() ?? '-'),
          _row('Gudang', warehouse?['name']?.toString() ?? '-'),
          _row('Catatan', (notes != null && notes.isNotEmpty) ? notes : '-'),
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  Widget _buildApproversCard() {
    final approvers = (_data!['approvers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (approvers.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval Flow', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          ...approvers.map((a) {
            final level = a['approval_level'];
            final statusStr = a['status']?.toString() ?? '';
            final name = a['approver_name']?.toString() ?? '-';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('Level $level:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusStr == 'APPROVED' ? Colors.green.shade100 : statusStr == 'REJECTED' ? Colors.red.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusStr, style: TextStyle(fontSize: 11, color: statusStr == 'APPROVED' ? Colors.green.shade800 : statusStr == 'REJECTED' ? Colors.red.shade800 : Colors.orange.shade800)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final so = _data!['stock_opname'] as Map<String, dynamic>? ?? {};
    final items = (so['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Item Opname', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Tidak ada item', style: TextStyle(color: Color(0xFF64748B))))
          else
            ...items.asMap().entries.map((e) {
              final i = e.value;
              final inv = i['inventory_item'] as Map?;
              final item = inv?['item'] as Map?;
              final name = item?['name']?.toString() ?? '-';
              final sysS = _num(i['qty_system_small']);
              final physS = _num(i['qty_physical_small']);
              final diffS = _num(i['qty_diff_small']);
              final reason = i['reason']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('System: $sysS | Fisik: $physS | Selisih: $diffS', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    if (reason.isNotEmpty) Text('Alasan: $reason', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final so = _data!['stock_opname'] as Map<String, dynamic>? ?? {};
    final status = so['status']?.toString();
    final canApprove = _data!['can_approve'] == true;
    final itemCount = (so['items'] as List?)?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'DRAFT') ...[
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => StockOpnameFormScreen(editId: widget.opnameId)));
              if (result == true && mounted) _loadDetail();
            },
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text('Edit', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 8),
          if (itemCount > 0)
            ElevatedButton.icon(
              onPressed: _submitForApproval,
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Submit untuk Approval', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Hapus', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
        if (status == 'SUBMITTED' && canApprove) ...[
          ElevatedButton.icon(
            onPressed: _showApproveDialog,
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('Approve / Reject', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
        if (status == 'APPROVED') ...[
          ElevatedButton.icon(
            onPressed: _process,
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text('Process & Update Inventory', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ],
    );
  }
}
