import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_food_return_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletFoodReturnDetailScreen extends StatefulWidget {
  final int returnId;

  const OutletFoodReturnDetailScreen({super.key, required this.returnId});

  @override
  State<OutletFoodReturnDetailScreen> createState() => _OutletFoodReturnDetailScreenState();
}

class _OutletFoodReturnDetailScreenState extends State<OutletFoodReturnDetailScreen> {
  final OutletFoodReturnService _service = OutletFoodReturnService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _canDelete = false;
  bool _approving = false;
  bool _deleting = false;

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
        _data = result?['return'];
        _canDelete = result?['can_delete'] == true;
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
      if (result['success'] == true) _loadDetail();
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Return?'),
        content: Text('Yakin ingin menghapus return ${_data?['return_number'] ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    final result = await _service.delete(widget.returnId);
    if (mounted) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true ? (result['message']?.toString() ?? 'Berhasil dihapus') : (result['message']?.toString() ?? 'Gagal menghapus')),
          backgroundColor: result['success'] == true ? null : Colors.red,
        ),
      );
      if (result['success'] == true) Navigator.pop(context, true);
    }
  }

  static const _orange = Color(0xFFEA580C);

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _statusLabel(String? s) {
    if (s == null) return '-';
    if (s == 'pending') return 'Pending';
    if (s == 'approved') return 'Disetujui';
    return s;
  }

  Color _statusColor(String? s) {
    if (s == 'approved') return const Color(0xFF059669);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Outlet Food Return',
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
    final warehouseName = (t['warehouse_outlet_name'] ?? '-').toString();
    final status = t['status']?.toString();
    final createdByName = (t['created_by_name'] ?? '-').toString();
    final notes = t['notes']?.toString();
    final items = (t['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    final statusPending = status == 'pending';
    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(returnNumber, returnDate, status),
            if (statusPending || _canDelete) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (statusPending)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _approving ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _approving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(_approving ? 'Memproses...' : 'Approve'),
                      ),
                    ),
                  if (statusPending && _canDelete) const SizedBox(width: 12),
                  if (_canDelete)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleting ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_outline, size: 20),
                        label: Text(_deleting ? 'Menghapus...' : 'Hapus'),
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
              notes: notes,
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
    String? notes,
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
          _infoRow('Keterangan', (notes != null && notes.isNotEmpty) ? notes : '-'),
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
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
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
              final qtyStr = qty != null ? NumberFormat('#,##0.##', 'id_ID').format(qty is num ? qty : double.tryParse(qty.toString()) ?? 0) : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 20, backgroundColor: _orange.withOpacity(0.15), child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _orange))),
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
