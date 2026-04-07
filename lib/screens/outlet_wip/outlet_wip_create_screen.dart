import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_wip_models.dart';
import '../../services/outlet_wip_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletWIPCreateScreen extends StatefulWidget {
  /// Jika ada, form dibuka untuk edit draft (data draft di-load dan di-pre-fill).
  final int? draftHeaderId;

  const OutletWIPCreateScreen({super.key, this.draftHeaderId});

  @override
  State<OutletWIPCreateScreen> createState() => _OutletWIPCreateScreenState();
}

class _OutletWIPCreateScreenState extends State<OutletWIPCreateScreen> {
  final OutletWIPService _service = OutletWIPService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _loadingData = true;
  bool _saving = false;
  String? _error;

  List<OutletWIPItemOption> _items = [];
  List<OutletWIPWarehouseOption> _warehouseOutlets = [];
  List<OutletWIPOutletOption> _outlets = [];
  int? _userOutletId;

  int? _selectedOutletId;
  int? _selectedWarehouseId;
  final List<_ProductionRow> _rows = [];
  /// Set setelah load draft agar field qty/qty jadi di-rebuild dengan initialValue yang benar.
  int? _draftFormSeed;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _batchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() {
      _loadingData = true;
      _error = null;
    });
    try {
      final result = await _service.getCreateData();
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loadingData = false;
          _error = 'Gagal memuat data form';
        });
        return;
      }
      final itemsRaw = result['items'] as List<dynamic>? ?? [];
      final whRaw = result['warehouse_outlets'] as List<dynamic>? ?? [];
      final outRaw = result['outlets'] as List<dynamic>? ?? [];
      final userOutletId = result['user_outlet_id'];

      _userOutletId = int.tryParse(userOutletId?.toString() ?? '');
      _items = itemsRaw.map((e) => OutletWIPItemOption.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      _warehouseOutlets = whRaw.map((e) => OutletWIPWarehouseOption.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      _outlets = outRaw.map((e) => OutletWIPOutletOption.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      if (_userOutletId == 1 && _outlets.isNotEmpty) {
        _selectedOutletId = _outlets.first.id;
      } else if (_userOutletId != null && _userOutletId != 1) {
        _selectedOutletId = _userOutletId;
      }
      _applyInitialWarehouse();
      if (_warehouseOutlets.isNotEmpty && _selectedWarehouseId == null) {
        _selectedWarehouseId = _warehouseOutlets.first.id;
      }
      setState(() {
        _loadingData = false;
        if (_rows.isEmpty) _rows.add(_ProductionRow());
      });
      if (mounted && widget.draftHeaderId != null) {
        await _loadDraftIntoForm(widget.draftHeaderId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingData = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Load data draft dan isi ke form (outlet, gudang, tanggal, batch, catatan, item produksi).
  Future<void> _loadDraftIntoForm(int headerId) async {
    final detail = await _service.getDetail(headerId);
    if (!mounted || detail == null) return;
    final header = detail['header'] as Map<String, dynamic>?;
    final productions = detail['productions'] as List<dynamic>? ?? [];
    if (header == null) return;

    _selectedOutletId = int.tryParse(header['outlet_id']?.toString() ?? '');
    _selectedWarehouseId = int.tryParse(header['warehouse_outlet_id']?.toString() ?? '');
    final prodDate = header['production_date']?.toString();
    if (prodDate != null && prodDate.isNotEmpty) _dateController.text = prodDate;
    _batchController.text = header['batch_number']?.toString() ?? '';
    _notesController.text = header['notes']?.toString() ?? '';

    _rows.clear();
    for (final p in productions) {
      final m = Map<String, dynamic>.from(p as Map);
      final row = _ProductionRow();
      row.selectedItemId = int.tryParse(m['item_id']?.toString() ?? '');
      row.qty = (double.tryParse(m['qty']?.toString() ?? '') ?? 0);
      row.qtyJadi = (double.tryParse(m['qty_jadi']?.toString() ?? '') ?? 0);
      row.selectedUnitId = int.tryParse(m['unit_id']?.toString() ?? '');
      _rows.add(row);
    }
    if (_rows.isEmpty) _rows.add(_ProductionRow());
    _draftFormSeed = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
  }

  void _applyInitialWarehouse() {
    if (_selectedOutletId == null) return;
    if (_userOutletId == 1) {
      final filtered = _warehouseOutlets.where((w) => w.outletId == _selectedOutletId).toList();
      if (filtered.isNotEmpty && !filtered.any((w) => w.id == _selectedWarehouseId)) {
        _selectedWarehouseId = filtered.first.id;
      }
    } else if (_warehouseOutlets.isNotEmpty && _selectedWarehouseId == null) {
      _selectedWarehouseId = _warehouseOutlets.first.id;
    }
  }

  List<OutletWIPWarehouseOption> get _filteredWarehouses {
    if (_userOutletId != 1) return _warehouseOutlets;
    if (_selectedOutletId == null) return _warehouseOutlets;
    return _warehouseOutlets.where((w) => w.outletId == _selectedOutletId).toList();
  }

  void _addRow() {
    setState(() => _rows.add(_ProductionRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() => _rows.removeAt(index));
  }

  Future<void> _loadBomForRow(_ProductionRow row) async {
    if (row.selectedItemId == null || row.qty <= 0 || _selectedOutletId == null || _selectedWarehouseId == null) {
      return;
    }
    setState(() => row.loadingBom = true);
    try {
      final result = await _service.getBomAndStock(
        itemId: row.selectedItemId!,
        qty: row.qty,
        outletId: _selectedOutletId!,
        warehouseOutletId: _selectedWarehouseId!,
      );
      if (!mounted) return;
      if (result is List) {
        final list = result.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return _BomLine(
            materialName: m['material_name']?.toString() ?? '-',
            qtyNeeded: (double.tryParse(m['qty_needed']?.toString() ?? '') ?? 0),
            materialUnitName: m['material_unit_name']?.toString() ?? '',
            stock: (double.tryParse(m['stock']?.toString() ?? '') ?? 0),
            sufficient: m['sufficient'] == true,
          );
        }).toList();
        setState(() {
          row.bomData = list;
          row.loadingBom = false;
        });
      } else {
        setState(() {
          row.bomData = [];
          row.loadingBom = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        row.bomData = [];
        row.loadingBom = false;
      });
    }
  }

  bool _rowCanProduce(_ProductionRow row) {
    if (row.bomData == null || row.bomData!.isEmpty) return false;
    return row.bomData!.every((e) => e.sufficient);
  }

  String _formatBomNumber(double n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2).replaceAll('.', ',');
  }

  bool _validate() {
    if (_selectedOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet')));
      return false;
    }
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih gudang')));
      return false;
    }
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi tanggal produksi')));
      return false;
    }
    final productions = _buildProductions();
    if (productions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambahkan minimal 1 item produksi')));
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _buildProductions() {
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final itemId = r.selectedItemId;
      if (itemId == null) continue;
      final qty = r.qty;
      final qtyJadi = r.qtyJadi;
      final unitId = r.selectedUnitId;
      if (unitId == null || qty <= 0 || qtyJadi <= 0) continue;
      list.add({
        'item_id': itemId,
        'qty': qty,
        'qty_jadi': qtyJadi,
        'unit_id': unitId,
      });
    }
    return list;
  }

  Future<void> _saveDraft() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final result = await _service.store(
        outletId: _selectedOutletId!,
        warehouseOutletId: _selectedWarehouseId!,
        productionDate: _dateController.text,
        batchNumber: _batchController.text.isEmpty ? null : _batchController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        productions: _buildProductions(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft tersimpan')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Gagal menyimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _saveAndSubmit() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      // Saat edit draft: update draft lalu submit draft yang sama (jangan buat header baru).
      if (widget.draftHeaderId != null) {
        final storeResult = await _service.store(
          outletId: _selectedOutletId!,
          warehouseOutletId: _selectedWarehouseId!,
          productionDate: _dateController.text,
          batchNumber: _batchController.text.isEmpty ? null : _batchController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          productions: _buildProductions(),
        );
        if (!mounted) return;
        if (storeResult['success'] != true) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(storeResult['message']?.toString() ?? 'Gagal menyimpan draft')),
          );
          return;
        }
        final submitResult = await _service.submit(widget.draftHeaderId!);
        if (!mounted) return;
        setState(() => _saving = false);
        if (submitResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft berhasil diproses')));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(submitResult['message']?.toString() ?? 'Gagal submit')),
          );
        }
        return;
      }
      // Buat baru: simpan dan proses sekaligus (satu header baru).
      final result = await _service.storeAndSubmit(
        outletId: _selectedOutletId!,
        warehouseOutletId: _selectedWarehouseId!,
        productionDate: _dateController.text,
        batchNumber: _batchController.text.isEmpty ? null : _batchController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        productions: _buildProductions(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produksi berhasil disimpan dan diproses')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Gagal')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.draftHeaderId != null ? 'Edit Draft / Tambah Inputan' : 'Tambah Produksi WIP',
      body: _loadingData
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadCreateData, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_userOutletId == 1 && _outlets.isNotEmpty) ...[
                        const Text('Outlet', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildOutletSearchField(),
                        const SizedBox(height: 12),
                      ],
                      const Text('Gudang', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedWarehouseId,
                        decoration: _inputDecoration(),
                        items: _filteredWarehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedWarehouseId = v;
                            for (final r in _rows) { r.bomData = null; }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Tanggal Produksi', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: _inputDecoration().copyWith(
                          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _selectDate),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Batch (opsional)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _batchController,
                        decoration: _inputDecoration(),
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 12),
                      const Text('Catatan (opsional)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesController,
                        decoration: _inputDecoration(),
                        maxLines: 2,
                        minLines: 1,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Item Produksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Tambah'),
                          ),
                        ],
                      ),
                      ...List.generate(_rows.length, (i) => _buildProductionRow(i)),
                      const SizedBox(height: 24),
                      if (_saving)
                        const Center(child: AppLoadingIndicator(size: 28, color: Color(0xFF6366F1)))
                      else ...[
                        ElevatedButton(
                          onPressed: _saveDraft,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Simpan Draft'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _saveAndSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Simpan & Proses Stok'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  String get _selectedOutletName {
    if (_selectedOutletId == null) return '';
    final o = _outlets.cast<OutletWIPOutletOption?>().firstWhere(
          (e) => e?.id == _selectedOutletId,
          orElse: () => null,
        );
    return o?.name ?? '';
  }

  Widget _buildOutletSearchField() {
    return InkWell(
      onTap: _userOutletId != 1 ? null : _openOutletSearch,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration().copyWith(
          suffixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
        ),
        child: Text(
          _selectedOutletName.isEmpty ? 'Cari atau pilih outlet...' : _selectedOutletName,
          style: TextStyle(
            fontSize: 16,
            color: _selectedOutletName.isEmpty ? Colors.grey.shade600 : null,
          ),
        ),
      ),
    );
  }

  Future<void> _openOutletSearch() async {
    final searchController = TextEditingController();
    List<OutletWIPOutletOption> filtered = List.from(_outlets);
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
                initialChildSize: 0.6,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari outlet...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onChanged: (v) {
                          final q = v.trim().toLowerCase();
                          setModalState(() {
                            filtered = q.isEmpty
                                ? List.from(_outlets)
                                : _outlets.where((o) => o.name.toLowerCase().contains(q)).toList();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          return ListTile(
                            title: Text(o.name),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() {
                                _selectedOutletId = o.id;
                                _selectedWarehouseId = null;
                                for (final r in _rows) { r.bomData = null; }
                                final wh = _warehouseOutlets.where((w) => w.outletId == o.id).toList();
                                if (wh.isNotEmpty) _selectedWarehouseId = wh.first.id;
                              });
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
      try { searchController.dispose(); } catch (_) {}
    });
  }

  Future<void> _openItemSearch(_ProductionRow row) async {
    final searchController = TextEditingController();
    List<OutletWIPItemOption> filtered = List.from(_items);
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
                initialChildSize: 0.6,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari item WIP...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onChanged: (v) {
                          final q = v.trim().toLowerCase();
                          setModalState(() {
                            filtered = q.isEmpty
                                ? List.from(_items)
                                : _items.where((o) => o.name.toLowerCase().contains(q)).toList();
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
                          return ListTile(
                            title: Text(item.name),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() {
                                row.selectedItemId = item.id;
                                row.selectedUnitId = item.smallUnitId ?? item.mediumUnitId ?? item.largeUnitId;
                              });
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
      try { searchController.dispose(); } catch (_) {}
    });
  }

  Widget _buildProductionRow(int index) {
    final row = _rows[index];
    final itemOptions = _items;
    final selectedItem = itemOptions.cast<OutletWIPItemOption?>().firstWhere(
          (e) => e?.id == row.selectedItemId,
          orElse: () => null,
        );
    final unitOptions = <int, String>{};
    if (selectedItem != null) {
      if (selectedItem.smallUnitId != null && selectedItem.smallUnitName != null) {
        unitOptions[selectedItem.smallUnitId!] = selectedItem.smallUnitName!;
      }
      if (selectedItem.mediumUnitId != null && selectedItem.mediumUnitName != null) {
        unitOptions[selectedItem.mediumUnitId!] = selectedItem.mediumUnitName!;
      }
      if (selectedItem.largeUnitId != null && selectedItem.largeUnitName != null) {
        unitOptions[selectedItem.largeUnitId!] = selectedItem.largeUnitName!;
      }
    }
    if (unitOptions.isEmpty && selectedItem != null) {
      unitOptions[selectedItem.smallUnitId ?? 0] = selectedItem.smallUnitName ?? 'Unit';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openItemSearch(row),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration().copyWith(
                        suffixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                      ),
                      child: Text(
                        selectedItem?.name ?? 'Cari atau pilih item WIP...',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedItem == null ? Colors.grey.shade600 : null,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeRow(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('qty_${index}_${_draftFormSeed ?? 0}'),
                    initialValue: row.qty != 0 ? (row.qty == row.qty.roundToDouble() ? row.qty.toInt().toString() : row.qty.toString()) : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration().copyWith(labelText: 'Qty'),
                    onChanged: (v) {
                      row.qty = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      row.bomData = null;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('qtyjadi_${index}_${_draftFormSeed ?? 0}'),
                    initialValue: row.qtyJadi != 0 ? (row.qtyJadi == row.qtyJadi.roundToDouble() ? row.qtyJadi.toInt().toString() : row.qtyJadi.toString()) : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration().copyWith(labelText: 'Qty Jadi'),
                    onChanged: (v) {
                      row.qtyJadi = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: row.selectedUnitId,
                    decoration: _inputDecoration(),
                    hint: const Text('Unit'),
                    items: unitOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => row.selectedUnitId = v),
                  ),
                ),
              ],
            ),
            if (row.selectedItemId != null && row.qty > 0) ...[
              const SizedBox(height: 12),
              _buildBomSection(row, index),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBomSection(_ProductionRow row, int index) {
    return InkWell(
      onTap: () {
        setState(() {
          row.showBom = !row.showBom;
          if (row.showBom && row.bomData == null && !row.loadingBom) {
            _loadBomForRow(row);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  row.showBom ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                const Text('Lihat BoM & Stock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 8),
                if (row.bomData != null && row.bomData!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _rowCanProduce(row) ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _rowCanProduce(row) ? '✓ Bisa Diproduksi' : '✗ Tidak Bisa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _rowCanProduce(row) ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                if (row.loadingBom) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  Text('Memuat...', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ],
            ),
            if (row.showBom && row.bomData != null) ...[
              const SizedBox(height: 12),
              if (row.bomData!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Item ini tidak memiliki BOM. Definisikan komposisi bahan terlebih dahulu.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(0.8),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        Padding(padding: EdgeInsets.all(6), child: Text('Material', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Qty Dibutuhkan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Stok Tersedia', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                      ],
                    ),
                    ...row.bomData!.map((b) => TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(6), child: Text(b.materialName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                        Padding(padding: const EdgeInsets.all(6), child: Text('${_formatBomNumber(b.qtyNeeded)} ${b.materialUnitName}', style: const TextStyle(fontSize: 11))),
                        Padding(padding: const EdgeInsets.all(6), child: Text('${_formatBomNumber(b.stock)} ${b.materialUnitName}', style: const TextStyle(fontSize: 11))),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            b.sufficient ? '✓ Cukup' : '✗ Kurang',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: b.sufficient ? Colors.green.shade700 : Colors.red.shade700),
                          ),
                        ),
                      ],
                    )),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BomLine {
  final String materialName;
  final double qtyNeeded;
  final String materialUnitName;
  final double stock;
  final bool sufficient;

  _BomLine({
    required this.materialName,
    required this.qtyNeeded,
    required this.materialUnitName,
    required this.stock,
    required this.sufficient,
  });
}

class _ProductionRow {
  int? selectedItemId;
  double qty = 0;
  double qtyJadi = 0;
  int? selectedUnitId;
  bool showBom = false;
  List<_BomLine>? bomData;
  bool loadingBom = false;
}
