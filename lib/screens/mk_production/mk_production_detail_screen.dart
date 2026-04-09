import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mk_production_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class MKProductionDetailScreen extends StatefulWidget {
  final int id;
  const MKProductionDetailScreen({super.key, required this.id});

  @override
  State<MKProductionDetailScreen> createState() => _MKProductionDetailScreenState();
}

class _MKProductionDetailScreenState extends State<MKProductionDetailScreen> {
  final MKProductionService _service = MKProductionService();
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _service.getDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produksi'),
        content: const Text('Data dan stok akan di-rollback. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _service.destroy(widget.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text((res['success'] == true) ? 'Berhasil dihapus' : (res['message']?.toString() ?? 'Gagal hapus')),
        backgroundColor: (res['success'] == true) ? Colors.green : Colors.red,
      ),
    );
    if (res['success'] == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prod = (_data?['prod'] as Map<String, dynamic>?) ?? {};
    final item = (_data?['item'] as Map<String, dynamic>?) ?? {};
    final warehouse = (_data?['warehouse'] as Map<String, dynamic>?) ?? {};
    final stockCard = (_data?['stock_card'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final bom = (_data?['bom'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return AppScaffold(
      title: 'Detail MK Production',
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 30, color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _sectionCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.factory, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Informasi Produksi',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _statusChip('PROCESSED'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _row('Tanggal', prod['production_date']?.toString() ?? '-'),
                            _row('Batch', prod['batch_number']?.toString() ?? '-'),
                            _row('Item', item['name']?.toString() ?? '-'),
                            _row('Warehouse', warehouse['name']?.toString() ?? '-'),
                            _row('Qty', _formatQty(prod['qty'])),
                            _row('Qty Jadi', _formatQty(prod['qty_jadi'])),
                            _row('Catatan', prod['notes']?.toString() ?? '-'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, color: Color(0xFF6366F1)),
                                SizedBox(width: 8),
                                Text('Stock Card', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (stockCard.isEmpty) const Text('Tidak ada data') else ...stockCard.map((e) {
                              final inQty = _formatQty(e['in_qty_small']);
                              final outQty = _formatQty(e['out_qty_small']);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(e['date']?.toString() ?? '-'),
                                subtitle: Text(e['description']?.toString() ?? '-'),
                                trailing: SizedBox(
                                  width: 92,
                                  child: Text(
                                    'In $inQty\nOut $outQty',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, color: Color(0xFF6366F1)),
                                SizedBox(width: 8),
                                Text('BOM', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (bom.isEmpty) const Text('Tidak ada data') else ...bom.map((e) {
                              final qty = _formatQty(e['qty']);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(e['material_name']?.toString() ?? '-'),
                                trailing: SizedBox(
                                  width: 96,
                                  child: Text(
                                    '$qty ${e['unit_name'] ?? ''}',
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus Produksi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
      ),
    );
  }

  String _formatQty(dynamic value) {
    final n = double.tryParse((value ?? '').toString()) ?? 0;
    return NumberFormat('#,##0.##').format(n);
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
