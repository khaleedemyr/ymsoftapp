import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_serial_receive_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletSerialReceiveDetailScreen extends StatefulWidget {
  final int headerId;

  const OutletSerialReceiveDetailScreen({super.key, required this.headerId});

  @override
  State<OutletSerialReceiveDetailScreen> createState() => _OutletSerialReceiveDetailScreenState();
}

class _OutletSerialReceiveDetailScreenState extends State<OutletSerialReceiveDetailScreen> {
  final OutletSerialReceiveService _service = OutletSerialReceiveService();

  Map<String, dynamic>? _header;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final res = await _service.getDetail(widget.headerId);
    if (res != null && mounted) {
      setState(() {
        _header = res['header'] != null ? Map<String, dynamic>.from(res['header']) : null;
        _items = res['items'] is List
            ? (res['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _canDelete = res['can_delete'] == true;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus GR Serial?'),
        content: Text('GR ${_header?['number']} akan dihapus dan inventory di-rollback.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await _service.delete(widget.headerId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res?['message'] ?? 'Gagal menghapus'),
          backgroundColor: res?['success'] == true ? Colors.green : Colors.red,
        ),
      );
      if (res?['success'] == true) Navigator.pop(context, true);
    }
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      return DateFormat('dd MMMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _fmtRupiah(dynamic val) {
    if (val == null) return '-';
    final n = double.tryParse(val.toString()) ?? 0;
    if (n == 0) return '-';
    return 'Rp ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _fmtQty(dynamic val) {
    if (val == null) return '-';
    final n = double.tryParse(val.toString()) ?? 0;
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  String _fmtCostSource(String? src) {
    if (src == null) return '-';
    if (src == 'fgr_modal_12pct') return 'FGR (Modal+12%)';
    if (src == 'item_prices') return 'Item Price';
    return src;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail GR Serial',
      showDrawer: false,
      actions: [
        if (_canDelete && _header != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Hapus',
            onPressed: _onDelete,
          ),
      ],
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF4F46E5)))
          : _header == null
              ? const Center(child: Text('Data tidak ditemukan.'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildItemsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 24, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _header?['number'] ?? '-',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtDate(_header?['receive_date']),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_items.length} serial',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.store_rounded, 'Outlet', _header?['outlet_name'] ?? _header?['outlet_id'] ?? '-'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.person_rounded, 'Dibuat oleh', _header?['created_by_name'] ?? '-'),
          if (_header?['notes'] != null && _header!['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(Icons.notes_rounded, 'Catatan', _header!['notes']),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Text('Daftar Serial', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          ),
          const Divider(height: 1),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Tidak ada item.', style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) => _buildItemTile(_items[index], index),
            ),
          _buildTotalRow(),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item_name'] ?? '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item['serial_number'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_fmtQty(item['qty'])} ${item['unit_name'] ?? ''}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('DO: ${item['delivery_order_number'] ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 10),
                    Text(_fmtRupiah(item['cost_small']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${item['outlet_name'] ?? item['outlet_id'] ?? ''}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: item['cost_source'] == 'fgr_modal_12pct' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _fmtCostSource(item['cost_source']),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: item['cost_source'] == 'fgr_modal_12pct' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    double totalQty = 0;
    double totalCost = 0;
    for (final item in _items) {
      final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
      final cost = double.tryParse(item['cost_small']?.toString() ?? '0') ?? 0;
      totalQty += qty;
      totalCost += qty * cost;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
      ),
      child: Row(
        children: [
          const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const Spacer(),
          Text(_fmtQty(totalQty), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(width: 20),
          Text(_fmtRupiah(totalCost), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
