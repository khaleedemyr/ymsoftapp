import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/asset_service_order_service.dart';

class AssetServiceOrderFormScreen extends StatefulWidget {
  const AssetServiceOrderFormScreen({super.key});

  @override
  State<AssetServiceOrderFormScreen> createState() =>
      _AssetServiceOrderFormScreenState();
}

class _AssetServiceOrderFormScreenState
    extends State<AssetServiceOrderFormScreen> {
  final _service = AssetServiceOrderService();
  final _descController = TextEditingController();
  final _costController = TextEditingController();
  final _supplierSearchController = TextEditingController();
  final _itemSearchController = TextEditingController();
  final _approverSearchController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _outlets = [];
  List<dynamic> _warehouseOutlets = [];
  int? _userOutletId;

  int? _selectedOutletId;
  int? _selectedWarehouseId;
  String _selectedDate = '';
  String _serviceType = 'external';

  int? _selectedSupplierId;
  String? _selectedSupplierName;
  List<dynamic> _supplierResults = [];
  Timer? _supplierDebounce;

  List<Map<String, dynamic>> _items = [];
  List<dynamic> _itemResults = [];
  Timer? _itemDebounce;

  List<Map<String, dynamic>> _selectedApprovers = [];
  List<dynamic> _approverResults = [];
  Timer? _approverDebounce;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadCreateData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _costController.dispose();
    _supplierSearchController.dispose();
    _itemSearchController.dispose();
    _approverSearchController.dispose();
    _supplierDebounce?.cancel();
    _itemDebounce?.cancel();
    _approverDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final data = await _service.getCreateData();
    if (data != null && mounted) {
      setState(() {
        _outlets = data['outlets'] ?? [];
        _warehouseOutlets = data['warehouseOutlets'] ?? [];
        _userOutletId = int.tryParse(data['user']?['id_outlet']?.toString() ?? '0');
        if (_userOutletId != null && _userOutletId != 1) {
          _selectedOutletId = _userOutletId;
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredWarehouses {
    if (_selectedOutletId == null) return [];
    return _warehouseOutlets
        .where((w) =>
            int.tryParse(w['outlet_id'].toString()) == _selectedOutletId)
        .toList();
  }

  bool get _isHQ => _userOutletId == 1;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ── Supplier search ──
  void _onSupplierSearch(String val) {
    _supplierDebounce?.cancel();
    if (val.length < 2) {
      setState(() => _supplierResults = []);
      return;
    }
    _supplierDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _service.searchSuppliers(val);
      if (mounted) setState(() => _supplierResults = results);
    });
  }

  void _selectSupplier(dynamic s) {
    setState(() {
      _selectedSupplierId = int.tryParse(s['id'].toString());
      _selectedSupplierName = s['name']?.toString() ?? '';
      _supplierSearchController.clear();
      _supplierResults = [];
    });
  }

  void _clearSupplier() {
    setState(() {
      _selectedSupplierId = null;
      _selectedSupplierName = null;
    });
  }

  // ── Item search ──
  void _onItemSearch(String val) {
    _itemDebounce?.cancel();
    if (val.length < 2 || _selectedWarehouseId == null) {
      setState(() => _itemResults = []);
      return;
    }
    _itemDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _service.searchItems(val,
          warehouseOutletId: _selectedWarehouseId);
      if (mounted) setState(() => _itemResults = results);
    });
  }

  void _addItem(dynamic item) {
    final itemId = int.tryParse(item['id'].toString()) ?? 0;
    if (_items.any((i) => i['item_id'] == itemId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item sudah ditambahkan')),
      );
      return;
    }

    final units = <String>[];
    if (item['small_unit_name'] != null) units.add(item['small_unit_name']);
    if (item['medium_unit_name'] != null) units.add(item['medium_unit_name']);
    if (item['large_unit_name'] != null) units.add(item['large_unit_name']);

    setState(() {
      _items.add({
        'item_id': itemId,
        'name': item['name'] ?? '',
        'units': units,
        'selected_unit': units.isNotEmpty ? units[0] : '',
        'qty_out': 1.0,
        'note': '',
        'stock_small': item['stock_qty_small'] ?? 0,
        'stock_medium': item['stock_qty_medium'] ?? 0,
        'stock_large': item['stock_qty_large'] ?? 0,
        'small_unit_name': item['small_unit_name'] ?? '',
        'medium_unit_name': item['medium_unit_name'] ?? '',
        'large_unit_name': item['large_unit_name'] ?? '',
        'qty_controller': TextEditingController(text: '1'),
        'note_controller': TextEditingController(),
      });
      _itemSearchController.clear();
      _itemResults = [];
    });
  }

  void _removeItem(int idx) {
    setState(() => _items.removeAt(idx));
  }

  String _stockDisplay(Map<String, dynamic> item) {
    final parts = <String>[];
    final qs = item['stock_small'];
    final qm = item['stock_medium'];
    final ql = item['stock_large'];
    if (qs != null && double.tryParse(qs.toString()) != 0)
      parts.add('${qs} ${item['small_unit_name']}');
    if (qm != null && double.tryParse(qm.toString()) != 0)
      parts.add('${qm} ${item['medium_unit_name']}');
    if (ql != null && double.tryParse(ql.toString()) != 0)
      parts.add('${ql} ${item['large_unit_name']}');
    return parts.isEmpty ? '0' : parts.join(' / ');
  }

  // ── Approver search ──
  void _onApproverSearch(String val) {
    _approverDebounce?.cancel();
    if (val.length < 2) {
      setState(() => _approverResults = []);
      return;
    }
    _approverDebounce = Timer(const Duration(milliseconds: 400), () async {
      final data = await _service.getApprovers(search: val);
      if (data != null && mounted) {
        setState(() => _approverResults = data['users'] ?? []);
      }
    });
  }

  void _toggleApprover(dynamic u) {
    final uid = int.tryParse(u['id'].toString()) ?? 0;
    setState(() {
      final idx = _selectedApprovers.indexWhere((a) => a['id'] == uid);
      if (idx >= 0) {
        _selectedApprovers.removeAt(idx);
      } else {
        _selectedApprovers.add({
          'id': uid,
          'name': u['name']?.toString() ?? '',
          'jabatan': u['jabatan']?.toString() ?? '',
        });
      }
    });
  }

  bool _isApproverSelected(int uid) =>
      _selectedApprovers.any((a) => a['id'] == uid);

  void _moveApprover(int idx, int dir) {
    final newIdx = idx + dir;
    if (newIdx < 0 || newIdx >= _selectedApprovers.length) return;
    setState(() {
      final temp = _selectedApprovers[idx];
      _selectedApprovers[idx] = _selectedApprovers[newIdx];
      _selectedApprovers[newIdx] = temp;
    });
  }

  Future<void> _submit() async {
    if (_selectedOutletId == null) {
      _showError('Pilih outlet');
      return;
    }
    if (_selectedWarehouseId == null) {
      _showError('Pilih warehouse');
      return;
    }
    if (_serviceType == 'external' && _selectedSupplierId == null) {
      _showError('Pilih supplier (External)');
      return;
    }
    if (_descController.text.trim().isEmpty) {
      _showError('Isi deskripsi / alasan service');
      return;
    }
    if (_items.isEmpty) {
      _showError('Tambahkan minimal 1 item');
      return;
    }
    if (_selectedApprovers.isEmpty) {
      _showError('Tambahkan minimal 1 approver');
      return;
    }

    setState(() => _isSaving = true);

    final itemsPayload = _items.map((i) {
      final qty =
          double.tryParse((i['qty_controller'] as TextEditingController).text) ??
              0;
      return {
        'item_id': i['item_id'],
        'qty_out': qty,
        'selected_unit': i['selected_unit'],
        'note': (i['note_controller'] as TextEditingController).text,
      };
    }).toList();

    final result = await _service.createOrder(
      date: _selectedDate,
      outletId: _selectedOutletId!,
      warehouseOutletId: _selectedWarehouseId!,
      serviceType: _serviceType,
      supplierId: _serviceType == 'external' ? _selectedSupplierId : null,
      description: _descController.text.trim(),
      estimatedCost: double.tryParse(_costController.text),
      items: itemsPayload,
      approvers: _selectedApprovers.map((a) => a['id'] as int).toList(),
    );

    setState(() => _isSaving = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Service order berhasil dibuat'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } else {
      _showError(result['message'] ?? 'Gagal menyimpan');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Service Order'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOutletWarehouseDate(),
                  const SizedBox(height: 16),
                  _buildServiceTypeRow(),
                  if (_serviceType == 'external') ...[
                    const SizedBox(height: 16),
                    _buildSupplierSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildDescCost(),
                  const SizedBox(height: 16),
                  _buildItemSearch(),
                  const SizedBox(height: 8),
                  _buildItemList(),
                  const SizedBox(height: 16),
                  _buildApproverSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Service Order',
                          style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOutletWarehouseDate() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outlet & Warehouse',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (_isHQ)
              DropdownButtonFormField<int>(
                value: _selectedOutletId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Outlet', isDense: true, border: OutlineInputBorder()),
                items: _outlets
                    .map((o) => DropdownMenuItem<int>(
                        value: int.tryParse(o['id_outlet'].toString()),
                        child: Text(o['nama_outlet']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedOutletId = val;
                    _selectedWarehouseId = null;
                    _items.clear();
                  });
                },
              )
            else
              TextFormField(
                initialValue: _outlets
                        .firstWhere(
                            (o) =>
                                int.tryParse(o['id_outlet'].toString()) ==
                                _userOutletId,
                            orElse: () => {'nama_outlet': '-'})['nama_outlet']
                        ?.toString() ??
                    '-',
                readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Outlet', isDense: true, border: OutlineInputBorder()),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedWarehouseId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Warehouse', isDense: true, border: OutlineInputBorder()),
              items: _filteredWarehouses
                  .map((w) => DropdownMenuItem<int>(
                      value: int.tryParse(w['id'].toString()),
                      child: Text(w['name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedWarehouseId = val;
                  _items.clear();
                });
              },
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Tanggal', isDense: true, border: OutlineInputBorder()),
                child: Text(_selectedDate,
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTypeRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipe service *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('External'),
                  selected: _serviceType == 'external',
                  selectedColor: Colors.teal.shade100,
                  onSelected: (_) {
                    setState(() => _serviceType = 'external');
                  },
                ),
                ChoiceChip(
                  label: const Text('Internal'),
                  selected: _serviceType == 'internal',
                  selectedColor: Colors.blueGrey.shade100,
                  onSelected: (_) {
                    setState(() {
                      _serviceType = 'internal';
                      _clearSupplier();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Supplier',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (_selectedSupplierId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Colors.teal, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_selectedSupplierName ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: _clearSupplier,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _supplierSearchController,
                decoration: InputDecoration(
                  hintText: 'Cari supplier...',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: _onSupplierSearch,
              ),
              if (_supplierResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _supplierResults.length,
                    itemBuilder: (ctx, i) {
                      final s = _supplierResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(s['name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: s['code'] != null
                            ? Text(s['code'].toString(),
                                style: const TextStyle(fontSize: 11))
                            : null,
                        onTap: () => _selectSupplier(s),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescCost() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detail Service',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Deskripsi / Alasan Service *',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _costController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Estimasi Biaya',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tambah Item',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (_selectedWarehouseId == null)
              const Text('Pilih warehouse terlebih dahulu.',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
            else ...[
              TextField(
                controller: _itemSearchController,
                decoration: InputDecoration(
                  hintText: 'Cari item asset...',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: _onItemSearch,
              ),
              if (_itemResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _itemResults.length,
                    itemBuilder: (ctx, i) {
                      final item = _itemResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(item['name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${item['sku'] ?? ''} • ${item['category_name'] ?? ''}',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => _addItem(item),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item (${_items.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${idx + 1}. ${item['name']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => _removeItem(idx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    Text('Stok: ${_stockDisplay(item)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: item['selected_unit'],
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Unit',
                                isDense: true,
                                border: OutlineInputBorder()),
                            items: (item['units'] as List<String>)
                                .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u,
                                        style:
                                            const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (val) {
                              setState(() => item['selected_unit'] = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: item['qty_controller'],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Qty',
                                isDense: true,
                                border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: item['note_controller'],
                      decoration: InputDecoration(
                        hintText: 'Catatan...',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 12),
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

  Widget _buildApproverSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approver',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _approverSearchController,
              decoration: InputDecoration(
                hintText: 'Cari approver...',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: _onApproverSearch,
            ),
            if (_approverResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                margin: const EdgeInsets.only(top: 4),
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
                    return CheckboxListTile(
                      dense: true,
                      value: selected,
                      title: Text(u['name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(u['jabatan']?.toString() ?? '',
                          style: const TextStyle(fontSize: 11)),
                      onChanged: (_) => _toggleApprover(u),
                    );
                  },
                ),
              ),
            if (_selectedApprovers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedApprovers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final a = entry.value;
                  return Chip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.teal,
                      child: Text('${idx + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                    label: Text('${a['name']}',
                        style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _selectedApprovers.removeAt(idx));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Urutan: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ...List.generate(_selectedApprovers.length, (i) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 14),
                            onPressed: () => _moveApprover(i, -1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        Text('${i + 1}. ${_selectedApprovers[i]['name']}  ',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
