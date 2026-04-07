import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_wip_models.dart';
import '../../services/outlet_wip_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'outlet_wip_create_screen.dart';

class OutletWIPDetailScreen extends StatefulWidget {
  final int headerId;

  const OutletWIPDetailScreen({super.key, required this.headerId});

  @override
  State<OutletWIPDetailScreen> createState() => _OutletWIPDetailScreenState();
}

class _OutletWIPDetailScreenState extends State<OutletWIPDetailScreen> {
  final OutletWIPService _service = OutletWIPService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getDetail(widget.headerId);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Data tidak ditemukan';
        });
        return;
      }
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _submit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Produksi'),
        content: const Text('Proses produksi WIP dan kurangi stok bahan baku?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _service.submit(widget.headerId);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produksi berhasil disubmit'), backgroundColor: Colors.green),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal submit'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produksi'),
        content: const Text('Yakin hapus data produksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _service.destroy(widget.headerId);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data dihapus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal hapus'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Produksi WIP',
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 16),
                        _buildProductionsCard(),
                        if (_data?['stock_cards'] != null && (_data!['stock_cards'] as List).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildStockCardsCard(),
                        ],
                        const SizedBox(height: 16),
                        _buildActions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final header = _data!['header'] as Map<String, dynamic>? ?? {};
    final number = header['number']?.toString() ?? '-';
    final status = header['status']?.toString() ?? 'PROCESSED';
    final date = _formatDate(header['production_date']?.toString());
    final batch = header['batch_number']?.toString() ?? '-';
    final notes = header['notes']?.toString() ?? '-';
    final outlet = _data!['outlet'] as Map<String, dynamic>?;
    final warehouse = _data!['warehouse_outlet'] as Map<String, dynamic>?;
    final outletName = outlet?['nama_outlet']?.toString() ?? '-';
    final warehouseName = warehouse?['name']?.toString() ?? '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    number,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const Divider(height: 20),
            _row('Tanggal', date),
            _row('Batch', batch),
            _row('Outlet', outletName),
            _row('Gudang', warehouseName),
            if (notes.isNotEmpty) _row('Catatan', notes),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionsCard() {
    final productions = _data!['productions'] as List<dynamic>? ?? [];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Produksi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...productions.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              final name = m['item_name']?.toString() ?? '-';
              final qty = m['qty']?.toString() ?? '0';
              final qtyJadi = m['qty_jadi']?.toString() ?? '0';
              final unit = m['unit_name']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '$qty → $qtyJadi $unit',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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

  Widget _buildStockCardsCard() {
    final cards = _data!['stock_cards'] as List<dynamic>? ?? [];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kartu Stok',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...cards.take(20).map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              final itemName = m['item_name']?.toString() ?? '-';
              final unitName = m['unit_name']?.toString() ?? '';
              final inSmall = (m['in_qty_small'] is num) ? (m['in_qty_small'] as num).toDouble() : double.tryParse(m['in_qty_small']?.toString() ?? '') ?? 0.0;
              final outSmall = (m['out_qty_small'] is num) ? (m['out_qty_small'] as num).toDouble() : double.tryParse(m['out_qty_small']?.toString() ?? '') ?? 0.0;
              final String typeLabel = outSmall > 0 ? 'Keluar' : (inSmall > 0 ? 'Masuk' : '-');
              final double qtyVal = outSmall > 0 ? outSmall : inSmall;
              final String qtyStr = qtyVal == qtyVal.roundToDouble() ? qtyVal.toInt().toString() : qtyVal.toStringAsFixed(2);
              final String qtyWithUnit = unitName.isEmpty ? '$typeLabel $qtyStr' : '$typeLabel $qtyStr $unitName';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        itemName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      qtyWithUnit,
                      style: TextStyle(
                        fontSize: 13,
                        color: outSmall > 0 ? Colors.red.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (cards.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${cards.length - 20} entri lainnya',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    final header = _data!['header'] as Map<String, dynamic>? ?? {};
    final status = header['status']?.toString() ?? '';

    if (status != 'DRAFT') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _editDraft,
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('Edit / Tambah Inputan'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFF6366F1)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Produksi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hapus'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editDraft() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletWIPCreateScreen(draftHeaderId: widget.headerId),
      ),
    );
    if (result == true && mounted) _load();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final isDraft = status.toUpperCase() == 'DRAFT';
    final bg = isDraft ? const Color(0xFFFEF9C3) : const Color(0xFFDCFCE7);
    final fg = isDraft ? const Color(0xFF92400E) : const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }
}
