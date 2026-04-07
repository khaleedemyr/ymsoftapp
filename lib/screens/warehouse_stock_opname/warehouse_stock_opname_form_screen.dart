import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/warehouse_stock_opname_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseStockOpnameFormScreen extends StatefulWidget {
  final int? editId;

  const WarehouseStockOpnameFormScreen({super.key, this.editId});

  @override
  State<WarehouseStockOpnameFormScreen> createState() => _WarehouseStockOpnameFormScreenState();
}

class _WarehouseStockOpnameFormScreenState extends State<WarehouseStockOpnameFormScreen> {
  final WarehouseStockOpnameService _service = WarehouseStockOpnameService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _approverSearchController = TextEditingController();
  final TextEditingController _itemSearchController = TextEditingController();
  final Map<String, bool> _categoryExpanded = {};

  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _divisions = [];
  bool _warehouseHasDivisions = false;
  bool _isLoadingData = true;
  bool _isLoadingItems = false;
  bool _isLoadingDivisions = false;
  bool _isSubmitting = false;

  int? _warehouseId;
  int? _warehouseDivisionId;
  String _opnameDate = '';
  List<Map<String, dynamic>> _items = [];
  final Map<int, TextEditingController> _physicalSmall = {};
  final Map<int, TextEditingController> _physicalMedium = {};
  final Map<int, TextEditingController> _physicalLarge = {};
  final Map<int, TextEditingController> _reason = {};
  List<int> _selectedApproverIds = [];
  final Map<int, String> _selectedApproverNames = {};
  List<Map<String, dynamic>> _approverSearchResults = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _opnameDate = _dateController.text;
    if (widget.editId != null) {
      _loadDetailThenForm();
    } else {
      _loadCreateData();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    _approverSearchController.dispose();
    _itemSearchController.dispose();
    for (final c in _physicalSmall.values) c.dispose();
    for (final c in _physicalMedium.values) c.dispose();
    for (final c in _physicalLarge.values) c.dispose();
    for (final c in _reason.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoadingData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _warehouses = result['warehouses'] != null ? List<Map<String, dynamic>>.from((result['warehouses'] as List).map((e) => Map<String, dynamic>.from(e is Map ? e : {}))) : [];
        _warehouses = _warehouses;
        _isLoadingData = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadDetailThenForm() async {
    setState(() => _isLoadingData = true);
    final result = await _service.getDetail(widget.editId!);
    if (mounted && result == null) {
      setState(() => _isLoadingData = false);
      return;
    }
    final opname = result!['data'] as Map<String, dynamic>? ?? {};
    final whId = opname['warehouse_id'] is int ? opname['warehouse_id'] as int : int.tryParse(opname['warehouse_id']?.toString() ?? '');
    final divId = opname['warehouse_division_id'];
    final divisionId = divId != null && divId != '' ? (divId is int ? divId as int : int.tryParse(divId.toString())) : null;

    _dateController.text = opname['opname_date']?.toString() ?? _dateController.text;
    _notesController.text = opname['notes']?.toString() ?? '';
    _opnameDate = _dateController.text;

    final approvers = (result['approvers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final approverIds = approvers.map((a) => a['id'] is int ? a['id'] as int : int.tryParse(a['id']?.toString() ?? '')).whereType<int>().toList();
    final approverNames = <int, String>{};
    for (final a in approvers) {
      final id = a['id'] is int ? a['id'] as int : int.tryParse(a['id']?.toString() ?? '');
      if (id != null && id != 0) approverNames[id!] = a['name']?.toString() ?? 'User #$id';
    }

    await _loadCreateData();
    if (!mounted) return;
    setState(() {
      _warehouseId = whId;
      _warehouseDivisionId = divisionId;
      _selectedApproverIds = approverIds;
      _selectedApproverNames.addAll(approverNames);
    });
    await _checkDivisions();
    await _loadItems();
    if (!mounted) return;
    final existingItems = (opname['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final it in _items) {
      final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
      final exList = existingItems.cast<Map<String, dynamic>>().where((e) => (e['inventory_item_id'] is int ? e['inventory_item_id'] as int : int.tryParse(e['inventory_item_id']?.toString() ?? '')) == invId).toList();
    final ex = exList.isEmpty ? null : exList.first;
      if (ex != null) {
        _physicalSmall[invId]?.text = _strNum(ex['qty_physical_small']);
        _physicalMedium[invId]?.text = _strNum(ex['qty_physical_medium']);
        _physicalLarge[invId]?.text = _strNum(ex['qty_physical_large']);
        _reason[invId]?.text = ex['reason']?.toString() ?? '';
      }
    }
    setState(() => _isLoadingData = false);
  }

  String _strNum(dynamic v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    if (v is double) return v.toString();
    return v.toString();
  }

  Future<void> _checkDivisions() async {
    if (_warehouseId == null) return;
    setState(() => _isLoadingDivisions = true);
    final result = await _service.checkDivisions(_warehouseId!);
    if (mounted && result != null) {
      setState(() {
        _warehouseHasDivisions = result['has_divisions'] == true;
        _divisions = result['divisions'] != null && result['divisions'] is List
            ? List<Map<String, dynamic>>.from((result['divisions'] as List).map((e) => Map<String, dynamic>.from(e is Map ? e : {})))
            : [];
        if (!_warehouseHasDivisions) _warehouseDivisionId = null;
        _isLoadingDivisions = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingDivisions = false);
    }
  }

  Future<void> _loadItems() async {
    if (_warehouseId == null) {
      setState(() => _items = []);
      return;
    }
    if (_warehouseHasDivisions && _warehouseDivisionId == null) {
      setState(() => _items = []);
      return;
    }
    setState(() => _isLoadingItems = true);
    for (final c in _physicalSmall.values) c.dispose();
    for (final c in _physicalMedium.values) c.dispose();
    for (final c in _physicalLarge.values) c.dispose();
    for (final c in _reason.values) c.dispose();
    _physicalSmall.clear();
    _physicalMedium.clear();
    _physicalLarge.clear();
    _reason.clear();

    final list = await _service.getItems(warehouseId: _warehouseId!, warehouseDivisionId: _warehouseDivisionId);
    if (mounted) {
      final items = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
      final isCreate = widget.editId == null;
      for (final it in items) {
        final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
        if (invId != null && invId != 0) {
          if (isCreate) {
            _physicalSmall[invId] = TextEditingController();
            _physicalMedium[invId] = TextEditingController();
            _physicalLarge[invId] = TextEditingController();
          } else {
            _physicalSmall[invId] = TextEditingController(text: _strNum(it['qty_system_small']));
            _physicalMedium[invId] = TextEditingController(text: _strNum(it['qty_system_medium']));
            _physicalLarge[invId] = TextEditingController(text: _strNum(it['qty_system_large']));
          }
          _reason[invId] = TextEditingController();
        }
      }
      setState(() {
        _items = items;
        _isLoadingItems = false;
        for (final it in _items) {
          final cat = it['category_name']?.toString().trim() ?? '';
          final key = cat.isEmpty ? 'Lainnya' : cat;
          _categoryExpanded[key] = true;
        }
      });
    }
  }

  void _onWarehouseChanged(int? id) {
    setState(() {
      _warehouseId = id;
      _warehouseDivisionId = null;
      _divisions = [];
      _warehouseHasDivisions = false;
      _items = [];
    });
    if (id != null) _checkDivisions();
  }

  void _onDivisionChanged(int? id) {
    setState(() {
      _warehouseDivisionId = id;
      _items = [];
    });
    if (_warehouseId != null) _loadItems();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        _opnameDate = _dateController.text;
      });
    }
  }

  /// Konversi otomatis S/M/L seperti outlet stock opname
  void _applyPhysicalQtyConversion(int invId, String fromField, Map<String, dynamic> it) {
    final smallConv = _num(it['small_conversion_qty']) > 0 ? _num(it['small_conversion_qty']) : 1.0;
    final mediumConv = _num(it['medium_conversion_qty']) > 0 ? _num(it['medium_conversion_qty']) : 1.0;
    double totalSmall = 0;
    final sCtrl = _physicalSmall[invId];
    final mCtrl = _physicalMedium[invId];
    final lCtrl = _physicalLarge[invId];
    if (sCtrl == null || mCtrl == null || lCtrl == null) return;
    switch (fromField) {
      case 'S':
        totalSmall = _num(sCtrl.text);
        mCtrl.text = _formatQty(totalSmall / smallConv);
        lCtrl.text = _formatQty(totalSmall / (smallConv * mediumConv));
        break;
      case 'M':
        totalSmall = _num(mCtrl.text) * smallConv;
        sCtrl.text = _formatQty(totalSmall);
        lCtrl.text = _formatQty(_num(mCtrl.text) / mediumConv);
        break;
      case 'L':
        totalSmall = _num(lCtrl.text) * mediumConv * smallConv;
        sCtrl.text = _formatQty(totalSmall);
        mCtrl.text = _formatQty(_num(lCtrl.text) * mediumConv);
        break;
    }
    setState(() {});
  }

  String _formatQty(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  Map<String, List<Map<String, dynamic>>> _getItemsGroupedByCategory() {
    final query = _itemSearchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = _items;
    if (query.isNotEmpty) {
      list = _items.where((it) {
        final name = (it['item_name'] ?? '').toString().toLowerCase();
        final cat = (it['category_name'] ?? '').toString().toLowerCase();
        return name.contains(query) || cat.contains(query);
      }).toList();
    }
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final it in list) {
      final cat = it['category_name']?.toString().trim() ?? '';
      final key = cat.isEmpty ? 'Lainnya' : cat;
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(it);
    }
    final keys = grouped.keys.toList()..sort();
    return Map.fromEntries(keys.map((k) => MapEntry(k, grouped[k]!)));
  }

  List<Map<String, dynamic>> _buildItemsPayload() {
    final payload = <Map<String, dynamic>>[];
    for (final it in _items) {
      final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
      if (invId == 0) continue;
      final ps = _physicalSmall[invId]?.text?.trim() ?? '';
      final pm = _physicalMedium[invId]?.text?.trim() ?? '';
      final pl = _physicalLarge[invId]?.text?.trim() ?? '';
      payload.add({
        'inventory_item_id': invId,
        'qty_physical_small': ps.isEmpty ? null : _num(ps),
        'qty_physical_medium': pm.isEmpty ? null : _num(pm),
        'qty_physical_large': pl.isEmpty ? null : _num(pl),
        'reason': _reason[invId]?.text?.trim(),
      });
    }
    return payload;
  }

  Future<void> _searchApprovers() async {
    final q = _approverSearchController.text.trim();
    if (q.length < 2) {
      setState(() => _approverSearchResults = []);
      return;
    }
    final list = await _service.getApprovers(q);
    if (mounted) setState(() => _approverSearchResults = list);
  }

  void _addApprover(Map<String, dynamic> user) {
    final id = user['id'] is int ? user['id'] as int : int.tryParse(user['id']?.toString() ?? '');
    if (id == null || id == 0 || _selectedApproverIds.contains(id)) return;
    final idVal = id!;
    setState(() {
      _selectedApproverIds.add(idVal);
      _selectedApproverNames[idVal] = user['name']?.toString() ?? user['nama_lengkap']?.toString() ?? 'User #$idVal';
      _approverSearchController.clear();
      _approverSearchResults = [];
    });
  }

  void _removeApprover(int id) {
    setState(() {
      _selectedApproverIds.remove(id);
      _selectedApproverNames.remove(id);
    });
  }

  Future<void> _submit() async {
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih gudang'), backgroundColor: Colors.orange));
      return;
    }
    if (_warehouseHasDivisions && _warehouseDivisionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih divisi gudang'), backgroundColor: Colors.orange));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belum ada item. Pilih gudang (dan divisi jika ada) lalu tunggu data dimuat.'), backgroundColor: Colors.orange));
      return;
    }
    final opnameDate = _dateController.text.trim();
    if (opnameDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal opname'), backgroundColor: Colors.orange));
      return;
    }
    final itemsPayload = _buildItemsPayload();
    if (itemsPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal isi 1 item'), backgroundColor: Colors.orange));
      return;
    }

