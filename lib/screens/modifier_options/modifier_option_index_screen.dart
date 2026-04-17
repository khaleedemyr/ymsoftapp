import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/modifier_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';

class ModifierOptionIndexScreen extends StatefulWidget {
  const ModifierOptionIndexScreen({super.key});

  @override
  State<ModifierOptionIndexScreen> createState() => _ModifierOptionIndexScreenState();
}

class _ModifierOptionIndexScreenState extends State<ModifierOptionIndexScreen> {
  final ModifierMasterService _service = ModifierMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _modifiers = [];
  bool _loading = false;
  bool _loadingMore = false;
  int? _selectedModifierId;
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCreateData();
    _loadList(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == '1' || normalized == 'true' || normalized == 'yes') return true;
    if (normalized == '0' || normalized == 'false' || normalized == 'no') return false;
    return fallback;
  }

  String _modifierName(Map<String, dynamic> modifier) {
    final name = (modifier['name'] ?? modifier['nama'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final id = _toInt(modifier['id']);
    return id > 0 ? 'Modifier $id' : '-';
  }

  List<Map<String, dynamic>> _parseBomRows(dynamic rawBom) {
    dynamic decoded = rawBom;
    if (rawBom is String) {
      final trimmed = rawBom.trim();
      if (trimmed.isEmpty) return [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return [];
      }
    }
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          return {
            'item_id': _toInt(map['item_id']),
            'qty': map['qty']?.toString() ?? '',
            'unit_id': _toInt(map['unit_id']),
            'stock_cut': _toBool(map['stock_cut'], fallback: true),
          };
        })
        .where((row) =>
            _toInt(row['item_id']) > 0 ||
            (row['qty']?.toString().trim().isNotEmpty ?? false) ||
            _toInt(row['unit_id']) > 0)
        .toList();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_loading && !_loadingMore && _page < _lastPage) {
        _loadList(refresh: false);
      }
    }
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getModifierOptionCreateData();
    if (!mounted) return;
    if (result['success'] == true) {
      final rows = ((result['modifiers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _modifiers = rows);
    }
  }

  Future<void> _loadList({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final targetPage = refresh ? 1 : _page + 1;
    final result = await _service.getModifierOptions(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      modifierId: _selectedModifierId,
      page: targetPage,
      perPage: _perPage,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal memuat modifier options'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['modifierOptions'] is Map<String, dynamic>
        ? result['modifierOptions'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rows = ((paged['data'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      if (refresh) {
        _items
          ..clear()
          ..addAll(rows);
      } else {
        _items.addAll(rows);
      }
      _page = _toInt(paged['current_page'], fallback: targetPage);
      _lastPage = _toInt(paged['last_page'], fallback: 1);
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _saveModifierOption({Map<String, dynamic>? row}) async {
    int? selectedModifier = _toInt(row?['modifier_id'], fallback: 0);
    if (selectedModifier == 0) selectedModifier = null;
    final nameController = TextEditingController(text: row?['name']?.toString() ?? '');
    final allItems = await _service.getItemsForModifierBom();
    final bomRows = _parseBomRows(row?['modifier_bom_json']);
    final unitsByItemId = <int, List<Map<String, dynamic>>>{};
    final loadingUnitsByItemId = <int>{};

    String itemLabelById(int id) {
      final item = allItems.firstWhere(
        (e) => _toInt(e['id']) == id,
        orElse: () => {'id': id, 'name': 'Item $id'},
      );
      final name = (item['name'] ?? '').toString().trim();
      return name.isEmpty ? 'Item $id' : name;
    }

    String unitLabel(Map<String, dynamic> unit) {
      final name = (unit['name'] ?? '').toString().trim();
      final type = (unit['type'] ?? '').toString().trim();
      if (name.isEmpty) return '-';
      return type.isEmpty ? name : '$name ($type)';
    }

    Future<void> loadUnitsForItem(int itemId) async {
      if (itemId <= 0 || unitsByItemId.containsKey(itemId)) return;
      final units = await _service.getItemUnitsForModifierBom(itemId);
      unitsByItemId[itemId] = units;
    }

    for (final bomRow in bomRows) {
      final itemId = _toInt(bomRow['item_id']);
      await loadUnitsForItem(itemId);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Text(row == null ? 'Tambah Modifier Option' : 'Edit Modifier Option'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedModifier,
                    decoration: const InputDecoration(
                      labelText: 'Modifier',
                      border: OutlineInputBorder(),
                    ),
                    items: _modifiers
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: _toInt(e['id']),
                            child: Text(e['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedModifier = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Option',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'BOM Modifier (Potong Stok)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setModalState(() {
                                bomRows.add({
                                  'item_id': 0,
                                  'qty': '',
                                  'unit_id': 0,
                                  'stock_cut': true,
                                });
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah Baris'),
                            ),
                          ],
                        ),
                        if (allItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Daftar item belum tersedia.',
                              style: TextStyle(color: Colors.red),
                            ),
                          )
                        else if (bomRows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Belum ada BOM',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          ...List.generate(bomRows.length, (index) {
                            final bom = bomRows[index];
                            final itemId = _toInt(bom['item_id']);
                            final unitId = _toInt(bom['unit_id']);
                            final units = unitsByItemId[itemId] ?? const <Map<String, dynamic>>[];
                            final loadingUnit = loadingUnitsByItemId.contains(itemId);
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final picked = await showMasterSingleSelectPicker(
                                              context: context,
                                              title: 'Pilih Item',
                                              source: allItems,
                                              initialId: itemId > 0 ? itemId : null,
                                              searchHint: 'Cari item...',
                                            );
                                            if (picked == null) return;
                                            setModalState(() {
                                              bom['item_id'] = picked;
                                              bom['unit_id'] = 0;
                                            });
                                            if (!unitsByItemId.containsKey(picked)) {
                                              setModalState(() {
                                                loadingUnitsByItemId.add(picked);
                                              });
                                              final units = await _service.getItemUnitsForModifierBom(picked);
                                              if (!mounted) return;
                                              setModalState(() {
                                                unitsByItemId[picked] = units;
                                                loadingUnitsByItemId.remove(picked);
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                                          label: Text(
                                            itemId > 0 ? itemLabelById(itemId) : 'Pilih Item',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus baris',
                                        onPressed: () => setModalState(() {
                                          bomRows.removeAt(index);
                                        }),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: bom['qty']?.toString() ?? '',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (v) => bom['qty'] = v,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            labelText: 'Qty',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<int?>(
                                          initialValue: units.any((u) => _toInt(u['id']) == unitId)
                                              ? unitId
                                              : null,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            labelText: 'Unit',
                                            border: OutlineInputBorder(),
                                          ),
                                          isExpanded: true,
                                          items: units
                                              .map((unit) => DropdownMenuItem<int?>(
                                                    value: _toInt(unit['id']),
                                                    child: Text(unitLabel(unit)),
                                                  ))
                                              .toList(),
                                          onChanged: itemId <= 0
                                              ? null
                                              : (v) => setModalState(() => bom['unit_id'] = v ?? 0),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          const Text('Stock Cut', style: TextStyle(fontSize: 12)),
                                          Checkbox(
                                            value: _toBool(bom['stock_cut'], fallback: true),
                                            onChanged: (v) => setModalState(() => bom['stock_cut'] = v == true),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (loadingUnit)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (saved != true) return;

    final name = nameController.text.trim();
    if (selectedModifier == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifier dan nama wajib diisi'), backgroundColor: Colors.red),
      );
      return;
    }

    final payloadBomRows = <Map<String, dynamic>>[];
    for (var i = 0; i < bomRows.length; i++) {
      final bom = bomRows[i];
      final itemId = _toInt(bom['item_id']);
      final unitId = _toInt(bom['unit_id']);
      final qtyText = (bom['qty'] ?? '').toString().trim();
      final qty = _toNum(qtyText);
      final hasAnyInput = itemId > 0 || unitId > 0 || qtyText.isNotEmpty;

      if (!hasAnyInput) continue;
      if (itemId <= 0 || unitId <= 0 || qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('BOM baris ${i + 1} belum lengkap/valid'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      payloadBomRows.add({
        'item_id': itemId,
        'qty': qty,
        'unit_id': unitId,
        'stock_cut': _toBool(bom['stock_cut'], fallback: true),
      });
    }

    final modifierBomJson =
        payloadBomRows.isEmpty ? '' : jsonEncode(payloadBomRows);

    final response = row == null
        ? await _service.createModifierOption(
            modifierId: selectedModifier!,
            name: name,
            modifierBomJson: modifierBomJson,
          )
        : await _service.updateModifierOption(
            id: _toInt(row['id']),
            modifierId: selectedModifier!,
            name: name,
            modifierBomJson: modifierBomJson,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? (response['success'] == true ? 'Berhasil disimpan' : 'Gagal disimpan')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Modifier Option'),
        content: Text('Yakin hapus "${row['name'] ?? '-'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final response = await _service.deleteModifierOption(_toInt(row['id']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? (response['success'] == true ? 'Berhasil dihapus' : 'Gagal dihapus')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Modifier Options',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveModifierOption(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14)],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadList(refresh: true),
                  decoration: InputDecoration(
                    hintText: 'Cari option...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () => _loadList(refresh: true),
                      icon: const Icon(Icons.search),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedModifierId,
                  decoration: const InputDecoration(
                    labelText: 'Filter Modifier',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Modifier')),
                    ..._modifiers.map(
                      (e) => DropdownMenuItem<int?>(
                        value: _toInt(e['id']),
                        child: Text(e['name']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedModifierId = value);
                    _loadList(refresh: true);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadList(refresh: true),
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Tidak ada data Modifier Option')),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              final row = _items[index];
                              final modifier = row['modifier'] is Map ? Map<String, dynamic>.from(row['modifier'] as Map) : <String, dynamic>{};
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFEDE9FE),
                                    child: Icon(Icons.tune_rounded, color: Colors.deepPurple.shade400),
                                  ),
                                  title: Text(row['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('Modifier: ${modifier['name'] ?? '-'}'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _saveModifierOption(row: row);
                                      if (v == 'delete') _delete(row);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

