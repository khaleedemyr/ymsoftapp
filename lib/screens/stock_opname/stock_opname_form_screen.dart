import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/stock_opname_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class StockOpnameFormScreen extends StatefulWidget {
  final int? editId;

  const StockOpnameFormScreen({super.key, this.editId});

  @override
  State<StockOpnameFormScreen> createState() => _StockOpnameFormScreenState();
}

class _StockOpnameFormScreenState extends State<StockOpnameFormScreen> {
  final StockOpnameService _service = StockOpnameService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _itemSearchController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  List<Map<String, dynamic>> _warehouseOutletsFiltered = [];
  List<Map<String, dynamic>> _users = [];
  int? _userOutletId;

  int? _outletId;
  int? _warehouseOutletId;
  String _opnameDate = '';
  bool _isLoadingData = true;
  bool _isLoadingItems = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _items = [];
  final Map<int, TextEditingController> _physicalSmall = {};
  final Map<int, TextEditingController> _physicalMedium = {};
  final Map<int, TextEditingController> _physicalLarge = {};
  final Map<int, TextEditingController> _reason = {};
  List<int> _selectedApproverIds = [];
  final Map<int, String> _selectedApproverNames = {};
  final Map<String, bool> _categoryExpanded = {};

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
      final data = result['data'] is Map ? result['data'] as Map<String, dynamic> : result;
      setState(() {
        _outlets = data['outlets'] != null ? List<Map<String, dynamic>>.from(data['outlets'] as List) : [];
        _warehouseOutlets = data['warehouse_outlets'] != null ? List<Map<String, dynamic>>.from(data['warehouse_outlets'] as List) : [];
        final rawUsers = data['users'];
        _users = rawUsers != null && rawUsers is List
            ? List<Map<String, dynamic>>.from((rawUsers as List).map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{}))
            : [];
        _userOutletId = data['user_outlet_id'] is int ? data['user_outlet_id'] as int : null;
        _filterWarehouses();
        if (_userOutletId != null && _userOutletId != 1 && _outlets.isNotEmpty) {
          _outletId = _outlets.first['id'] is int ? _outlets.first['id'] as int : int.tryParse(_outlets.first['id']?.toString() ?? '');
          _filterWarehouses();
        }
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
    final so = result!['stock_opname'] as Map<String, dynamic>? ?? {};
    final outletId = so['outlet_id'] is int ? so['outlet_id'] as int : int.tryParse(so['outlet_id']?.toString() ?? '');
    final warehouseId = so['warehouse_outlet_id'];
    final whId = warehouseId is int ? warehouseId : int.tryParse(warehouseId?.toString() ?? '');
    _dateController.text = so['opname_date']?.toString() ?? _dateController.text;
    _notesController.text = so['notes']?.toString() ?? '';
    _opnameDate = _dateController.text;
    final approvers = (result['approvers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final approverIds = approvers.map((a) => a['approver_id'] as int?).whereType<int>().toList();
    final approverNames = <int, String>{};
    for (final a in approvers) {
      final id = a['approver_id'] is int ? a['approver_id'] as int : int.tryParse(a['approver_id']?.toString() ?? '');
      if (id != null) approverNames[id] = a['approver_name']?.toString() ?? a['name']?.toString() ?? 'User #$id';
    }

    await _loadCreateData();
    if (!mounted) return;
    setState(() {
      _outletId = outletId;
      _warehouseOutletId = whId;
      _filterWarehouses();
      _selectedApproverIds = approverIds;
      _selectedApproverNames.addAll(approverNames);
    });
    await _loadItems();
    if (!mounted) return;
    final existingItems = (so['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final it in _items) {
      final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
      final exList = existingItems.where((e) => (e['inventory_item_id'] is int ? e['inventory_item_id'] as int : int.tryParse(e['inventory_item_id']?.toString() ?? '')) == invId).toList();
      final ex = exList.isNotEmpty ? exList.first : null;
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

  void _filterWarehouses() {
    _warehouseOutletsFiltered = _outletId == null
        ? []
        : _warehouseOutlets.where((w) => (w['outlet_id'] ?? w['id']) == _outletId).toList();
    if (_warehouseOutletId != null && !_warehouseOutletsFiltered.any((w) => (w['id'] ?? 0) == _warehouseOutletId)) {
      _warehouseOutletId = null;
    }
  }

  Future<void> _loadItems() async {
    if (_outletId == null || _warehouseOutletId == null) {
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

    final list = await _service.getInventoryItems(outletId: _outletId!, warehouseOutletId: _warehouseOutletId!);
    if (mounted) {
      final items = list.map((e) => Map<String, dynamic>.from(e is Map ? e as Map : {})).toList();
      final isCreate = widget.editId == null;
      for (final it in items) {
        final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
        if (invId != null && invId != 0) {
          // Saat create: kosongkan qty fisik supaya user input murni dari hitungan fisik tanpa lihat system
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

  /// Filter items by search lalu group per kategori
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

  void _copySystemToPhysical(int? invId) {
    if (invId == null) return;
    final it = _items.firstWhere((e) => (e['inventory_item_id'] is int ? e['inventory_item_id'] as int : int.tryParse(e['inventory_item_id']?.toString() ?? '0')) == invId, orElse: () => <String, dynamic>{});
    if (it.isEmpty) return;
    setState(() {
      _physicalSmall[invId]?.text = _strNum(it['qty_system_small']);
      _physicalMedium[invId]?.text = _strNum(it['qty_system_medium']);
      _physicalLarge[invId]?.text = _strNum(it['qty_system_large']);
    });
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
        'qty_physical_small': ps.isEmpty ? null : (_num(ps)),
        'qty_physical_medium': pm.isEmpty ? null : (_num(pm)),
        'qty_physical_large': pl.isEmpty ? null : (_num(pl)),
        'reason': _reason[invId]?.text?.trim(),
      });
    }
    return payload;
  }

  Future<void> _submit() async {
    if (_outletId == null || _warehouseOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet dan gudang'), backgroundColor: Colors.orange));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belum ada item. Pilih outlet dan gudang lalu tunggu data item dimuat.'), backgroundColor: Colors.orange));
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SubmitPreviewDialog(
        outletName: _outlets.cast<Map<String, dynamic>>().firstWhere((o) => (o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '')) == _outletId, orElse: () => {'name': '-'})['name']?.toString() ?? '-',
        warehouseName: _warehouseOutletsFiltered.cast<Map<String, dynamic>>().firstWhere((w) => (w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '')) == _warehouseOutletId, orElse: () => {'name': '-'})['name']?.toString() ?? '-',
        opnameDate: opnameDate,
        notes: _notesController.text.trim(),
        itemCount: itemsPayload.length,
        approverNames: _selectedApproverIds.map((id) => _approverName(id)).toList(),
        isEdit: widget.editId != null,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    if (widget.editId != null) {
      final result = await _service.update(
        id: widget.editId!,
        outletId: _outletId!,
        warehouseOutletId: _warehouseOutletId,
        opnameDate: opnameDate,
        items: itemsPayload,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        approvers: _selectedApproverIds.isEmpty ? null : _selectedApproverIds,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock opname berhasil di-update'), backgroundColor: Color(0xFF059669)));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
        }
      }
    } else {
      final result = await _service.store(
        outletId: _outletId!,
        warehouseOutletId: _warehouseOutletId,
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
      title: widget.editId != null ? 'Edit Stock Opname' : 'Buat Stock Opname',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Outlet', _buildOutletDropdown()),
                  _section('Gudang Outlet', _buildWarehouseDropdown()),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                  if (_items.isNotEmpty) ...[
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

  Widget _buildOutletDropdown() {
    final single = _userOutletId != null && _userOutletId != 1 && _outlets.length <= 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _outletId,
          isExpanded: true,
          hint: const Text('Pilih outlet'),
          items: _outlets.map((o) {
            final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '');
            return DropdownMenuItem<int>(value: id, child: Text(o['name']?.toString() ?? '-'));
          }).toList(),
          onChanged: single ? null : (v) {
            setState(() {
              _outletId = v;
              _warehouseOutletId = null;
              _filterWarehouses();
              _items = [];
            });
          },
        ),
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _warehouseOutletId,
          isExpanded: true,
          hint: const Text('Pilih gudang'),
          items: _warehouseOutletsFiltered.map((w) {
            final id = w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '');
            return DropdownMenuItem<int>(value: id, child: Text(w['name']?.toString() ?? '-'));
          }).toList(),
          onChanged: (v) {
            setState(() {
              _warehouseOutletId = v;
              _loadItems();
            });
          },
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: Color(0xFF64748B)),
            const SizedBox(width: 12),
            Text(_dateController.text.isEmpty ? 'Pilih tanggal' : _dateController.text, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  /// Isi qty lain berdasarkan konversi satuan (small_conversion_qty, medium_conversion_qty)
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

  Widget _buildItemRow(Map<String, dynamic> it, bool isCreate) {
    final invId = it['inventory_item_id'] is int ? it['inventory_item_id'] as int : int.tryParse(it['inventory_item_id']?.toString() ?? '');
    if (invId == null || invId == 0) return const SizedBox.shrink();
    final name = it['item_name']?.toString() ?? '-';
    final sysS = it['qty_system_small'];
    final sysM = it['qty_system_medium'];
    final sysL = it['qty_system_large'];
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
              ),
              if (!isCreate)
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copySystemToPhysical(invId),
                  tooltip: 'Samakan dengan system',
                ),
            ],
          ),
          if (!isCreate)
            Text('System: S=$sysS M=$sysM L=$sysL $smallUnit', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          if (!isCreate) const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _physicalSmall[invId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(labelText: labelS, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
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
                  decoration: InputDecoration(labelText: labelM, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
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
                  decoration: InputDecoration(labelText: labelL, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
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
    if (_isLoadingItems) return const Center(child: Padding(padding: EdgeInsets.all(24), child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB))));
    final isCreate = widget.editId == null;
    final grouped = _getItemsGroupedByCategory();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCreate
                ? 'Item Opname (isi qty fisik sesuai hitungan di lapangan, tanpa melihat system)'
                : 'Item Opname (isi qty fisik atau gunakan tombol = untuk salin dari system)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                    children: itemsInCategory.map((it) => _buildItemRow(it, isCreate)).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddApproverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => _ApproverPickerSheet(
          service: _service,
          selectedIds: List.from(_selectedApproverIds),
          scrollController: scrollController,
          onSelect: (id, name) {
            setState(() {
              _selectedApproverIds.add(id);
              _selectedApproverNames[id] = name;
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  String _approverName(int id) {
    if (_selectedApproverNames.containsKey(id)) return _selectedApproverNames[id]!;
    final list = _users.where((u) => (u['id'] is int ? u['id'] as int : int.tryParse(u['id']?.toString() ?? '')) == id).toList();
    return list.isNotEmpty ? (list.first['nama_lengkap']?.toString() ?? list.first['name']?.toString() ?? '') : 'User #$id';
  }

  Widget _buildApproversSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approvers (urutan dari terendah ke tertinggi)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showAddApproverSheet,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Tambah Approver'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
          ),
          if (_selectedApproverIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._selectedApproverIds.asMap().entries.map((e) {
              final idx = e.key + 1;
              final id = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(_approverName(id)),
                  leading: CircleAvatar(radius: 16, child: Text('$idx')),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626)),
                    onPressed: () => setState(() => _selectedApproverIds.remove(id)),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ApproverPickerSheet extends StatefulWidget {
  final StockOpnameService service;
  final List<int> selectedIds;
  final ScrollController scrollController;
  final void Function(int id, String name) onSelect;

  const _ApproverPickerSheet({
    required this.service,
    required this.selectedIds,
    required this.scrollController,
    required this.onSelect,
  });

  @override
  State<_ApproverPickerSheet> createState() => _ApproverPickerSheetState();
}

class _ApproverPickerSheetState extends State<_ApproverPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadApprovers('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadApprovers(String query) async {
    setState(() => _isLoading = true);
    final results = await widget.service.getApprovers(query);
    if (mounted) {
      setState(() {
        _list = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _list.where((u) {
      final id = u['id'] is int ? u['id'] as int : int.tryParse(u['id']?.toString() ?? '');
      return id != null && !widget.selectedIds.contains(id);
    }).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Pilih approver', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) {
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 400), () => _loadApprovers(value));
            },
            decoration: InputDecoration(
              hintText: 'Cari nama, email, atau jabatan...',
              prefixIcon: const Icon(Icons.search, size: 22, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        if (_isLoading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (available.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _list.isEmpty ? 'Ketik untuk cari user (min 2 karakter)' : 'Semua user di daftar sudah ditambahkan.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              controller: widget.scrollController,
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (_, i) {
                final u = available[i];
                final id = u['id'] is int ? u['id'] as int : int.tryParse(u['id']?.toString() ?? '');
                final name = u['name']?.toString() ?? u['nama_lengkap']?.toString() ?? '-';
                final jabatan = u['jabatan'] is Map ? (u['jabatan'] as Map)['nama_jabatan']?.toString() : u['jabatan']?.toString();
                final jabatanStr = jabatan?.toString() ?? '';
                return ListTile(
                  title: Text(name),
                  subtitle: jabatanStr.isNotEmpty ? Text(jabatanStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))) : null,
                  onTap: () {
                    if (id != null) {
                      widget.onSelect(id, name);
                      // Hanya tutup sheet di onSelect; jangan pop lagi di sini (bisa ikut ke-pop form)
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SubmitPreviewDialog extends StatelessWidget {
  final String outletName;
  final String warehouseName;
  final String opnameDate;
  final String notes;
  final int itemCount;
  final List<String> approverNames;
  final bool isEdit;

  const _SubmitPreviewDialog({
    required this.outletName,
    required this.warehouseName,
    required this.opnameDate,
    required this.notes,
    required this.itemCount,
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
            _row('Outlet', outletName),
            _row('Gudang', warehouseName),
            _row('Tanggal Opname', opnameDate),
            if (notes.isNotEmpty) _row('Catatan', notes),
            _row('Jumlah Item', '$itemCount'),
            const SizedBox(height: 8),
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
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
