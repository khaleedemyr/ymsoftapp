import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_rejection_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class _LineItem {
  int itemId;
  int unitId;
  String itemName;
  String unitName;
  double qtyRejected;
  String itemCondition; // good, damaged, expired, other
  String? rejectionReason;
  String? conditionNotes;
  TextEditingController qtyController = TextEditingController();
  TextEditingController reasonController = TextEditingController();
  TextEditingController conditionNotesController = TextEditingController();

  _LineItem({
    required this.itemId,
    required this.unitId,
    required this.itemName,
    required this.unitName,
    required this.qtyRejected,
    required this.itemCondition,
    this.rejectionReason,
    this.conditionNotes,
  }) {
    qtyController.text = qtyRejected.toString();
    reasonController.text = rejectionReason ?? '';
    conditionNotesController.text = conditionNotes ?? '';
  }

  void dispose() {
    qtyController.dispose();
    reasonController.dispose();
    conditionNotesController.dispose();
  }

  Map<String, dynamic> toPayload() {
    final qty = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? qtyRejected;
    return {
      'item_id': itemId,
      'unit_id': unitId,
      'qty_rejected': qty,
      'rejection_reason': reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      'item_condition': itemCondition,
      'condition_notes': conditionNotesController.text.trim().isEmpty ? null : conditionNotesController.text.trim(),
    };
  }
}

class OutletRejectionCreateScreen extends StatefulWidget {
  final int? editId;

  const OutletRejectionCreateScreen({super.key, this.editId});

  @override
  State<OutletRejectionCreateScreen> createState() => _OutletRejectionCreateScreenState();
}

class _OutletRejectionCreateScreenState extends State<OutletRejectionCreateScreen> {
  final OutletRejectionService _service = OutletRejectionService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _deliveryOrders = [];
  bool _loadingCreateData = true;
  int? _outletId;
  int? _warehouseId;
  int? _deliveryOrderId;
  String _rejectionDate = '';
  final List<_LineItem> _items = [];
  bool _saving = false;
  bool _loadingDo = false;

  static const _primary = Color(0xFF0EA5E9);

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _outletName(Map<String, dynamic> o) => o['nama_outlet']?.toString() ?? '-';
  String _warehouseName(Map<String, dynamic> w) => w['name']?.toString() ?? '-';

