import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/retail_warehouse_food_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailWarehouseFoodDetailScreen extends StatefulWidget {
  final int id;

  const RetailWarehouseFoodDetailScreen({super.key, required this.id});

  @override
  State<RetailWarehouseFoodDetailScreen> createState() =>
      _RetailWarehouseFoodDetailScreenState();
}

class _RetailWarehouseFoodDetailScreenState extends State<RetailWarehouseFoodDetailScreen> {
  final RetailWarehouseFoodService _service = RetailWarehouseFoodService();
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final Map<int, int> _serialCountByItemId = {};
  final Map<int, int> _serialInUseByItemId = {};

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
    final result = await _service.getDetail(widget.id);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data';
      });
      return;
    }
    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Data tidak ditemukan';
      });
      return;
    }
    final raw = result['data'];
    if (raw == null) {
      setState(() {
        _loading = false;
        _error = 'Data tidak ditemukan';
      });
      return;
    }
    final data = Map<String, dynamic>.from(raw);
    final itemsRaw = data['items'];
    final List<Map<String, dynamic>> items = itemsRaw is List
        ? itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    setState(() {
      _data = data;
      _items = items;
      _loading = false;
      _error = null;
    });
    await _refreshSerialSummary();
  }

  Future<void> _refreshSerialSummary() async {
    final rows = await _service.getSerialSummaryForRwf(widget.id);
    if (!mounted) return;
    final map = <int, int>{};
    final inUse = <int, int>{};
    for (final r in rows) {
      final id = int.tryParse(r['retail_warehouse_food_item_id']?.toString() ?? '');
      final t = int.tryParse(r['total']?.toString() ?? '0') ?? 0;
      final u = int.tryParse(r['in_use']?.toString() ?? '0') ?? 0;
      if (id != null) {
        map[id] = t;
        inUse[id] = u;
      }
    }
    setState(() {
      _serialCountByItemId
        ..clear()
        ..addAll(map);
      _serialInUseByItemId
        ..clear()
        ..addAll(inUse);
    });
  }

  int _serialCountFor(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return 0;
    return _serialCountByItemId[id] ?? 0;
  }

  int _serialInUseFor(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return 0;
    return _serialInUseByItemId[id] ?? 0;
  }

  Future<void> _generateSerialForItem(Map<String, dynamic> item) async {
    final itemId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
    if (itemId == 0) return;
    final data = await _service.getSerialUnitsForRwfItem(itemId);
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat unit serial'), backgroundColor: Colors.red),
      );
      return;
    }
    final units = (data['units'] as List<dynamic>?) ?? [];
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit konversi item tidak ditemukan.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final name = item['item_name']?.toString() ?? '-';
    final qtyLabel = '${data['qty_received']} ${data['received_unit_name'] ?? ''}';

    int? selectedUnitId = int.tryParse(units.first['unit_id']?.toString() ?? '');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Generate Serial — $name'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Qty: $qtyLabel', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(selectedUnitId),
                  initialValue: selectedUnitId,
                  decoration: const InputDecoration(labelText: 'Unit serial', border: OutlineInputBorder()),
                  items: units.map((u) {
                    final id = int.tryParse(u['unit_id']?.toString() ?? '') ?? 0;
                    final uname = u['unit_name']?.toString() ?? '';
                    final cq = u['converted_qty'];
                    return DropdownMenuItem(
                      value: id,
                      child: Text('$uname (qty: $cq)'),
                    );
                  }).toList(),
                  onChanged: (v) => setLocal(() => selectedUnitId = v),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, selectedUnitId), child: const Text('Generate')),
        ],
      ),
    );
    if (picked == null || picked == 0) return;

    final res = await _service.generateSerialsForRwfItem(itemId, unitId: picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'OK' : 'Gagal')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    await _refreshSerialSummary();
  }

  Future<void> _showSerialsForItem(Map<String, dynamic> item) async {
    final itemId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
    if (itemId == 0) return;
    final name = item['item_name']?.toString() ?? '-';
    final rows = await _service.getSerialsForRwfItem(itemId);
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada serial untuk item ini.'), backgroundColor: Colors.orange),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Serial — $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: rows.length > 200 ? 200 : rows.length,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  return ListTile(
                    dense: true,
                    title: Text(r['serial_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${r['unit_name'] ?? '-'} · RWF ${r['gr_number'] ?? '-'}',
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

  Future<void> _rollbackSerialForItem(Map<String, dynamic> item) async {
    final itemId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
    if (itemId == 0) return;
    final name = item['item_name']?.toString() ?? '-';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rollback serial?'),
        content: Text('Hapus semua serial untuk "$name" pada transaksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rollback', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _service.rollbackSerialsForRwfItem(itemId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Rollback berhasil' : 'Gagal')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    await _refreshSerialSummary();
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  String _paymentMethodLabel(String? v) {
    if (v == null || v.isEmpty) return '-';
    if (v == 'cash') return 'Cash';
    if (v == 'contra_bon') return 'Contra Bon';
    return v;
  }

  String _warehouseName(Map<String, dynamic>? data) {
    if (data == null) return '-';
    final w = data['warehouse'];
    if (w is Map) return w['name']?.toString() ?? '-';
    return data['warehouse_name']?.toString() ?? '-';
  }

  String _divisionName(Map<String, dynamic>? data) {
    if (data == null) return '-';
    final wd = data['warehouse_division'];
    if (wd is Map) return wd['name']?.toString() ?? '-';
    return data['warehouse_division_name']?.toString() ?? '-';
  }

  String _supplierName(Map<String, dynamic>? data) {
    if (data == null) return '-';
    final s = data['supplier'];
    if (s is Map) return s['name']?.toString() ?? '-';
    return data['supplier_name']?.toString() ?? '-';
  }

  String _creatorName(Map<String, dynamic>? data) {
    if (data == null) return '-';
    final c = data['creator'];
    if (c is Map) return c['nama_lengkap']?.toString() ?? c['name']?.toString() ?? '-';
    return data['created_by_name']?.toString() ?? '-';
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppScaffold(
        title: 'Detail Warehouse Retail Food',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB))),
      );
    }
    if (_error != null || _data == null) {
      return AppScaffold(
        title: 'Detail Warehouse Retail Food',
        showDrawer: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(_error ?? 'Data tidak ditemukan',
                    style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final d = _data!;
    final retailNumber = d['retail_number']?.toString() ?? '-';
    final paymentMethod = d['payment_method']?.toString();

    return AppScaffold(
      title: 'Detail Warehouse Retail Food',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Informasi Transaksi',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retailNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Tanggal', _formatDate(d['transaction_date']?.toString() ?? d['created_at']?.toString())),
                  _buildInfoRow('Metode Pembayaran', _paymentMethodLabel(paymentMethod)),
                  _buildInfoRow('Total', _formatMoney(d['total_amount'])),
                  if (d['notes'] != null && d['notes'].toString().isNotEmpty)
                    _buildInfoRow('Catatan', d['notes'].toString()),
                ],
              ),
            ),
            _buildSection(
              'Gudang',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Gudang', _warehouseName(d)),
                  _buildInfoRow('Divisi', _divisionName(d)),
                ],
              ),
            ),
            _buildSection(
              'Supplier',
              _buildInfoRow('Nama', _supplierName(d)),
            ),
            _buildSection(
              'Dibuat oleh',
              _buildInfoRow('User', _creatorName(d)),
            ),
            _buildSection(
              'Detail Item',
              _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Tidak ada item', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : Column(
                      children: _items.map((item) {
                        final name = item['item_name']?.toString() ?? '-';
                        final qty = item['qty'];
                        final unit = item['unit']?.toString() ?? '';
                        final price = item['price'];
                        final subtotal = item['subtotal'];
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                                fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$qty $unit x ${_formatMoney(price)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatMoney(subtotal),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _generateSerialForItem(item),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1D4ED8),
                                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Generate serial', style: TextStyle(fontSize: 12)),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _showSerialsForItem(item),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF334155),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text('Lihat (${_serialCountFor(item)})', style: const TextStyle(fontSize: 12)),
                                  ),
                                  OutlinedButton(
                                    onPressed: _serialInUseFor(item) > 0 ? null : () => _rollbackSerialForItem(item),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFB91C1C),
                                      side: const BorderSide(color: Color(0xFFFECACA)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Rollback', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
