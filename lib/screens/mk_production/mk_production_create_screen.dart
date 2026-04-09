import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mk_production_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class MKProductionCreateScreen extends StatefulWidget {
  const MKProductionCreateScreen({super.key});

  @override
  State<MKProductionCreateScreen> createState() => _MKProductionCreateScreenState();
}

class _MKProductionCreateScreenState extends State<MKProductionCreateScreen> {
  final MKProductionService _service = MKProductionService();
  final TextEditingController _dateC = TextEditingController();
  final TextEditingController _batchC = TextEditingController();
  final TextEditingController _qtyC = TextEditingController(text: '0');
  final TextEditingController _qtyJadiC = TextEditingController(text: '0');
  final TextEditingController _notesC = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _warehouses = [];
  Set<int> _itemsWithBom = {};
  int? _itemId;
  int? _warehouseId;
  int? _unitId;
  List<Map<String, dynamic>> _bom = [];
  String? _bomError;

  @override
  void initState() {
    super.initState();
    _dateC.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _load();
  }

  String get _selectedItemName {
    if (_itemId == null) return 'Item Hasil Produksi';
    final selected = _items.cast<Map<String, dynamic>?>().firstWhere(
          (e) => int.tryParse((e?['id'] ?? '').toString()) == _itemId,
          orElse: () => null,
        );
    return selected?['name']?.toString() ?? 'Item Hasil Produksi';
  }