  @override
  void initState() {
    super.initState();
    _rejectionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateController.text = _rejectionDate;
    if (widget.editId != null) {
      _loadCreateData().then((_) => _loadEditData());
    } else {
      _loadCreateData();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _loadingCreateData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _outlets = (result['outlets'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _warehouses = (result['warehouses'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _loadingCreateData = false;
      });
    } else if (mounted) {
      setState(() => _loadingCreateData = false);
    }
  }

  Future<void> _loadEditData() async {
    if (widget.editId == null) return;
    final result = await _service.getDetail(widget.editId!);
    if (!mounted || result == null) return;
    final r = result['rejection'] ?? result;
    if (r is! Map) return;
    var outList = List<Map<String, dynamic>>.from(_outlets);
    var whList = List<Map<String, dynamic>>.from(_warehouses);
    if (r['outlet'] is Map) {
      final o = Map<String, dynamic>.from(r['outlet'] as Map);
      final id = _int(o['id_outlet']);
      if (id != null && !outList.any((e) => _int(e['id_outlet']) == id)) outList.insert(0, o);
    }
    if (r['warehouse'] is Map) {
      final w = Map<String, dynamic>.from(r['warehouse'] as Map);
      final id = _int(w['id']);
      if (id != null && !whList.any((e) => _int(e['id']) == id)) whList.insert(0, w);
    }
    setState(() {
      _outlets = outList;
      _warehouses = whList;
      _rejectionDate = r['rejection_date']?.toString().substring(0, 10) ?? _rejectionDate;
      _dateController.text = _rejectionDate;
      _outletId = _int(r['outlet_id']);
      _warehouseId = _int(r['warehouse_id']);
      _deliveryOrderId = _int(r['delivery_order_id']);
      _notesController.text = r['notes']?.toString() ?? '';
      final itemsList = r['items'];
      if (itemsList is List) {
        for (final it in itemsList) {
          final itemData = it['item'] is Map ? it['item'] as Map<String, dynamic>? : null;
          final unitData = it['unit'] is Map ? it['unit'] as Map<String, dynamic>? : null;
          _items.add(_LineItem(
            itemId: _int(it['item_id']) ?? 0,
            unitId: _int(it['unit_id']) ?? 0,
            itemName: itemData?['name']?.toString() ?? '-',
            unitName: unitData?['name']?.toString() ?? '-',
            qtyRejected: (it['qty_rejected'] is num) ? (it['qty_rejected'] as num).toDouble() : double.tryParse(it['qty_rejected']?.toString() ?? '') ?? 0,
            itemCondition: it['item_condition']?.toString() ?? 'good',
            rejectionReason: it['rejection_reason']?.toString(),
            conditionNotes: it['condition_notes']?.toString(),
          ));
        }
      }
    });
    _loadDeliveryOrders();
  }

  Future<void> _loadDeliveryOrders() async {
    if (_outletId == null || _warehouseId == null) {
      setState(() => _deliveryOrders = []);
      return;
    }
    setState(() => _loadingDo = true);
    final list = await _service.getDeliveryOrders(outletId: _outletId!, warehouseId: _warehouseId!);
    if (mounted) {
      setState(() {
        _deliveryOrders = list;
        _loadingDo = false;
      });
    }
  }

  Future<void> _loadItemsFromDeliveryOrder() async {
    if (_deliveryOrderId == null) {
      _showSnack('Pilih delivery order dulu', isError: true);
      return;
    }
    setState(() => _loadingDo = true);
    final result = await _service.getDeliveryOrderItems(_deliveryOrderId!);
    if (!mounted) return;
    setState(() => _loadingDo = false);
    if (result == null) {
      _showSnack('Gagal memuat item DO', isError: true);
      return;
    }
    final itemsRaw = result['items'] as List? ?? [];
    for (final old in _items) {
      old.dispose();
    }
    final newItems = <_LineItem>[];
    for (final it in itemsRaw) {
      final item = it is Map ? Map<String, dynamic>.from(it) : <String, dynamic>{};
      final itemData = item['item'] is Map ? item['item'] as Map<String, dynamic>? : null;
      final unitData = item['unit'] is Map ? item['unit'] as Map<String, dynamic>? : null;
      final unitId = _int(unitData?['id'] ?? item['unit_id']);
      final unitName = unitData?['name']?.toString() ?? '-';
      final qty = (item['qty'] is num) ? (item['qty'] as num).toDouble() : double.tryParse(item['remaining_qty']?.toString() ?? '0') ?? 0;
      if (qty <= 0) continue;
      final itemId = _int(item['item_id']) ?? 0;
      if (itemId == 0) continue;
      newItems.add(_LineItem(
        itemId: itemId,
        unitId: unitId ?? 0,
        itemName: itemData?['name']?.toString() ?? '-',
        unitName: unitName,
        qtyRejected: qty,
        itemCondition: 'good',
      ));
    }
    setState(() {
      _items.clear();
      _items.addAll(newItems);
    });
    _showSnack('${newItems.length} item dimuat dari DO');
  }

  Future<void> _addItemManual() async {
    if (_warehouseId == null) {
      _showSnack('Pilih outlet dan gudang dulu', isError: true);
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemSearchSheet(service: _service),
    );
    if (selected != null && mounted) {
      final itemId = _int(selected['id']) ?? 0;
      final name = selected['name']?.toString() ?? '-';
      final smallU = selected['small_unit'] ?? selected['smallUnit'];
      final mediumU = selected['medium_unit'] ?? selected['mediumUnit'];
      final largeU = selected['large_unit'] ?? selected['largeUnit'];
      final smallUnitName = smallU is Map ? smallU['name']?.toString() : smallU?.toString();
      final mediumUnitName = mediumU is Map ? mediumU['name']?.toString() : mediumU?.toString();
      final largeUnitName = largeU is Map ? largeU['name']?.toString() : largeU?.toString();
      final smallUnitId = _int(smallU is Map ? smallU['id'] : selected['small_unit_id']);
      final mediumUnitId = _int(mediumU is Map ? mediumU['id'] : selected['medium_unit_id']);
      final largeUnitId = _int(largeU is Map ? largeU['id'] : selected['large_unit_id']);
      String unitName = mediumUnitName ?? smallUnitName ?? largeUnitName ?? 'Pcs';
      int unitId = mediumUnitId ?? smallUnitId ?? largeUnitId ?? 0;
      setState(() {
        _items.add(_LineItem(
          itemId: itemId,
          unitId: unitId,
          itemName: name,
          unitName: unitName,
          qtyRejected: 1,
          itemCondition: 'good',
        ));
      });
    }
  }

  void _removeItem(int index) {
    if (index >= _items.length) return;
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : null),
    );
  }

