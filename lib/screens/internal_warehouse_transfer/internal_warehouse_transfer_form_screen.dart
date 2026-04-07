import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/internal_warehouse_transfer_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class InternalWarehouseTransferFormScreen extends StatefulWidget {
  const InternalWarehouseTransferFormScreen({super.key});

  @override
  State<InternalWarehouseTransferFormScreen> createState() => _InternalWarehouseTransferFormScreenState();
}

class _InternalWarehouseTransferFormScreenState extends State<InternalWarehouseTransferFormScreen> {
  final InternalWarehouseTransferService _service = InternalWarehouseTransferService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  List<Map<String, dynamic>> _warehouseOutletsFiltered = [];
  int? _userOutletId;

  int? _outletId;
  int? _warehouseOutletFromId;
  int? _warehouseOutletToId;
  bool _isLoading = false;
  bool _isLoadingData = true;

  final List<_TransferItemInput> _items = [];

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
        _outlets = List<Map<String, dynamic>>.from(result['outlets'] ?? []);
        _warehouseOutlets = List<Map<String, dynamic>>.from(result['warehouse_outlets'] ?? []);
        _userOutletId = result['user_outlet_id'] is int ? result['user_outlet_id'] as int : null;
        if (_userOutletId != null && _userOutletId != 1 && _outlets.isNotEmpty) {
          final firstId = _outlets.first['id_outlet'] ?? _outlets.first['id'];
          _outletId = firstId is int ? firstId : int.tryParse(firstId.toString());
        }
        _filterWarehouses();
        _isLoadingData = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  void _filterWarehouses() {
    _warehouseOutletsFiltered = _outletId == null
        ? []
        : _warehouseOutlets.where((w) => (w['outlet_id'] ?? 0) == _outletId).toList();
    if (_warehouseOutletFromId != null &&
        !_warehouseOutletsFiltered.any((w) => (w['id'] ?? 0) == _warehouseOutletFromId)) {
      _warehouseOutletFromId = null;
    }
    if (_warehouseOutletToId != null &&
        !_warehouseOutletsFiltered.any((w) => (w['id'] ?? 0) == _warehouseOutletToId)) {
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

  Future<void> _openItemSearch(int index) async {
    if (_warehouseOutletFromId == null) {
      _showMessage('Pilih warehouse asal dulu');
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
    }
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _getOutletName() {
    final list = _outlets.where((e) => (e['id_outlet'] ?? e['id']) == _outletId).toList();
    return list.isNotEmpty ? (list.first['nama_outlet']?.toString() ?? '-') : '-';
  }

  String _getWarehouseFromName() {
    final list = _warehouseOutletsFiltered.where((e) => (e['id'] ?? 0) == _warehouseOutletFromId).toList();
    return list.isNotEmpty ? (list.first['name']?.toString() ?? '-') : '-';
  }

  String _getWarehouseToName() {
    final list = _warehouseOutletsFiltered.where((e) => (e['id'] ?? 0) == _warehouseOutletToId).toList();
    return list.isNotEmpty ? (list.first['name']?.toString() ?? '-') : '-';
  }

  Future<void> _submit() async {
    if (_outletId == null || _warehouseOutletFromId == null || _warehouseOutletToId == null) {
      _showMessage('Pilih outlet & warehouse asal dan tujuan');
      return;
    }
    if (_warehouseOutletFromId == _warehouseOutletToId) {
      _showMessage('Warehouse asal dan tujuan tidak boleh sama');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty = _parseNum(item.qtyController.text.replaceAll(',', ''));
      if (item.itemId == null || qty <= 0 || item.unit == null || item.unit!.isEmpty) {
        _showMessage('Lengkapi semua item: nama, qty, unit');
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
      outletId: _outletId!,
      warehouseOutletFromId: _warehouseOutletFromId!,
      warehouseOutletToId: _warehouseOutletToId!,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      items: itemsPayload,
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
    String dateFormatted = _dateController.text;
    try {
      dateFormatted = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(_dateController.text));
    } catch (_) {}

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.preview_rounded, color: Color(0xFF0EA5E9)),
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
              _previewRow('Outlet', _getOutletName()),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            child: const Text('Simpan'),
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
      title: 'Buat Internal Warehouse Transfer',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildOutletWarehouseCard(),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildOutletWarehouseCard() {
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
            value: _outletId,
            decoration: _inputDecoration('Outlet'),
            items: _outlets.map((o) {
              final id = o['id_outlet'] ?? o['id'];
              return DropdownMenuItem<int>(
                value: id is int ? id : int.tryParse(id.toString()),
                child: Text(o['nama_outlet']?.toString() ?? '-'),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _outletId = v;
                _warehouseOutletFromId = null;
                _warehouseOutletToId = null;
                _filterWarehouses();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _warehouseOutletFromId,
            decoration: _inputDecoration('Warehouse Asal'),
            items: _warehouseOutletsFiltered.map((w) {
              return DropdownMenuItem<int>(
                value: w['id'] as int,
                child: Text(w['name']?.toString() ?? '-'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _warehouseOutletFromId = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _warehouseOutletToId,
            decoration: _inputDecoration('Warehouse Tujuan'),
            items: _warehouseOutletsFiltered.map((w) {
              return DropdownMenuItem<int>(
                value: w['id'] as int,
                child: Text(w['name']?.toString() ?? '-'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _warehouseOutletToId = v),
          ),
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
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9)),
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
          const SizedBox(height: 8),
          TextField(
            controller: item.noteController,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
          backgroundColor: const Color(0xFF0EA5E9),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const AppLoadingIndicator(size: 20, color: Colors.white)
            : const Text('Simpan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _TransferItemInput {
  int? itemId;
  String? sku;
  String? unit;
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
  final InternalWarehouseTransferService _service = InternalWarehouseTransferService();
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
                ? const Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF0EA5E9)))
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
