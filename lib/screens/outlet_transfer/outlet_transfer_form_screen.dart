import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_transfer_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletTransferFormScreen extends StatefulWidget {
  const OutletTransferFormScreen({super.key});

  @override
  State<OutletTransferFormScreen> createState() => _OutletTransferFormScreenState();
}

class _OutletTransferFormScreenState extends State<OutletTransferFormScreen> {
  final OutletTransferService _service = OutletTransferService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _outletsFrom = [];
  List<Map<String, dynamic>> _outletsTo = [];
  List<Map<String, dynamic>> _warehouseOutletsFrom = [];
  List<Map<String, dynamic>> _warehouseOutletsTo = [];
  List<Map<String, dynamic>> _warehouseOutletsFromFiltered = [];
  List<Map<String, dynamic>> _warehouseOutletsToFiltered = [];
  int? _userOutletId;

  int? _outletFromId;
  int? _outletToId;
  int? _warehouseOutletFromId;
  int? _warehouseOutletToId;
  bool _isLoading = false;
  bool _isLoadingData = true;

  final List<_TransferItemInput> _items = [];
  final List<Map<String, dynamic>> _approvers = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _items.add(_TransferItemInput());
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoadingData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _outletsFrom = List<Map<String, dynamic>>.from(result['outlets_from'] ?? []);
        _outletsTo = List<Map<String, dynamic>>.from(result['outlets_to'] ?? []);
        _warehouseOutletsFrom = List<Map<String, dynamic>>.from(result['warehouse_outlets_from'] ?? []);
        _warehouseOutletsTo = List<Map<String, dynamic>>.from(result['warehouse_outlets_to'] ?? []);
        _userOutletId = result['user_outlet_id'] is int ? result['user_outlet_id'] as int : null;
        if (_userOutletId != null && _userOutletId != 1 && _outletsFrom.isNotEmpty) {
          _outletFromId = _outletsFrom.first['id_outlet'] ?? _outletsFrom.first['id'];
        }
        _filterWarehouses();
        _isLoadingData = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  void _filterWarehouses() {
    _warehouseOutletsFromFiltered = _outletFromId == null
        ? []
        : _warehouseOutletsFrom.where((w) => (w['outlet_id'] ?? w['id']) == _outletFromId).toList();
    _warehouseOutletsToFiltered = _outletToId == null
        ? []
        : _warehouseOutletsTo.where((w) => (w['outlet_id'] ?? w['id']) == _outletToId).toList();
    if (_warehouseOutletFromId != null &&
        !_warehouseOutletsFromFiltered.any((w) => (w['id'] ?? 0) == _warehouseOutletFromId)) {
      _warehouseOutletFromId = null;
    }
    if (_warehouseOutletToId != null &&
        !_warehouseOutletsToFiltered.any((w) => (w['id'] ?? 0) == _warehouseOutletToId)) {
      _warehouseOutletToId = null;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _addItem() {
    setState(() => _items.add(_TransferItemInput()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _loadStock(int index) async {
    if (_warehouseOutletFromId == null || _items[index].itemId == null) return;
    final stock = await _service.getStock(
      itemId: _items[index].itemId!,
      warehouseOutletId: _warehouseOutletFromId!,
    );
    if (mounted) setState(() => _items[index].stock = stock);
  }

  Future<void> _openItemSearch(int index) async {
    if (_warehouseOutletFromId == null) {
      _showMessage('Pilih warehouse outlet asal dulu');
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemSearchModal(warehouseOutletId: _warehouseOutletFromId!),
    );
    if (selected != null && mounted) {
      setState(() {
        _items[index].itemId = selected['id'] as int;
        _items[index].nameController.text = selected['name']?.toString() ?? '';
        _items[index].sku = selected['sku']?.toString();
        final units = <String>{};
        for (final u in [selected['unit_small'], selected['unit_medium'], selected['unit_large']]) {
          if (u is String && u.isNotEmpty) units.add(u);
        }
        _items[index].availableUnits = units.toList();
        _items[index].unit = _items[index].availableUnits.isNotEmpty ? _items[index].availableUnits.first : null;
      });
      await _loadStock(index);
    }
  }

  double? _getAvailableStock(_TransferItemInput item) {
    if (item.stock == null || item.unit == null) return null;
    final s = item.stock!;
    if (item.unit == s['unit_small']) return _parseNum(s['qty_small']);
    if (item.unit == s['unit_medium']) return _parseNum(s['qty_medium']);
    if (item.unit == s['unit_large']) return _parseNum(s['qty_large']);
    return null;
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _getOutletFromName() {
    final list = _outletsFrom.where((e) => (e['id_outlet'] ?? e['id']) == _outletFromId).toList();
    return list.isNotEmpty ? (list.first['nama_outlet']?.toString() ?? '-') : '-';
  }

  String _getOutletToName() {
    final list = _outletsTo.where((e) => (e['id_outlet'] ?? e['id']) == _outletToId).toList();
    return list.isNotEmpty ? (list.first['nama_outlet']?.toString() ?? '-') : '-';
  }

  String _getWarehouseFromName() {
    final list = _warehouseOutletsFromFiltered.where((e) => (e['id'] ?? 0) == _warehouseOutletFromId).toList();
    return list.isNotEmpty ? (list.first['name']?.toString() ?? '-') : '-';
  }

  String _getWarehouseToName() {
    final list = _warehouseOutletsToFiltered.where((e) => (e['id'] ?? 0) == _warehouseOutletToId).toList();
    return list.isNotEmpty ? (list.first['name']?.toString() ?? '-') : '-';
  }

  Future<void> _submit() async {
    if (_outletFromId == null || _warehouseOutletFromId == null || _outletToId == null || _warehouseOutletToId == null) {
      _showMessage('Pilih outlet & warehouse asal dan tujuan');
      return;
    }
    if (_warehouseOutletFromId == _warehouseOutletToId) {
      _showMessage('Warehouse asal dan tujuan tidak boleh sama');
      return;
    }
    if (_approvers.isEmpty) {
      _showMessage('Pilih minimal 1 approver');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty = _parseNum(item.qtyController.text.replaceAll(',', ''));
      if (item.itemId == null || qty <= 0 || item.unit == null || item.unit!.isEmpty) {
        _showMessage('Lengkapi semua item: nama, qty, unit');
        return;
      }
      final stock = _getAvailableStock(item);
      if (stock != null && qty > stock) {
        _showMessage('Qty "${item.nameController.text}" melebihi stok ($stock)');
        return;
      }
      itemsPayload.add({
        'item_id': item.itemId,
        'qty': qty,
        'unit': item.unit,
        if (item.noteController.text.isNotEmpty) 'note': item.noteController.text,
      });
    }

    final confirmed = await _showPreviewDialog(itemsPayload);
    if (confirmed != true || !mounted) return;
    await _doSubmit(itemsPayload);
  }

  Future<void> _doSubmit(List<Map<String, dynamic>> itemsPayload) async {
    setState(() => _isLoading = true);
    final result = await _service.createTransfer(
      transferDate: _dateController.text,
      outletFromId: _outletFromId!,
      warehouseOutletFromId: _warehouseOutletFromId!,
      outletToId: _outletToId!,
      warehouseOutletToId: _warehouseOutletToId!,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      items: itemsPayload,
      approvers: _approvers.map((a) => a['id'] as int).toList(),
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        _showMessage(result['message']?.toString() ?? 'Berhasil disimpan', success: true);
        Navigator.pop(context, true);
      } else {
        _showMessage(result['message']?.toString() ?? 'Gagal menyimpan');
      }
    }
  }

  Future<bool?> _showPreviewDialog(List<Map<String, dynamic>> itemsPayload) async {
    final dateStr = _dateController.text;
    String dateFormatted = dateStr;
    try {
      dateFormatted = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(dateStr));
    } catch (_) {}

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.preview_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Preview'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _previewRow('Tanggal', dateFormatted),
              const SizedBox(height: 10),
              const Text('Outlet & Gudang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              _previewRow('Dari Outlet', _getOutletFromName()),
              _previewRow('Ke Outlet', _getOutletToName()),
              _previewRow('Dari Gudang', _getWarehouseFromName()),
              _previewRow('Ke Gudang', _getWarehouseToName()),
              if (_notesController.text.isNotEmpty) _previewRow('Keterangan', _notesController.text),
              const SizedBox(height: 12),
              const Text('Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ..._items.asMap().entries.map((e) {
                final i = e.value;
                final qty = i.qtyController.text.replaceAll(',', '');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${i.nameController.text} — $qty ${i.unit ?? ""}${i.noteController.text.isNotEmpty ? " (${i.noteController.text})" : ""}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Text('Approver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ..._approvers.asMap().entries.map((e) {
                final idx = e.key + 1;
                final name = e.value['nama_lengkap']?.toString() ?? e.value['name']?.toString() ?? '-';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('$idx. $name', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Simpan & Submit'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showMessage(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Pindah Outlet',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildOutletsCard(),
                  const SizedBox(height: 16),
                  _buildApproversCard(),
                  const SizedBox(height: 16),
                  _buildItemsCard(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _selectDate,
            child: AbsorbPointer(
              child: TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Tanggal Transfer',
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Keterangan (opsional)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outlet & Warehouse', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _outletFromId,
            decoration: _inputDecoration('Outlet Asal'),
            items: _outletsFrom.map((o) {
              final id = o['id_outlet'] ?? o['id'];
              return DropdownMenuItem<int>(value: id is int ? id : int.tryParse(id.toString()), child: Text(o['nama_outlet']?.toString() ?? '-'));
            }).toList(),
            onChanged: (v) {
              setState(() {
                _outletFromId = v;
                _warehouseOutletFromId = null;
                _filterWarehouses();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _warehouseOutletFromId,
            decoration: _inputDecoration('Warehouse Outlet Asal'),
            items: _warehouseOutletsFromFiltered.map((w) {
              return DropdownMenuItem<int>(value: w['id'] as int, child: Text(w['name']?.toString() ?? '-'));
            }).toList(),
            onChanged: (v) {
              setState(() => _warehouseOutletFromId = v);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _outletToId,
            decoration: _inputDecoration('Outlet Tujuan'),
            items: _outletsTo.map((o) {
              final id = o['id_outlet'] ?? o['id'];
              return DropdownMenuItem<int>(value: id is int ? id : int.tryParse(id.toString()), child: Text(o['nama_outlet']?.toString() ?? '-'));
            }).toList(),
            onChanged: (v) {
              setState(() {
                _outletToId = v;
                _warehouseOutletToId = null;
                _filterWarehouses();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _warehouseOutletToId,
            decoration: _inputDecoration('Warehouse Outlet Tujuan'),
            items: _warehouseOutletsToFiltered.map((w) {
              return DropdownMenuItem<int>(value: w['id'] as int, child: Text(w['name']?.toString() ?? '-'));
            }).toList(),
            onChanged: (v) => setState(() => _warehouseOutletToId = v),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildApproversCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approvers (min. 1)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final list = await Navigator.push<List<Map<String, dynamic>>>(
                context,
                MaterialPageRoute(
                  builder: (context) => _ApproverSelectScreen(selected: List.from(_approvers)),
                ),
              );
              if (list != null && mounted) setState(() => _approvers
                ..clear()
                ..addAll(list));
            },
            icon: const Icon(Icons.person_add),
            label: Text(_approvers.isEmpty ? 'Pilih Approver' : '${_approvers.length} approver dipilih'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              side: const BorderSide(color: Color(0xFF6366F1)),
            ),
          ),
          if (_approvers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _approvers.asMap().entries.map((e) {
                return Chip(
                  label: Text(e.value['name']?.toString() ?? e.value['nama_lengkap']?.toString() ?? ''),
                  onDeleted: () => setState(() => _approvers.removeAt(e.key)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Item Transfer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
              ),
            ],
          ),
          ...List.generate(_items.length, (i) => _buildItemRow(_items[i], i)),
        ],
      ),
    );
  }

  Widget _buildItemRow(_TransferItemInput item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openItemSearch(index),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: item.nameController,
                      decoration: InputDecoration(
                        labelText: 'Pilih Item',
                        suffixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeItem(index),
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          if (item.sku != null && item.sku!.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.availableUnits.contains(item.unit) ? item.unit : null,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: item.availableUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => item.unit = v),
                ),
              ),
            ],
          ),
          if (item.stock != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Stok: ${_parseNum(item.stock!['qty_small'])} ${item.stock!['unit_small']} | ${_parseNum(item.stock!['qty_medium'])} ${item.stock!['unit_medium']} | ${_parseNum(item.stock!['qty_large'])} ${item.stock!['unit_large']}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const AppLoadingIndicator(size: 20, color: Colors.white)
            : const Text('Simpan & Submit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _TransferItemInput {
  int? itemId;
  String? sku;
  String? unit;
  Map<String, dynamic>? stock;
  List<String> availableUnits = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    noteController.dispose();
  }
}

class _ItemSearchModal extends StatefulWidget {
  final int warehouseOutletId;

  const _ItemSearchModal({required this.warehouseOutletId});

  @override
  State<_ItemSearchModal> createState() => _ItemSearchModalState();
}

class _ItemSearchModalState extends State<_ItemSearchModal> {
  final OutletTransferService _service = OutletTransferService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onSearch() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      _load(_searchController.text);
    });
  }

  Future<void> _load(String q) async {
    if (q.length < 2) {
      setState(() => _items = []);
      return;
    }
    setState(() => _isLoading = true);
    final res = await _service.searchItems(q, warehouseOutletId: widget.warehouseOutletId);
    if (mounted) setState(() {
      _items = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari item (min. 2 karakter)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      return ListTile(
                        title: Text(it['name']?.toString() ?? '-'),
                        subtitle: Text('SKU: ${it['sku'] ?? '-'}'),
                        onTap: () => Navigator.pop(context, it),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApproverSelectScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selected;

  const _ApproverSelectScreen({required this.selected});

  @override
  State<_ApproverSelectScreen> createState() => _ApproverSelectScreenState();
}

class _ApproverSelectScreenState extends State<_ApproverSelectScreen> {
  final OutletTransferService _service = OutletTransferService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _selected = [];
  bool _isLoading = false;

  int? _userId(Map<String, dynamic> user) {
    final v = user['id'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  bool _isUserSelected(Map<String, dynamic> u) {
    final id = _userId(u);
    if (id == null) return false;
    return _selected.any((s) => _userId(s) == id);
  }

  void _toggleUser(Map<String, dynamic> u, bool selected) {
    final id = _userId(u);
    if (id == null) return;
    if (selected) {
      if (!_selected.any((s) => _userId(s) == id)) {
        _selected.add(Map<String, dynamic>.from(u));
      }
    } else {
      _selected.removeWhere((s) => _userId(s) == id);
    }
  }

  void _returnSelected() {
    Navigator.pop(context, List<Map<String, dynamic>>.from(_selected));
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.selected.map((e) => Map<String, dynamic>.from(e)).toList();
    _loadApprovers('');
  }

  Future<void> _loadApprovers(String q) async {
    setState(() => _isLoading = true);
    final res = await _service.getApprovers(search: q.isEmpty ? null : q);
    if (mounted) setState(() {
      _users = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _returnSelected();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pilih Approver'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _returnSelected,
          ),
          actions: [
            TextButton(
              onPressed: _returnSelected,
              child: const Text('Selesai'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama / jabatan',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: _loadApprovers,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        final name = u['name']?.toString() ?? u['nama_lengkap']?.toString() ?? '-';
                        final jabatan = u['jabatan']?.toString() ?? '';
                        final isSelected = _isUserSelected(u);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(name),
                          subtitle: jabatan.isNotEmpty ? Text(jabatan) : null,
                          onChanged: (v) {
                            setState(() => _toggleUser(u, v == true));
                          },
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
