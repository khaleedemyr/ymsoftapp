import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/warehouse_internal_use_waste_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseInternalUseWasteCreateScreen extends StatefulWidget {
  const WarehouseInternalUseWasteCreateScreen({super.key});

  @override
  State<WarehouseInternalUseWasteCreateScreen> createState() =>
      _WarehouseInternalUseWasteCreateScreenState();
}

class _WarehouseInternalUseWasteCreateScreenState
    extends State<WarehouseInternalUseWasteCreateScreen> {
  final WarehouseInternalUseWasteService _service = WarehouseInternalUseWasteService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _rukos = [];
  List<Map<String, dynamic>> _units = [];

  bool _loadingCreateData = true;
  bool _saving = false;
  String _type = 'internal_use';
  int? _warehouseId;
  int? _rukoId;
  int? _itemId;
  String _itemName = '';
  int? _unitId;
  Map<String, dynamic>? _stockInfo;

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _loadingCreateData = true);
    final result = await _service.getCreateData();
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _warehouses = result['warehouses'] is List
            ? (result['warehouses'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : [];
        _items = result['items'] is List
            ? (result['items'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : [];
        _rukos = result['rukos'] is List
            ? (result['rukos'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : [];
      }
      _loadingCreateData = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _openItemPicker() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data item tidak tersedia'), backgroundColor: Colors.orange),
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ItemPickerSheet(items: _items),
    );
    if (selected == null || !mounted) return;
    final itemId = _int(selected['id']);
    final name = selected['name']?.toString() ?? selected['nama']?.toString() ?? '-';
    if (itemId == null) return;

    setState(() {
      _itemId = itemId;
      _itemName = name;
      _unitId = null;
      _units = [];
      _stockInfo = null;
    });
    final units = await _service.getItemUnits(itemId);
    if (!mounted) return;
    // Deduplicate by id so DropdownButton has exactly one item per value
    final seenIds = <int>{};
    final deduped = <Map<String, dynamic>>[];
    for (final u in units) {
      final id = _int(u['id']);
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        deduped.add(u);
      }
    }
    setState(() {
      _units = deduped;
      if (_units.isNotEmpty && _unitId == null) {
        final first = _int(_units.first['id']);
        if (first != null) _unitId = first;
      }
    });
    _refreshStock();
  }

  Future<void> _refreshStock() async {
    if (_warehouseId == null || _itemId == null) return;
    final info = await _service.getStock(warehouseId: _warehouseId!, itemId: _itemId!);
    if (mounted) setState(() => _stockInfo = info);
  }

  Future<void> _submit() async {
    if (_saving) return;
    final date = _dateController.text.trim();
    if (date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal wajib diisi'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gudang wajib dipilih'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_type == 'internal_use' && _rukoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruko wajib dipilih untuk Internal Use'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item wajib dipilih'), backgroundColor: Colors.orange),
      );
      return;
    }
    final qty = double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qty harus lebih dari 0'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit wajib dipilih'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await _service.store(
      type: _type,
      date: date,
      warehouseId: _warehouseId!,
      rukoId: _type == 'internal_use' ? _rukoId : null,
      itemId: _itemId!,
      qty: qty,
      unitId: _unitId!,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil disimpan'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['message']?.toString() ?? 'Gagal menyimpan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCreateData) {
      return AppScaffold(
        title: 'Tambah Internal Use & Waste',
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    const primaryGreen = Color(0xFF059669);

    return AppScaffold(
      title: 'Tambah Internal Use & Waste',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionCard(
              title: 'Jenis & Waktu',
              icon: Icons.category_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('Tipe'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _type,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'internal_use', child: Text('Internal Use')),
                      DropdownMenuItem(value: 'spoil', child: Text('Spoil')),
                      DropdownMenuItem(value: 'waste', child: Text('Waste')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() { _type = v; if (v != 'internal_use') _rukoId = null; });
                    },
                  ),
                  const SizedBox(height: 16),
                  _label('Tanggal'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: _inputDecoration(),
                      child: Row(
                        children: [
                          Expanded(child: Text(_dateController.text, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Icon(Icons.calendar_today, size: 20, color: primaryGreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Lokasi',
              icon: Icons.warehouse_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('Gudang'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _warehouseId,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Pilih Gudang --', overflow: TextOverflow.ellipsis)),
                      ..._warehouses.map((w) {
                        final id = _int(w['id']);
                        final name = w['name']?.toString() ?? '-';
                        return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                      }),
                    ],
                    onChanged: (v) {
                      setState(() { _warehouseId = v; _stockInfo = null; });
                      _refreshStock();
                    },
                  ),
                  if (_type == 'internal_use') ...[
                    const SizedBox(height: 16),
                    _label('Ruko'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _rukoId,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-- Pilih Ruko --', overflow: TextOverflow.ellipsis)),
                        ..._rukos.map((r) {
                          final id = _int(r['id']);
                          final name = r['name']?.toString() ?? '-';
                          return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                        }),
                      ],
                      onChanged: (v) => setState(() => _rukoId = v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Item & Jumlah',
              icon: Icons.inventory_2_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('Item'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _openItemPicker,
                    child: InputDecorator(
                      decoration: _inputDecoration(),
                      child: Row(
                        children: [
                          Expanded(child: Text(_itemName.isEmpty ? 'Pilih item' : _itemName, style: TextStyle(color: _itemName.isEmpty ? Colors.grey : null), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                  if (_stockInfo != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: primaryGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Text(_formatStockInfo(), style: TextStyle(fontSize: 12, color: Colors.grey.shade800), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _label('Qty'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  _label('Unit'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _unitId != null && _units.any((u) => _int(u['id']) == _unitId) ? _unitId : null,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('-- Pilih Unit --', overflow: TextOverflow.ellipsis)),
                      ..._units.map((u) {
                        final id = _int(u['id']);
                        final name = u['name']?.toString() ?? '-';
                        if (id == null) return null;
                        return DropdownMenuItem<int>(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                      }).whereType<DropdownMenuItem<int>>(),
                    ],
                    onChanged: (v) => setState(() => _unitId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Catatan',
              icon: Icons.note_outlined,
              child: TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: _inputDecoration(hint: 'Opsional'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)));
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  String _formatStockInfo() {
    if (_stockInfo == null) return '';
    final s = _stockInfo!;
    String part(dynamic q, dynamic u) {
      if (q == null) return '0';
      final n = q is num ? q.toDouble() : (double.tryParse(q.toString()) ?? 0);
      final fmt = n == n.truncate() ? n.toInt().toString() : n.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return '$fmt ${(u ?? '').toString().trim()}';
    }
    return 'Stok: ${part(s['qty_small'], s['unit_small_name'])} / ${part(s['qty_medium'], s['unit_medium_name'])} / ${part(s['qty_large'], s['unit_large_name'])}';
  }
}

class _ItemPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _ItemPickerSheet({required this.items});

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((item) {
      final name = (item['name']?.toString() ?? item['nama']?.toString() ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  static String _itemName(Map<String, dynamic> item) =>
      item['name']?.toString() ?? item['nama']?.toString() ?? '-';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Pilih Item', style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari nama item...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty ? 'Tidak ada item' : 'Tidak ada hasil untuk "${_searchController.text.trim()}"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredItems.length,
                      itemBuilder: (_, i) {
                        final item = _filteredItems[i];
                        return ListTile(
                          title: Text(_itemName(item), overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