    final whList = _warehouses.where((w) => (w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '')) == _warehouseId).toList();
    final warehouseName = whList.isEmpty ? '-' : (whList.first['name']?.toString() ?? '-');
    String divisionName = '-';
    if (_warehouseDivisionId != null) {
      final divList = _divisions.where((d) => (d['id'] is int ? d['id'] as int : int.tryParse(d['id']?.toString() ?? '')) == _warehouseDivisionId).toList();
      divisionName = divList.isEmpty ? '-' : (divList.first['name']?.toString() ?? '-');
    }
    final approverNames = _selectedApproverIds.map((id) => _selectedApproverNames[id] ?? 'User #$id').toList();
    final itemSummaries = <MapEntry<String, String>>[];
    for (final p in itemsPayload) {
      final invId = p['inventory_item_id'] is int ? p['inventory_item_id'] as int : int.tryParse(p['inventory_item_id']?.toString() ?? '');
      final itList = _items.where((e) => (e['inventory_item_id'] is int ? e['inventory_item_id'] as int : int.tryParse(e['inventory_item_id']?.toString() ?? '')) == invId).toList();
      final name = itList.isEmpty ? 'Item #$invId' : (itList.first['item_name']?.toString() ?? 'Item #$invId');
      final s = p['qty_physical_small']?.toString() ?? '-';
      final m = p['qty_physical_medium']?.toString() ?? '-';
      final l = p['qty_physical_large']?.toString() ?? '-';
      itemSummaries.add(MapEntry(name, 'S:$s M:$m L:$l'));
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SubmitPreviewDialog(
        warehouseName: warehouseName,
        divisionName: divisionName,
        opnameDate: opnameDate,
        notes: _notesController.text.trim(),
        itemCount: itemsPayload.length,
        itemSummaries: itemSummaries,
        approverNames: approverNames,
        isEdit: widget.editId != null,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    if (widget.editId != null) {
      final result = await _service.update(
        id: widget.editId!,
        warehouseId: _warehouseId!,
        warehouseDivisionId: _warehouseDivisionId,
        opnameDate: opnameDate,
        items: itemsPayload,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        approvers: _selectedApproverIds.isEmpty ? null : _selectedApproverIds,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil di-update'), backgroundColor: Color(0xFF059669)));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
        }
      }
    } else {
      final result = await _service.store(
        warehouseId: _warehouseId!,
        warehouseDivisionId: _warehouseDivisionId,
        opnameDate: opnameDate,
        items: itemsPayload,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        approvers: _selectedApproverIds.isEmpty ? null : _selectedApproverIds,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock opname berhasil dibuat'), backgroundColor: Color(0xFF059669)));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.editId != null ? 'Edit Warehouse Stock Opname' : 'Buat Warehouse Stock Opname',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Gudang', _buildWarehouseDropdown()),
                  if (_warehouseHasDivisions) _section('Divisi Gudang', _buildDivisionDropdown()),
                  _section('Tanggal Opname', _buildDateField()),
                  _section(
                    'Catatan',
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Catatan (opsional)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  if (_isLoadingItems) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF2563EB)))),
                  if (_items.isNotEmpty && !_isLoadingItems) ...[
                    const SizedBox(height: 16),
                    _buildItemsSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildApproversSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.editId != null ? 'Simpan Perubahan' : 'Simpan Stock Opname'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _warehouseId,
          isExpanded: true,
          hint: const Text('Pilih gudang'),
          items: [const DropdownMenuItem<int?>(value: null, child: Text('Pilih gudang'))]
              ..addAll(_warehouses.map((w) {
                final id = w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '');
                return DropdownMenuItem<int?>(value: id, child: Text(w['name']?.toString() ?? '-'));
              })),
          onChanged: (v) => _onWarehouseChanged(v),
        ),
      ),
    );
  }

  Widget _buildDivisionDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _warehouseDivisionId,
          isExpanded: true,
          hint: Text(_isLoadingDivisions ? 'Memeriksa divisi...' : 'Pilih divisi'),
          items: [const DropdownMenuItem<int?>(value: null, child: Text('Pilih divisi'))]
              ..addAll(_divisions.map((d) {
                final id = d['id'] is int ? d['id'] as int : int.tryParse(d['id']?.toString() ?? '');
                return DropdownMenuItem<int?>(value: id, child: Text(d['name']?.toString() ?? '-'));
              })),
          onChanged: _isLoadingDivisions ? null : (v) => _onDivisionChanged(v),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: AbsorbPointer(
        child: TextField(
          controller: _dateController,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ),
    );
  }

  /// Satu baris item: nama, konversi satuan, 3 input Fisik S/M/L (tanpa tampil system/selisih)
  Widget _buildItemRow(Map<String, dynamic> it) {
    final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
    if (invId == null || invId == 0) return const SizedBox.shrink();
    final name = it['item_name']?.toString() ?? '-';
    final smallUnit = it['small_unit_name']?.toString() ?? '';
    final mediumUnit = it['medium_unit_name']?.toString() ?? '';
    final largeUnit = it['large_unit_name']?.toString() ?? '';
    final labelS = smallUnit.isEmpty ? 'Fisik S' : 'Fisik S ($smallUnit)';
    final labelM = mediumUnit.isEmpty ? 'Fisik M' : 'Fisik M ($mediumUnit)';
    final labelL = largeUnit.isEmpty ? 'Fisik L' : 'Fisik L ($largeUnit)';
    final smallConv = _num(it['small_conversion_qty']) >= 1 ? _num(it['small_conversion_qty']) : 1.0;
    final mediumConv = _num(it['medium_conversion_qty']) >= 1 ? _num(it['medium_conversion_qty']) : 1.0;
    final convText = smallUnit.isNotEmpty || mediumUnit.isNotEmpty || largeUnit.isNotEmpty
        ? '1 ${largeUnit.isNotEmpty ? largeUnit : 'L'} = ${mediumConv.toInt()} ${mediumUnit.isNotEmpty ? mediumUnit : 'M'} = ${(mediumConv * smallConv).toInt()} $smallUnit'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (convText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(convText, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _physicalSmall[invId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    labelText: labelS,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => _applyPhysicalQtyConversion(invId, 'S', it),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _physicalMedium[invId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    labelText: labelM,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => _applyPhysicalQtyConversion(invId, 'M', it),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _physicalLarge[invId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    labelText: labelL,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => _applyPhysicalQtyConversion(invId, 'L', it),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    if (_isLoadingItems) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB))));
    }
    final grouped = _getItemsGroupedByCategory();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Item Opname (isi qty fisik sesuai hitungan di lapangan)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _itemSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari item atau kategori...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) {
                  final categoryName = entry.key;
                  final itemsInCategory = entry.value;
                  final isExpanded = _categoryExpanded[categoryName] ?? true;
                  return ExpansionTile(
                    key: ValueKey('cat-$categoryName-$isExpanded'),
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (v) => setState(() => _categoryExpanded[categoryName] = v),
                    title: Text(
                      '$categoryName (${itemsInCategory.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    children: itemsInCategory.map((it) => _buildItemRow(it)).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproversSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approvers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          TextField(
            controller: _approverSearchController,
            decoration: InputDecoration(
              hintText: 'Cari nama / email (min 2 karakter)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => _searchApprovers(),
          ),
          if (_approverSearchResults.isNotEmpty)
            ..._approverSearchResults.take(5).map((u) => ListTile(
                  title: Text(u['name']?.toString() ?? u['nama_lengkap']?.toString() ?? '-'),
                  subtitle: Text(u['email']?.toString() ?? ''),
                  onTap: () => _addApprover(u),
                )),
          const SizedBox(height: 8),
          ..._selectedApproverIds.asMap().entries.map((e) {
            final id = e.value;
            final name = _selectedApproverNames[id] ?? 'User #$id';
            return ListTile(
              dense: true,
              title: Text(name),
              trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeApprover(id)),
            );
          }),
        ],
      ),
    );
  }
}