  bool _validateForm() {
    if (_outletId == null || _warehouseId == null) {
      _showSnack('Pilih outlet dan gudang', isError: true);
      return false;
    }
    if (_items.isEmpty) {
      _showSnack('Tambahkan minimal 1 item', isError: true);
      return false;
    }
    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0) {
        _showSnack('Qty "${item.itemName}" harus > 0', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _saveDraft() async {
    if (!_validateForm()) return;
    final payloadItems = _items.map((e) => e.toPayload()).toList();
    if (widget.editId != null) {
      final result = await _service.update(
        id: widget.editId!,
        rejectionDate: _dateController.text,
        outletId: _outletId!,
        warehouseId: _warehouseId!,
        deliveryOrderId: _deliveryOrderId,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: payloadItems,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnack(result['message']?.toString() ?? 'Berhasil disimpan (draft)');
        Navigator.pop(context, true);
      } else {
        _showSnack(result['message']?.toString() ?? 'Gagal update', isError: true);
      }
      return;
    }
    setState(() => _saving = true);
    final result = await _service.store(
      rejectionDate: _dateController.text,
      outletId: _outletId!,
      warehouseId: _warehouseId!,
      deliveryOrderId: _deliveryOrderId,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: payloadItems,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      _showSnack(result['message']?.toString() ?? 'Berhasil disimpan (draft)');
      Navigator.pop(context, true);
    } else {
      _showSnack(result['message']?.toString() ?? 'Gagal menyimpan', isError: true);
    }
  }

  Future<void> _submitForApproval() async {
    if (!_validateForm()) return;
    final payloadItems = _items.map((e) => e.toPayload()).toList();
    setState(() => _saving = true);
    if (widget.editId != null) {
      final updateResult = await _service.update(
        id: widget.editId!,
        rejectionDate: _dateController.text,
        outletId: _outletId!,
        warehouseId: _warehouseId!,
        deliveryOrderId: _deliveryOrderId,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: payloadItems,
      );
      if (!mounted) return;
      if (updateResult['success'] != true) {
        setState(() => _saving = false);
        _showSnack(updateResult['message']?.toString() ?? 'Gagal update', isError: true);
        return;
      }
      final submitResult = await _service.submit(widget.editId!);
      if (!mounted) return;
      setState(() => _saving = false);
      if (submitResult['success'] == true) {
        _showSnack(submitResult['message']?.toString() ?? 'Berhasil disubmit');
        Navigator.pop(context, true);
      } else {
        _showSnack(submitResult['message']?.toString() ?? 'Gagal submit', isError: true);
      }
      return;
    }
    final storeResult = await _service.store(
      rejectionDate: _dateController.text,
      outletId: _outletId!,
      warehouseId: _warehouseId!,
      deliveryOrderId: _deliveryOrderId,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: payloadItems,
    );
    if (!mounted) return;
    if (storeResult['success'] != true) {
      setState(() => _saving = false);
      _showSnack(storeResult['message']?.toString() ?? 'Gagal menyimpan', isError: true);
      return;
    }
    final rejection = storeResult['rejection'];
    final id = rejection is Map ? (rejection['id'] is int ? rejection['id'] as int : int.tryParse(rejection['id']?.toString() ?? '')) : null;
    if (id == null) {
      setState(() => _saving = false);
      _showSnack('Data tersimpan tapi submit gagal (id tidak ditemukan)', isError: true);
      return;
    }
    final submitResult = await _service.submit(id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (submitResult['success'] == true) {
      _showSnack(submitResult['message']?.toString() ?? 'Berhasil disubmit');
      Navigator.pop(context, true);
    } else {
      _showSnack(submitResult['message']?.toString() ?? 'Gagal submit', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCreateData) {
      return AppScaffold(
        title: widget.editId != null ? 'Edit Outlet Rejection' : 'Buat Outlet Rejection',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9))),
      );
    }

    return AppScaffold(
      title: widget.editId != null ? 'Edit Outlet Rejection' : 'Buat Outlet Rejection',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              value: _outletId != null && _outlets.any((o) => _int(o['id_outlet']) == _outletId) ? _outletId : null,
              decoration: _inputDec('Outlet'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Pilih Outlet')),
                ..._outlets.map((o) => DropdownMenuItem<int>(value: _int(o['id_outlet']), child: Text(_outletName(o)))),
              ],
              onChanged: (v) {
                setState(() {
                  _outletId = v;
                  _warehouseId = _warehouseId;
                  _deliveryOrderId = null;
                  _deliveryOrders = [];
                });
                if (_outletId != null && _warehouseId != null) _loadDeliveryOrders();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _warehouseId != null && _warehouses.any((w) => _int(w['id']) == _warehouseId) ? _warehouseId : null,
              decoration: _inputDec('Gudang'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Pilih Gudang')),
                ..._warehouses.map((w) => DropdownMenuItem<int>(value: _int(w['id']), child: Text(_warehouseName(w)))),
              ],
              onChanged: (v) {
                setState(() {
                  _warehouseId = v;
                  _deliveryOrderId = null;
                  _deliveryOrders = [];
                });
                if (_outletId != null && _warehouseId != null) _loadDeliveryOrders();
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(d));
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: _dateController,
                  decoration: _inputDec('Tanggal Rejection', suffixIcon: const Icon(Icons.calendar_today, color: _primary)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_outletId != null && _warehouseId != null) ...[
              DropdownButtonFormField<int>(
                value: _deliveryOrderId != null && _deliveryOrders.any((do_) => _int(do_['id']) == _deliveryOrderId) ? _deliveryOrderId : null,
                decoration: _inputDec('Delivery Order (opsional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tanpa DO')),
                  ..._deliveryOrders.map((do_) {
                    final id = _int(do_['id']);
                    final text = do_['display_text']?.toString() ?? do_['number']?.toString() ?? 'DO $id';
                    return DropdownMenuItem<int>(value: id, child: Text(text, overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (v) => setState(() => _deliveryOrderId = v),
              ),
              const SizedBox(height: 8),
              if (_deliveryOrderId != null)
                OutlinedButton.icon(
                  onPressed: _loadingDo ? null : _loadItemsFromDeliveryOrder,
                  icon: _loadingDo ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_loadingDo ? 'Loading...' : 'Load item dari DO'),
                ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: _inputDec('Catatan (opsional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Item Rejection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addItemManual,
                  style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Item'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada item. Pilih "Load item dari DO" atau "Tambah Item".')),
              )
            else
              ...List.generate(_items.length, (i) => _buildItemRow(i)),
            const SizedBox(height: 24),
            if (_saving)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saveDraft,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simpan (Draft)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitForApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffixIcon,
    );
  }

  static const _conditions = ['good', 'damaged', 'expired', 'other'];
  static const _conditionLabels = {'good': 'Baik', 'damaged': 'Rusak', 'expired': 'Kadaluarsa', 'other': 'Lainnya'};

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            children: [
              Expanded(child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22), onPressed: () => _removeItem(index)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: item.qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Text(item.unitName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.itemCondition,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(_conditionLabels[c] ?? c))).toList(),
                  onChanged: (v) => setState(() => item.itemCondition = v ?? 'good'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: item.reasonController,
            decoration: const InputDecoration(labelText: 'Alasan (opsional)', isDense: true),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _ItemSearchSheet extends StatefulWidget {
  final OutletRejectionService service;

  const _ItemSearchSheet({required this.service});

  @override
  State<_ItemSearchSheet> createState() => _ItemSearchSheetState();
}

class _ItemSearchSheetState extends State<_ItemSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q.length >= 2) _search();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final list = await widget.service.getItems(search: _searchController.text.trim());
    if (mounted) setState(() {
      _items = list;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Cari nama atau SKU item...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _searching
                ? const Center(child: AppLoadingIndicator(size: 28, color: Color(0xFF0EA5E9)))
                : _items.isEmpty
                    ? Center(child: Text(_searchController.text.trim().length < 2 ? 'Ketik minimal 2 karakter' : 'Tidak ada hasil', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final name = item['name']?.toString() ?? '-';
                          final sku = item['sku']?.toString();
                          return ListTile(
                            title: Text(name),
                            subtitle: sku != null && sku.isNotEmpty ? Text('SKU: $sku') : null,
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
