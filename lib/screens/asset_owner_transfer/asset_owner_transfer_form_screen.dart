import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/asset_owner_transfer_service.dart';

class AssetOwnerTransferFormScreen extends StatefulWidget {
  const AssetOwnerTransferFormScreen({super.key});

  @override
  State<AssetOwnerTransferFormScreen> createState() =>
      _AssetOwnerTransferFormScreenState();
}

class _AssetOwnerTransferFormScreenState extends State<AssetOwnerTransferFormScreen> {
  static const Color _violet = Color(0xFF7C3AED);

  final _service = AssetOwnerTransferService();
  final _notesController = TextEditingController();
  final _itemSearchController = TextEditingController();
  final _approverSearchController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  List<Map<String, dynamic>> _warehousesForLocation = [];
  bool _loadingWarehouses = false;
  int? _userOutletId;

  int? _ownerFromId;
  int? _ownerToId;
  int? _locationOutletId;
  int? _warehouseOutletId;
  DateTime _transferDate = DateTime.now();

  List<Map<String, dynamic>> _selectedItems = [];
  List<Map<String, dynamic>> _itemSearchResults = [];
  bool _isSearchingItems = false;
  Timer? _itemDebounce;

  List<Map<String, dynamic>> _selectedApprovers = [];
  List<Map<String, dynamic>> _approverResults = [];
  Timer? _approverDebounce;

