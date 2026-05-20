import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/good_receive_service.dart';
import '../../models/good_receive_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/date_format_util.dart';

class GoodReceiveDetailScreen extends StatefulWidget {
  final int goodReceiveId;

  const GoodReceiveDetailScreen({super.key, required this.goodReceiveId});

  @override
  State<GoodReceiveDetailScreen> createState() => _GoodReceiveDetailScreenState();
}

class _GoodReceiveDetailScreenState extends State<GoodReceiveDetailScreen> {
  final GoodReceiveService _service = GoodReceiveService();
  
  FoodGoodReceive? _goodReceive;
  bool _isLoading = true;
  bool _isDeleting = false;
  final Map<int, int> _serialCountByItemId = {};
  final Map<int, int> _serialInUseByItemId = {};

  @override
  void initState() {
    super.initState();
    _loadGoodReceive();
  }

  Future<void> _loadGoodReceive() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.getGoodReceive(widget.goodReceiveId);
      
      if (result != null && mounted) {
        setState(() {
          _goodReceive = FoodGoodReceive.fromJson(result);
          _isLoading = false;
        });
        await _refreshSerialSummary();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load Good Receive details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGoodReceive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus Good Receive ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        final result = await _service.deleteGoodReceive(widget.goodReceiveId);
        
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });

          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Good Receive berhasil dihapus'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Gagal menghapus Good Receive'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Good Receive',
      actions: [
        if (!_isLoading && _goodReceive != null)
          IconButton(
            tooltip: 'Hapus Good Receive',
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _deleteGoodReceive,
          ),
      ],
      body: _isLoading
          ? const AppLoadingIndicator()
          : _goodReceive == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Good Receive tidak ditemukan'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kembali'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 16),
                          _buildItemsCard(),
                          const SizedBox(height: 80), // Space for FAB
                        ],
                      ),
                    ),
                    if (_isDeleting)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Informasi Good Receive',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('GR Number', _goodReceive!.grNumber, Icons.receipt_long),
            _buildInfoRow('Tanggal Terima', formatApiDate(_goodReceive!.receiveDate, pattern: 'dd MMMM yyyy'), Icons.calendar_today),
            if (_goodReceive!.poNumber != null)
              _buildInfoRow('PO Number', _goodReceive!.poNumber!, Icons.shopping_cart),
            _buildInfoRow('Supplier', _goodReceive!.supplierName, Icons.business),
            if (_goodReceive!.receivedByName != null)
              _buildInfoRow('Diterima Oleh', _goodReceive!.receivedByName!, Icons.person),
            if (_goodReceive!.notes != null && _goodReceive!.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Catatan:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _goodReceive!.notes!,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Detail Item & Serial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            ...List.generate(_goodReceive!.items.length, (index) {
              final item = _goodReceive!.items[index];
              return _buildItemTile(item, index);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshSerialSummary() async {
    if (_goodReceive == null) return;
    final rows = await _service.getSerialSummaryForGr(_goodReceive!.id);
    if (!mounted) return;
    final map = <int, int>{};
    final inUse = <int, int>{};
    for (final r in rows) {
      final id = int.tryParse(r['good_receive_item_id']?.toString() ?? '');
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

  int _serialCountFor(FoodGoodReceiveItem item) => _serialCountByItemId[item.id] ?? 0;

  int _serialInUseFor(FoodGoodReceiveItem item) => _serialInUseByItemId[item.id] ?? 0;

  Future<void> _generateSerialForItem(FoodGoodReceiveItem item) async {
    final data = await _service.getSerialUnitsForGrItem(item.id);
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat unit serial'), backgroundColor: Colors.red));
      return;
    }
    final units = (data['units'] as List<dynamic>?) ?? [];
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit konversi item tidak ditemukan.'), backgroundColor: Colors.orange));
      return;
    }
    final qtyLabel = '${data['qty_received']} ${data['received_unit_name'] ?? ''}';

    int? selectedUnitId = int.tryParse(units.first['unit_id']?.toString() ?? '');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Generate Serial — ${item.itemName}'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Qty diterima: $qtyLabel', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(selectedUnitId),
                  initialValue: selectedUnitId,
                  decoration: const InputDecoration(labelText: 'Unit serial', border: OutlineInputBorder()),
                  items: units.map((u) {
                    final id = int.tryParse(u['unit_id']?.toString() ?? '') ?? 0;
                    final name = u['unit_name']?.toString() ?? '';
                    final cq = u['converted_qty'];
                    return DropdownMenuItem(
                      value: id,
                      child: Text('$name (qty: $cq)'),
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

    final res = await _service.generateSerialsForGrItem(item.id, unitId: picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'OK' : 'Gagal')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    await _refreshSerialSummary();
  }

  Future<void> _showSerialsForItem(FoodGoodReceiveItem item) async {
    final rows = await _service.getSerialsForGrItem(item.id);
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belum ada serial untuk item ini.'), backgroundColor: Colors.orange));
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
              child: Text('Serial — ${item.itemName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      '${r['unit_name'] ?? '-'} · PO ${r['po_number'] ?? '-'} · GR ${r['gr_number'] ?? '-'}',
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

  Future<void> _rollbackSerialForItem(FoodGoodReceiveItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rollback serial?'),
        content: Text('Hapus semua serial untuk "${item.itemName}" pada GR ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rollback', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _service.rollbackSerialsForGrItem(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Rollback berhasil' : 'Gagal')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    await _refreshSerialSummary();
  }

  Widget _buildItemTile(FoodGoodReceiveItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.itemName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildItemInfo('Qty Ordered', '${NumberFormat('#,##0.##').format(item.qtyOrdered)} ${item.unitName}'),
              _buildItemInfo('Qty Received', '${NumberFormat('#,##0.##').format(item.qtyReceived)} ${item.unitName}'),
            ],
          ),
          if (item.warehouseDivisionName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  item.warehouseDivisionName!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.notes!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text('Serial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: () => _generateSerialForItem(item),
                child: const Text('Generate Serial'),
              ),
              OutlinedButton(
                onPressed: () => _showSerialsForItem(item),
                child: Text('Lihat Serial (${_serialCountFor(item)})'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: (_serialCountFor(item) <= 0 || _serialInUseFor(item) > 0)
                    ? null
                    : () => _rollbackSerialForItem(item),
                child: const Text('Rollback Serial'),
              ),
            ],
          ),
          if (_serialInUseFor(item) > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Rollback dinonaktifkan: ada serial yang sudah digunakan.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
