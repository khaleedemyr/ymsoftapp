import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mk_production_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

/// Selaras web `MKProduction/Show.vue` — detail + generate / daftar / rollback serial.
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
  int _serialTotal = 0;
  int _serialInUse = 0;
  bool _serialBusy = false;

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
    await _refreshSerialTotal();
  }

  Future<void> _refreshSerialTotal() async {
    final c = await _service.getSerialSummaryCounts(widget.id);
    if (!mounted) return;
    setState(() {
      _serialTotal = c['total'] ?? 0;
      _serialInUse = c['in_use'] ?? 0;
    });
  }

  String _formatQty(dynamic value) {
    final n = double.tryParse((value ?? '').toString()) ?? 0;
    if (n == n.truncateToDouble()) {
      return NumberFormat.decimalPattern('id_ID').format(n.toInt());
    }
    return NumberFormat.decimalPattern('id_ID').format(n);
  }

  String _formatDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return '-';
    try {
      return DateFormat.yMMMd('id_ID').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _onGenerateSerial() async {
    final prod = (_data?['prod'] as Map<String, dynamic>?) ?? {};
    final item = (_data?['item'] as Map<String, dynamic>?) ?? {};
    final qtyJadi = double.tryParse(prod['qty_jadi']?.toString() ?? '') ?? 0;
    final unitName = _unitNameForProd(prod, item);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate serial MK Production?'),
        content: Text(
          'Generate berdasarkan Qty Jadi ${_formatQty(qtyJadi)} ${unitName.isNotEmpty ? unitName : ''}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, generate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _serialBusy = true);
    final res = await _service.generateSerials(widget.id);
    if (!mounted) return;
    setState(() => _serialBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    await _refreshSerialTotal();
    await _load();
  }

  Future<void> _onShowSerials() async {
    setState(() => _serialBusy = true);
    final rows = await _service.getSerialList(widget.id);
    if (!mounted) return;
    setState(() => _serialBusy = false);

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada serial MK Production.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final item = (_data?['item'] as Map<String, dynamic>?) ?? {};
    final prod = (_data?['prod'] as Map<String, dynamic>?) ?? {};
    final title = item['name']?.toString() ?? 'Serial';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Batch: ${prod['batch_number'] ?? '-'} · ${_formatDate(prod['production_date'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: rows.length > 200 ? 200 : rows.length,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  return ListTile(
                    dense: true,
                    leading: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade600)),
                    title: Text(r['serial_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${r['unit_name'] ?? '-'} · ${r['generated_at'] ?? '-'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRollbackSerial() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rollback serial MK Production?'),
        content: const Text('Semua serial untuk produksi ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, rollback', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _serialBusy = true);
    final res = await _service.rollbackSerials(widget.id);
    if (!mounted) return;
    setState(() => _serialBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Rollback berhasil' : 'Gagal')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    await _refreshSerialTotal();
  }

  String _unitNameForProd(Map<String, dynamic> prod, Map<String, dynamic> item) {
    final uid = prod['unit_id'];
    if (uid == null) return '';
    final u = int.tryParse(uid.toString());
    if (u == null) return '';
    final su = int.tryParse(item['small_unit_id']?.toString() ?? '');
    final mu = int.tryParse(item['medium_unit_id']?.toString() ?? '');
    final lu = int.tryParse(item['large_unit_id']?.toString() ?? '');
    if (su != null && u == su) return item['small_unit_name']?.toString() ?? '';
    if (mu != null && u == mu) return item['medium_unit_name']?.toString() ?? '';
    if (lu != null && u == lu) return item['large_unit_name']?.toString() ?? '';
    return '';
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
      title: 'MK Production Detail',
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 30, color: Color(0xFF6366F1)))
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                              onPressed: (_serialBusy || _serialInUse > 0) ? null : _onGenerateSerial,
                              icon: const Icon(Icons.qr_code_2, size: 18),
                              label: const Text('Generate Serial'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF475569)),
                              onPressed: _serialBusy ? null : _onShowSerials,
                              icon: const Icon(Icons.list_alt, size: 18),
                              label: Text('Serial List ($_serialTotal)'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                              onPressed: (_serialBusy || _serialTotal <= 0 || _serialInUse > 0) ? null : _onRollbackSerial,
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('Rollback Serial'),
                            ),
                          ],
                        ),
                        if (_serialInUse > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Generate/rollback serial dinonaktifkan: ada serial yang sudah digunakan.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _metricRow(prod, item, warehouse),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Detail Information',
                          icon: Icons.info_outline,
                          child: Column(
                            children: [
                              _row('Item', item['name']?.toString() ?? '-'),
                              _row('Warehouse', warehouse['name']?.toString() ?? '-'),
                              _row('Catatan', prod['notes']?.toString().isNotEmpty == true ? prod['notes'].toString() : '-'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Stock Card',
                          icon: Icons.receipt_long_outlined,
                          child: stockCard.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Tidak ada data stock card'),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFF4F46E5).withValues(alpha: 0.12)),
                                    columns: const [
                                      DataColumn(label: Text('Tanggal')),
                                      DataColumn(label: Text('In Qty'), numeric: true),
                                      DataColumn(label: Text('Out Qty'), numeric: true),
                                      DataColumn(label: Text('Saldo Qty'), numeric: true),
                                      DataColumn(label: Text('Deskripsi')),
                                    ],
                                    rows: stockCard.map((e) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(_formatDate(e['date']))),
                                          DataCell(Text(_formatQty(e['in_qty_small']))),
                                          DataCell(Text(_formatQty(e['out_qty_small']))),
                                          DataCell(Text(_formatQty(e['saldo_qty_small']))),
                                          DataCell(
                                            SizedBox(
                                              width: 200,
                                              child: Text(
                                                e['description']?.toString() ?? '-',
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'BOM (Bill of Materials)',
                          icon: Icons.inventory_2_outlined,
                          child: bom.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Tidak ada data'),
                                )
                              : Column(
                                  children: bom.map((e) {
                                    final qty = _formatQty(e['qty']);
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(e['material_name']?.toString() ?? '-'),
                                      trailing: Text('$qty ${e['unit_name'] ?? ''}', textAlign: TextAlign.right),
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus Produksi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_serialBusy)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _metricRow(Map<String, dynamic> prod, Map<String, dynamic> item, Map<String, dynamic> warehouse) {
    return Row(
      children: [
        Expanded(child: _metricTile('Production Date', _formatDate(prod['production_date']), Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Batch', prod['batch_number']?.toString() ?? '-', Colors.purple)),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Qty Produksi', _formatQty(prod['qty']), Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Qty Jadi', _formatQty(prod['qty_jadi']), Colors.orange)),
      ],
    );
  }

  Widget _metricTile(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.12), accent.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: accent.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
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
            width: 100,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