  Future<void> _openItemSearch() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(_items);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.65,
                minChildSize: 0.35,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari item hasil produksi...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onChanged: (v) {
                          final q = v.trim().toLowerCase();
                          setModalState(() {
                            filtered = q.isEmpty
                                ? List<Map<String, dynamic>>.from(_items)
                                : _items.where((e) => (e['name'] ?? '').toString().toLowerCase().contains(q)).toList();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final id = int.tryParse((item['id'] ?? '').toString());
                          return ListTile(
                            title: Text(item['name']?.toString() ?? '-'),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() {
                                _itemId = id;
                                _unitId = null;
                              });
                              _loadBom();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        searchController.dispose();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _dateC.dispose();
    _batchC.dispose();
    _qtyC.dispose();
    _qtyJadiC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _service.getCreateData();
    if (!mounted) return;
    final items = (data?['items'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final wh = (data?['warehouses'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final withBom = (data?['items_with_bom'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse((Map<String, dynamic>.from(e as Map))['id'].toString()) ?? 0)
        .where((e) => e > 0)
        .toSet();
    setState(() {
      _items = items;
      _warehouses = wh;
      _itemsWithBom = withBom;
      _loading = false;
    });
  }

  Map<String, dynamic>? get _selectedItem {
    if (_itemId == null) return null;
    for (final i in _items) {
      if (int.tryParse((i['id'] ?? '').toString()) == _itemId) return i;
    }
    return null;
  }

  List<Map<String, dynamic>> get _units {
    final item = _selectedItem;
    if (item == null) return [];
    final units = <Map<String, dynamic>>[];
    void addUnit(dynamic id, dynamic name) {
      final uid = int.tryParse((id ?? '').toString());
      final uname = (name ?? '').toString();
      if (uid != null && uid > 0 && uname.isNotEmpty && !units.any((e) => e['id'] == uid)) {
        units.add({'id': uid, 'name': uname});
      }
    }
    addUnit(item['small_unit_id'], item['small_unit_name']);
    addUnit(item['medium_unit_id'], item['medium_unit_name']);
    addUnit(item['large_unit_id'], item['large_unit_name']);
    return units;
  }

  Future<void> _loadBom() async {
    final qty = double.tryParse(_qtyC.text) ?? 0;
    if (_itemId == null || _warehouseId == null || qty <= 0) {
      setState(() {
        _bom = [];
        _bomError = null;
      });
      return;
    }
    final result = await _service.getBomAndStock(itemId: _itemId!, qty: qty, warehouseId: _warehouseId!);
    if (!mounted) return;
    if (result is List) {
      setState(() {
        _bom = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _bomError = null;
      });
      return;
    }
    if (result is Map && result['error'] != null) {
      setState(() {
        _bom = [];
        _bomError = result['error'].toString();
      });
      return;
    }
    setState(() {
      _bom = [];
      _bomError = null;
    });
  }

  bool get _stockInsufficient {
    for (final b in _bom) {
      final sisa = double.tryParse((b['sisa'] ?? '0').toString()) ?? 0;
      if (sisa < 0) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyC.text) ?? 0;
    final qtyJadi = double.tryParse(_qtyJadiC.text) ?? 0;
    if (_warehouseId == null || _itemId == null || _unitId == null || qty <= 0 || qtyJadi <= 0 || _dateC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi data produksi')));
      return;
    }
    if (_stockInsufficient) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok bahan baku tidak cukup')));
      return;
    }
    setState(() => _saving = true);
    final res = await _service.store(
      warehouseId: _warehouseId!,
      productionDate: _dateC.text,
      batchNumber: _batchC.text.trim(),
      itemId: _itemId!,
      qty: qty,
      qtyJadi: qtyJadi,
      unitId: _unitId!,
      notes: _notesC.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produksi berhasil disimpan'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal simpan'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat MK Production',
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 30, color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.factory, color: Color(0xFF6366F1)),
                      SizedBox(width: 8),
                      Text(
                        'Form Produksi Baru',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFormCard(),
                  const SizedBox(height: 12),
                  if (_bomError != null)
                    Card(
                      color: const Color(0xFFFEF2F2),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_bomError!, style: const TextStyle(color: Color(0xFF991B1B))),
                      ),
                    ),
                  if (_bom.isNotEmpty) _buildBomCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Simpan Produksi'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text('Input Produksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _warehouseId,
              decoration: _inputDecoration('Warehouse'),
              items: _warehouses
                  .map(
                    (e) => DropdownMenuItem<int>(
                      value: int.tryParse((e['id'] ?? '').toString()),
                      child: Text(e['name']?.toString() ?? '-'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _warehouseId = v);
                _loadBom();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dateC,
              readOnly: true,
              decoration: _inputDecoration('Tanggal Produksi').copyWith(
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_dateC.text) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dateC.text = DateFormat('yyyy-MM-dd').format(d));
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: _batchC, decoration: _inputDecoration('Batch Number')),
            const SizedBox(height: 8),
            InkWell(
              onTap: _openItemSearch,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration('Item Hasil Produksi').copyWith(
                  suffixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                ),
                child: Text(
                  _selectedItemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (_itemId != null && !_itemsWithBom.contains(_itemId))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Item ini belum memiliki BOM.', style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                if (compact) {
                  return Column(
                    children: [
                      TextField(
                        controller: _qtyC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('Qty Produksi'),
                        onChanged: (_) => _loadBom(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _qtyJadiC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('Qty Jadi'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('Qty Produksi'),
                        onChanged: (_) => _loadBom(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _qtyJadiC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('Qty Jadi'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _unitId,
              decoration: _inputDecoration('Unit Qty Jadi'),
              items: _units
                  .map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name']?.toString() ?? '-')))
                  .toList(),
              onChanged: (v) => setState(() => _unitId = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _notesC, maxLines: 3, decoration: _inputDecoration('Catatan')),
          ],
        ),
      ),
    );
  }

  Widget _buildBomCard() {
    return Container(
      padding: const EdgeInsets.all(12),
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
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text('Bahan Baku (BOM)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ..._bom.map((b) {
              final sisa = double.tryParse((b['sisa'] ?? '0').toString()) ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sisa < 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['material_name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text('${b['qty_total'] ?? 0} ${b['unit_name'] ?? ''}'),
                        Text('Stok ${b['stok'] ?? 0}'),
                        Text('Sisa $sisa', style: TextStyle(color: sisa < 0 ? Colors.red : Colors.green)),
                      ],
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