class _SubmitPreviewDialog extends StatelessWidget {
  final String warehouseName;
  final String divisionName;
  final String opnameDate;
  final String notes;
  final int itemCount;
  final List<MapEntry<String, String>> itemSummaries;
  final List<String> approverNames;
  final bool isEdit;

  const _SubmitPreviewDialog({
    required this.warehouseName,
    required this.divisionName,
    required this.opnameDate,
    required this.notes,
    required this.itemCount,
    required this.itemSummaries,
    required this.approverNames,
    required this.isEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdit ? 'Preview - Simpan Perubahan' : 'Preview - Simpan Stock Opname'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Gudang', warehouseName),
            _row('Divisi Gudang', divisionName),
            _row('Tanggal Opname', opnameDate),
            if (notes.isNotEmpty) _row('Catatan', notes),
            _row('Jumlah Item', '$itemCount'),
            const SizedBox(height: 8),
            const Text('Item (qty fisik S / M / L):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            ...itemSummaries.take(15).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Text(e.key, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                ],
              ),
            )),
            if (itemSummaries.length > 15) Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('+ ${itemSummaries.length - 15} item lainnya', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
            const SizedBox(height: 12),
            const Text('Approvers:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (approverNames.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 4), child: Text('Tidak ada', style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
            if (approverNames.isNotEmpty)
              ...approverNames.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 13)),
              )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