  @override
  void initState() {
    super.initState();
    _loadCreateData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _itemSearchController.dispose();
    _approverSearchController.dispose();
    _itemDebounce?.cancel();
    _approverDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getCreateData();
    if (!mounted) return;

    List<Map<String, dynamic>> outlets = [];
    List<Map<String, dynamic>> warehouses = [];
    int? userOutletId;

    if (result != null) {
      outlets = (result['outlets'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      warehouses = (result['warehouseOutlets'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      userOutletId = int.tryParse(result['user']?['id_outlet']?.toString() ?? '0');
    }

    if (outlets.isEmpty) {
      outlets = await _service.getOutlets();
    }
    if (warehouses.isEmpty) {
      warehouses = await _service.getAllWarehouses();
    }

    setState(() {
      _outlets = outlets;
      _warehouseOutlets = warehouses;
      _userOutletId = userOutletId;
      if (_userOutletId != null && _userOutletId != 1) {
        _ownerFromId = _userOutletId;
      }
      _isLoading = false;
    });

    if (outlets.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat daftar outlet. Periksa koneksi lalu buka ulang.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int? _parseOutletId(Map<String, dynamic> o) {
    final v = o['id_outlet'] ?? o['id'];
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  String _outletName(Map<String, dynamic> o) =>
      o['nama_outlet']?.toString() ?? o['name']?.toString() ?? '-';

  List<DropdownMenuItem<int>> get _outletDropdownItems {
    final items = <DropdownMenuItem<int>>[];
    final seen = <int>{};
    for (final o in _outlets) {
      final id = _parseOutletId(o);
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      items.add(DropdownMenuItem(
        value: id,
        child: Text(_outletName(o), style: const TextStyle(fontSize: 14)),
      ));
    }
    return items;
  }

  List<DropdownMenuItem<int>> get _ownerToDropdownItems {
    return _outletDropdownItems
        .where((d) => d.value != _ownerFromId)
        .toList();
  }

  Future<void> _loadWarehousesForOutlet(int? outletId) async {
    if (outletId == null) {
      setState(() {
        _warehousesForLocation = [];
        _warehouseOutletId = null;
      });
      return;
    }

    setState(() => _loadingWarehouses = true);

    var list = await _service.getWarehousesByOutlet(outletId);
    if (list.isEmpty) {
      list = _getWarehousesForOutlet(outletId);
    }

    if (!mounted) return;
    setState(() {
      _warehousesForLocation = list;
      _loadingWarehouses = false;
      if (_warehouseOutletId != null &&
          !list.any((w) => int.tryParse(w['id']?.toString() ?? '') == _warehouseOutletId)) {
        _warehouseOutletId = null;
      }
    });

    if (list.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada gudang untuk outlet lokasi ini.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  List<DropdownMenuItem<int>> get _warehouseDropdownItems {
    final items = <DropdownMenuItem<int>>[];
    final seen = <int>{};
    final source = _warehousesForLocation.isNotEmpty
        ? _warehousesForLocation
        : _getWarehousesForOutlet(_locationOutletId);
    for (final w in source) {
      final id = int.tryParse(w['id']?.toString() ?? '');
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      items.add(DropdownMenuItem(
        value: id,
        child: Text(w['name']?.toString() ?? '-', style: const TextStyle(fontSize: 14)),
      ));
    }
    return items;
  }

  int? _safeValue(int? value, List<DropdownMenuItem<int>> items) {
    if (value == null) return null;
    return items.any((d) => d.value == value) ? value : null;
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
    String hint = 'Pilih',
  }) {
    final enabled = items.isNotEmpty;
    return InputDecorator(
      decoration: _inputDecoration(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _safeValue(value, items),
          isExpanded: true,
          isDense: true,
          hint: Text(hint, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getWarehousesForOutlet(int? outletId) {
    if (outletId == null) return [];
    return _warehouseOutlets.where((w) {
      final wOutlet = int.tryParse(
          (w['outlet_id'] ?? w['id_outlet'] ?? w['outletId'])?.toString() ?? '');
      return wOutlet == outletId;
    }).toList();
  }

  void _onItemSearch(String query) {
    _itemDebounce?.cancel();
    if (query.length < 2 || _warehouseOutletId == null || _ownerFromId == null) {
      setState(() => _itemSearchResults = []);
      return;
    }
    _itemDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearchingItems = true);
      final results = await _service.searchItems(
        query,
        ownerOutletId: _ownerFromId!,
        warehouseOutletId: _warehouseOutletId!,
      );
      if (mounted) {
        setState(() {
          _itemSearchResults = results
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isSearchingItems = false;
        });
      }
    });
  }

  void _addItem(Map<String, dynamic> item) {
    final itemId = int.tryParse(item['id'].toString()) ?? 0;
    if (_selectedItems.any((i) => int.tryParse(i['item_id'].toString()) == itemId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item sudah ditambahkan.')),
      );
      return;
    }
    setState(() {
      _selectedItems.add({
        'item_id': itemId,
        'item_name': item['name'] ?? '',
        'sku': item['sku'] ?? '',
        'unit_id': item['small_unit_id'],
        'unit_name': item['unit_small'] ?? '-',
        'stock_small': double.tryParse(item['stock_small']?.toString() ?? '0') ?? 0,
        'qty': 0.0,
        'note': '',
        'qty_controller': TextEditingController(),
        'note_controller': TextEditingController(),
      });
      _itemSearchController.clear();
      _itemSearchResults = [];
    });
  }

  void _removeItem(int index) {
    final item = _selectedItems[index];
    (item['qty_controller'] as TextEditingController?)?.dispose();
    (item['note_controller'] as TextEditingController?)?.dispose();
    setState(() => _selectedItems.removeAt(index));
  }

  void _onApproverSearch(String query) {
    _approverDebounce?.cancel();
    _approverDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _service.searchApprovers(query);
      if (mounted) {
        setState(() {
          _approverResults = results
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    });
  }

  void _toggleApprover(Map<String, dynamic> user) {
    final userId = int.tryParse(user['id'].toString()) ?? 0;
    setState(() {
      final idx =
          _selectedApprovers.indexWhere((a) => int.tryParse(a['id'].toString()) == userId);
      if (idx >= 0) {
        _selectedApprovers.removeAt(idx);
      } else {
        _selectedApprovers.add(user);
      }
    });
  }

  bool _isApproverSelected(int userId) {
    return _selectedApprovers.any((a) => int.tryParse(a['id'].toString()) == userId);
  }

  Future<void> _pickTransferDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _transferDate = picked);
  }

  Future<void> _submitForm() async {
    if (_ownerFromId == null || _ownerToId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pemilik asal dan tujuan.')),
      );
      return;
    }
    if (_ownerFromId == _ownerToId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pemilik asal dan tujuan harus berbeda.')),
      );
      return;
    }
    if (_locationOutletId == null || _warehouseOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih lokasi outlet dan gudang.')),
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item.')),
      );
      return;
    }

    for (final item in _selectedItems) {
      final qty = double.tryParse(
              (item['qty_controller'] as TextEditingController).text) ??
          0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Qty untuk ${item['item_name']} harus > 0.')),
        );
        return;
      }
      if (qty > (item['stock_small'] as double)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Qty ${item['item_name']} melebihi stok.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final items = _selectedItems.map((item) {
      return {
        'item_id': item['item_id'],
        'unit_id': item['unit_id'],
        'qty': double.tryParse(
                (item['qty_controller'] as TextEditingController).text) ??
            0,
        'note': (item['note_controller'] as TextEditingController).text,
      };
    }).toList();

    final approverIds = _selectedApprovers
        .map((a) => int.tryParse(a['id'].toString()) ?? 0)
        .where((id) => id > 0)
        .toList();

    final dateStr =
        '${_transferDate.year}-${_transferDate.month.toString().padLeft(2, '0')}-${_transferDate.day.toString().padLeft(2, '0')}';

    final result = await _service.createTransfer(
      transferDate: dateStr,
      ownerOutletFromId: _ownerFromId!,
      ownerOutletToId: _ownerToId!,
      outletId: _locationOutletId!,
      warehouseOutletId: _warehouseOutletId!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      items: items,
      approvers: approverIds.isNotEmpty ? approverIds : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer kepemilikan berhasil dibuat.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal membuat transfer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Transfer Kepemilikan'),
        backgroundColor: _violet,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kepemilikan',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _violet)),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            label: 'Pemilik Asal *',
                            value: _ownerFromId,
                            items: _outletDropdownItems,
                            hint: 'Pilih pemilik asal',
                            onChanged: (v) => setState(() {
                              _ownerFromId = v;
                              if (_ownerToId == v) _ownerToId = null;
                              _selectedItems = [];
                              _itemSearchResults = [];
                            }),
                          ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            label: 'Pemilik Tujuan *',
                            value: _ownerToId,
                            items: _ownerToDropdownItems,
                            hint: 'Pilih pemilik tujuan',
                            onChanged: (v) => setState(() => _ownerToId = v),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Stok pindah pemilik di gudang yang sama.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lokasi & Tanggal',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _violet)),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            label: 'Outlet Lokasi *',
                            value: _locationOutletId,
                            items: _outletDropdownItems,
                            hint: 'Pilih lokasi outlet',
                            onChanged: (v) {
                              setState(() {
                                _locationOutletId = v;
                                _warehouseOutletId = null;
                                _selectedItems = [];
                                _itemSearchResults = [];
                                _warehousesForLocation = [];
                              });
                              _loadWarehousesForOutlet(v);
                            },
                          ),
                          const SizedBox(height: 8),
                          _loadingWarehouses
                              ? InputDecorator(
                                  decoration: _inputDecoration('Gudang *'),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Memuat gudang...', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                )
                              : _buildDropdown(
                                  label: 'Gudang *',
                                  value: _warehouseOutletId,
                                  items: _warehouseDropdownItems,
                                  hint: _locationOutletId == null
                                      ? 'Pilih outlet lokasi dulu'
                                      : (_warehouseDropdownItems.isEmpty
                                          ? 'Tidak ada gudang'
                                          : 'Pilih gudang'),
                                  onChanged: (v) => setState(() {
                                    _warehouseOutletId = v;
                                    _selectedItems = [];
                                    _itemSearchResults = [];
                                  }),
                                ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickTransferDate,
                            child: InputDecorator(
                              decoration: _inputDecoration('Tanggal Transfer *'),
                              child: Text(
                                '${_transferDate.year}-${_transferDate.month.toString().padLeft(2, '0')}-${_transferDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            decoration: _inputDecoration('Catatan (opsional)'),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Item Transfer',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _violet)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _itemSearchController,
                            enabled: _warehouseOutletId != null && _ownerFromId != null,
                            decoration: InputDecoration(
                              hintText: _warehouseOutletId != null && _ownerFromId != null
                                  ? 'Cari item asset...'
                                  : 'Pilih pemilik asal & gudang dulu',
                              prefixIcon: _isSearchingItems
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: _onItemSearch,
                          ),
                          if (_itemSearchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _itemSearchResults.length,
                                itemBuilder: (ctx, i) {
                                  final item = _itemSearchResults[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item['name']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(
                                      'SKU: ${item['sku'] ?? '-'} | Stok: ${item['stock_small'] ?? 0} ${item['unit_small'] ?? ''}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onTap: () => _addItem(item),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          ..._selectedItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['item_name']?.toString() ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.red),
                                        onPressed: () => _removeItem(idx),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Stok: ${item['stock_small']} ${item['unit_name']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller:
                                              item['qty_controller'] as TextEditingController,
                                          keyboardType: const TextInputType.numberWithOptions(
                                              decimal: true),
                                          decoration: _inputDecoration('Qty'),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              item['note_controller'] as TextEditingController,
                                          decoration: _inputDecoration('Catatan'),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (_selectedItems.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Belum ada item.',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Approver (opsional)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _violet)),
                          const SizedBox(height: 8),
                          if (_selectedApprovers.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _selectedApprovers.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final a = entry.value;
                                return Chip(
                                  avatar: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _violet,
                                    child: Text('${idx + 1}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 11)),
                                  ),
                                  label: Text('${a['name']} (${a['jabatan'] ?? '-'})',
                                      style: const TextStyle(fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _toggleApprover(a),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _approverSearchController,
                            decoration: InputDecoration(
                              hintText: 'Cari approver...',
                              prefixIcon: const Icon(Icons.person_search, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: _onApproverSearch,
                          ),
                          if (_approverResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _approverResults.length,
                                itemBuilder: (ctx, i) {
                                  final u = _approverResults[i];
                                  final uid = int.tryParse(u['id'].toString()) ?? 0;
                                  final selected = _isApproverSelected(uid);
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      selected ? Icons.check_box : Icons.check_box_outline_blank,
                                      color: selected ? _violet : Colors.grey,
                                      size: 20,
                                    ),
                                    title: Text(u['name']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(u['jabatan']?.toString() ?? '-',
                                        style: const TextStyle(fontSize: 11)),
                                    onTap: () => _toggleApprover(u),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Text(
                            'Isi approver untuk langsung submit. Kosongkan untuk simpan draft.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _violet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan Transfer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }
}
