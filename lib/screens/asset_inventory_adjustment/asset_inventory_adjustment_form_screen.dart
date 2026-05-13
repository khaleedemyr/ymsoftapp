import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/asset_inventory_adjustment_service.dart';

class AssetInventoryAdjustmentFormScreen extends StatefulWidget {
  const AssetInventoryAdjustmentFormScreen({super.key});

  @override
  State<AssetInventoryAdjustmentFormScreen> createState() =>
      _AssetInventoryAdjustmentFormScreenState();
}

class _AssetInventoryAdjustmentFormScreenState
    extends State<AssetInventoryAdjustmentFormScreen> {
  final _service = AssetInventoryAdjustmentService();
  final _reasonController = TextEditingController();
  final _itemSearchController = TextEditingController();
  final _approverSearchController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  int? _userOutletId;

  int? _outletId;
  int? _warehouseOutletId;
  DateTime _adjustmentDate = DateTime.now();
  String _type = 'in';

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
    _reasonController.dispose();
    _itemSearchController.dispose();
    _approverSearchController.dispose();
    _itemDebounce?.cancel();
    _approverDebounce?.cancel();
    for (final item in _selectedItems) {
      (item['qty_controller'] as TextEditingController?)?.dispose();
      (item['note_controller'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getCreateData();
    if (result != null && mounted) {
      setState(() {
        _outlets = (result['outlets'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _warehouseOutlets = (result['warehouse_outlets'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _userOutletId = int.tryParse(result['user']?['id_outlet']?.toString() ?? '0');
        if (_userOutletId != null && _userOutletId != 1) {
          _outletId = _userOutletId;
        }
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getWarehousesForOutlet(int? outletId) {
    if (outletId == null) return [];
    return _warehouseOutlets
        .where((w) => int.tryParse(w['outlet_id']?.toString() ?? '') == outletId)
        .toList();
  }

  void _onItemSearch(String query) {
    _itemDebounce?.cancel();
    if (query.length < 2 || _warehouseOutletId == null) {
      setState(() => _itemSearchResults = []);
      return;
    }
    _itemDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearchingItems = true);
      final results = await _service.searchItems(
        query,
        warehouseOutletId: _warehouseOutletId,
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
        'unit_name': item['unit_small'] ?? '-',
        'stock_small': double.tryParse(item['stock_small']?.toString() ?? '0') ?? 0,
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
      final result = await _service.getApprovers(search: query);
      if (result != null && mounted) {
        setState(() {
          _approverResults = (result['users'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    });
  }

  void _toggleApprover(Map<String, dynamic> user) {
    final userId = int.tryParse(user['id'].toString()) ?? 0;
    setState(() {
      final idx = _selectedApprovers.indexWhere(
          (a) => int.tryParse(a['id'].toString()) == userId);
      if (idx >= 0) {
        _selectedApprovers.removeAt(idx);
      } else {
        _selectedApprovers.add(user);
      }
    });
  }

  bool _isApproverSelected(int userId) {
    return _selectedApprovers
        .any((a) => int.tryParse(a['id'].toString()) == userId);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _adjustmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _adjustmentDate = picked);
  }

  Future<void> _submitForm() async {
    if (_outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet.')),
      );
      return;
    }
    if (_warehouseOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih warehouse.')),
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
    }

    setState(() => _isSubmitting = true);

    final items = _selectedItems.map((item) {
      return {
        'item_id': item['item_id'],
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
        '${_adjustmentDate.year}-${_adjustmentDate.month.toString().padLeft(2, '0')}-${_adjustmentDate.day.toString().padLeft(2, '0')}';

    final result = await _service.createAdjustment(
      date: dateStr,
      outletId: _outletId!,
      warehouseOutletId: _warehouseOutletId!,
      type: _type,
      reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
      items: items,
      approvers: approverIds.isNotEmpty ? approverIds : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adjustment berhasil dibuat.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal membuat adjustment.'),
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
        title: const Text('Buat Adjustment Asset'),
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
                  // Type Selection
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipe Adjustment',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _type = 'in'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _type == 'in' ? Colors.green : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _type == 'in' ? Colors.green.shade700 : Colors.grey.shade300,
                                        width: _type == 'in' ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.arrow_downward,
                                          color: _type == 'in' ? Colors.white : Colors.green,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock In',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: _type == 'in' ? Colors.white : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _type = 'out'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _type == 'out' ? Colors.red : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _type == 'out' ? Colors.red.shade700 : Colors.grey.shade300,
                                        width: _type == 'out' ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          color: _type == 'out' ? Colors.white : Colors.red,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock Out',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: _type == 'out' ? Colors.white : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informasi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                          const SizedBox(height: 12),
                          if (_userOutletId == 1)
                            DropdownButtonFormField<int>(
                              value: _outletId,
                              decoration: _inputDecoration('Outlet'),
                              items: _outlets.map((o) {
                                return DropdownMenuItem<int>(
                                  value: int.tryParse(o['id_outlet'].toString()),
                                  child: Text(o['nama_outlet']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() {
                                _outletId = v;
                                _warehouseOutletId = null;
                              }),
                            )
                          else
                            TextFormField(
                              initialValue: _outlets
                                      .where((o) => int.tryParse(o['id_outlet'].toString()) == _userOutletId)
                                      .map((o) => o['nama_outlet']?.toString())
                                      .firstOrNull ??
                                  '-',
                              enabled: false,
                              decoration: _inputDecoration('Outlet'),
                            ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _warehouseOutletId,
                            decoration: _inputDecoration('Warehouse'),
                            items: _getWarehousesForOutlet(_outletId).map((w) {
                              return DropdownMenuItem<int>(
                                value: int.tryParse(w['id'].toString()),
                                child: Text(w['name']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _warehouseOutletId = v),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: _inputDecoration('Tanggal'),
                              child: Text(
                                '${_adjustmentDate.year}-${_adjustmentDate.month.toString().padLeft(2, '0')}-${_adjustmentDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _reasonController,
                            decoration: _inputDecoration('Alasan'),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Item Adjustment',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _itemSearchController,
                            enabled: _warehouseOutletId != null,
                            decoration: InputDecoration(
                              hintText: _warehouseOutletId != null
                                  ? 'Cari item asset...'
                                  : 'Pilih warehouse dulu',
                              prefixIcon: _isSearchingItems
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
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
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
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
                                          controller: item['qty_controller'] as TextEditingController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: _inputDecoration('Qty'),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: item['note_controller'] as TextEditingController,
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
                                child: Text('Belum ada item.', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Approvers Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Approver',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
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
                                    backgroundColor: Colors.teal,
                                    child: Text('${idx + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11)),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                      color: selected ? Colors.teal : Colors.grey,
                                      size: 20,
                                    ),
                                    title: Text(u['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(u['jabatan']?.toString() ?? '-', style: const TextStyle(fontSize: 11)),
                                    onTap: () => _toggleApprover(u),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Text(
                            'Urutan approver = level approval (1 = pertama).',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan Adjustment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
