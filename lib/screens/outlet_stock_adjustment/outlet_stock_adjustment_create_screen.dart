import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_stock_adjustment_models.dart';
import '../../services/auth_service.dart';
import '../../services/outlet_stock_adjustment_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletStockAdjustmentCreateScreen extends StatefulWidget {
  const OutletStockAdjustmentCreateScreen({super.key});

  @override
  State<OutletStockAdjustmentCreateScreen> createState() => _OutletStockAdjustmentCreateScreenState();
}

class _OutletStockAdjustmentCreateScreenState extends State<OutletStockAdjustmentCreateScreen> {
  final OutletStockAdjustmentService _service = OutletStockAdjustmentService();
  final AuthService _authService = AuthService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingOutlets = true;
  bool _outletSelectable = true;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];

  int? _outletId;
  String? _outletName;
  int? _regionId;
  int? _warehouseOutletId;
  String? _type;

  final List<_AdjustmentItemInput> _items = [];
  final List<OutletStockAdjustmentApprover> _approvers = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _items.add(_AdjustmentItemInput());
    _loadUserAndOutlets();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _reasonController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserAndOutlets() async {
    setState(() {
      _isLoadingOutlets = true;
    });

    try {
      final userData = await _authService.getUserData();
      final rawOutletId = userData?['id_outlet'];
      _outletId = _parseInt(rawOutletId);
      _outletName = userData?['outlet']?['nama_outlet']?.toString() ??
          userData?['outlet_name']?.toString() ??
          userData?['nama_outlet']?.toString();

      _outletSelectable = _outletId == null || _outletId == 1;
      if (_outletSelectable) {
        _outlets = await _service.getOutlets();
      }

      if (!_outletSelectable && _outletId != null) {
        await _loadOutletDetail(_outletId!);
        await _loadWarehouseOutlets(_outletId!);
      }
    } catch (e) {
      print('Error loading outlet data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOutlets = false;
        });
      }
    }
  }

  Future<void> _loadOutletDetail(int outletId) async {
    final detail = await _service.getOutletDetail(outletId);
    if (detail != null) {
      final outlet = detail['outlet'] as Map<String, dynamic>?;
      _regionId = _parseInt(detail['region_id'] ?? outlet?['region_id']);
      _outletName = outlet?['nama_outlet']?.toString() ?? _outletName;
    }
  }

  Future<void> _loadWarehouseOutlets(int outletId) async {
    final warehouses = await _service.getWarehouseOutlets(outletId);
    if (mounted) {
      setState(() {
        _warehouseOutlets = warehouses;
      });
    }
  }

  void _onOutletChanged(int? value) {
    setState(() {
      _outletId = value;
      _warehouseOutletId = null;
      _warehouseOutlets = [];
      _regionId = null;
      _resetItems();
    });

    if (value != null) {
      _loadOutletDetail(value);
      _loadWarehouseOutlets(value);
    }
  }

  void _resetItems() {
    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..add(_AdjustmentItemInput());
  }

  void _addItem() {
    setState(() {
      _items.add(_AdjustmentItemInput());
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  Future<void> _openItemSearch(int index) async {
    if (_outletId == null) {
      _showMessage('Pilih outlet terlebih dahulu');
      return;
    }
    if (_warehouseOutletId == null) {
      _showMessage('Pilih warehouse outlet terlebih dahulu');
      return;
    }
    if (_regionId == null) {
      _showMessage('Region outlet belum tersedia');
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ItemSearchModal(
          outletId: _outletId!,
          regionId: _regionId!,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        final item = _items[index];
        item.itemId = _parseInt(selected['id']);
        item.nameController.text = selected['name']?.toString() ?? '';
        item.sku = selected['sku']?.toString();
        final units = <String>{};
        for (final unit in [
          selected['unit_small'],
          selected['unit_medium'],
          selected['unit_large'],
        ]) {
          if (unit is String && unit.isNotEmpty) {
            units.add(unit);
          }
        }
        item.availableUnits = units.toList();
        item.unit = item.availableUnits.isNotEmpty ? item.availableUnits.first : null;
        item.unitController.text = item.unit ?? '';
      });
    }
  }

  Future<void> _openApproverSearch() async {
    final selected = await showModalBottomSheet<OutletStockAdjustmentApprover>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _ApproverSearchModal();
      },
    );

    if (selected != null) {
      final exists = _approvers.any((approver) => approver.id == selected.id);
      if (!exists) {
        setState(() {
          _approvers.add(selected);
        });
      }
    }
  }

  void _moveApprover(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _approvers.length) return;
    setState(() {
      final item = _approvers.removeAt(fromIndex);
      _approvers.insert(toIndex, item);
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    if (_dateController.text.isEmpty || _outletId == null || _warehouseOutletId == null || _type == null || _reasonController.text.isEmpty) {
      _showMessage('Semua field wajib diisi');
      return;
    }

    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '')) ?? 0;
      if (item.itemId == null || qty <= 0 || item.unit == null || item.unit!.isEmpty) {
        _showMessage('Setiap item wajib diisi dengan qty dan unit');
        return;
      }
    }

    if (_approvers.isEmpty) {
      _showMessage('Approver wajib diisi minimal 1 orang');
      return;
    }

    await _showPreview();
  }

  Future<void> _submitConfirmed() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final itemsPayload = _items.map((item) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '')) ?? 0;
      return {
        'item_id': item.itemId,
        'qty': qty,
        'selected_unit': item.unit,
        if (item.noteController.text.isNotEmpty) 'note': item.noteController.text,
      };
    }).toList();

    final approverIds = _approvers.map((e) => e.id).toList();

    final result = await _service.createAdjustment(
      date: _dateController.text,
      outletId: _outletId!,
      warehouseOutletId: _warehouseOutletId!,
      type: _type!,
      reason: _reasonController.text,
      items: itemsPayload,
      approvers: approverIds,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true) {
      _showMessage('Outlet stock adjustment berhasil disimpan', success: true);
      Navigator.pop(context, true);
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal menyimpan data');
    }
  }

  Future<void> _showPreview() async {
    final outletName = _outletName ?? _outlets
        .firstWhere(
          (o) => _parseInt(o['id_outlet'] ?? o['id']) == _outletId,
          orElse: () => {'nama_outlet': '-', 'name': '-'},
        )['nama_outlet']?.toString() ??
        _outlets
            .firstWhere(
              (o) => _parseInt(o['id_outlet'] ?? o['id']) == _outletId,
              orElse: () => {'nama_outlet': '-', 'name': '-'},
            )['name']?.toString() ??
        '-';

    final warehouseName = _warehouseOutlets
        .firstWhere(
          (wo) => _parseInt(wo['id']) == _warehouseOutletId,
          orElse: () => {'name': '-'},
        )['name']?.toString() ??
        '-';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.visibility, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Preview Adjustment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPreviewSection(
                          title: 'Informasi',
                          child: Column(
                            children: [
                              _buildPreviewRow('Tanggal', _dateController.text),
                              _buildPreviewRow('Outlet', outletName),
                              _buildPreviewRow('Warehouse', warehouseName),
                              _buildPreviewRow('Tipe', _type == 'in' ? 'Stock In' : 'Stock Out'),
                              _buildPreviewRow('Alasan', _reasonController.text),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewSection(
                          title: 'Items (${_items.length})',
                          child: Column(
                            children: _items.map((item) {
                              final qty = item.qtyController.text.isNotEmpty
                                  ? item.qtyController.text
                                  : '0';
                              final unit = item.unit ?? item.unitController.text;
                              final note = item.noteController.text;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nameController.text.isNotEmpty
                                          ? item.nameController.text
                                          : '-',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _previewPill('Qty', '$qty ${unit ?? '-'}'),
                                        if (note.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          _previewPill('Note', note),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewSection(
                          title: 'Approvers (${_approvers.length})',
                          child: Column(
                            children: _approvers.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final approver = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'L$index',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6366F1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            approver.name,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          if (approver.jabatan != null && approver.jabatan!.isNotEmpty)
                                            Text(
                                              approver.jabatan!,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await _submitConfirmed();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Outlet Stock Adjustment',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildOutletCard(),
            const SizedBox(height: 16),
            _buildItemsCard(),
            const SizedBox(height: 16),
            _buildApproverCard(),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(_dateController.text),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            },
            child: AbsorbPointer(
              child: TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: InputDecoration(
              labelText: 'Tipe Adjustment',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'in', child: Text('Stock In')),
              DropdownMenuItem(value: 'out', child: Text('Stock Out')),
            ],
            onChanged: (value) {
              setState(() {
                _type = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Alasan / Catatan',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outlet & Warehouse',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _isLoadingOutlets
              ? const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)))
              : Column(
                  children: [
                    _outletSelectable
                        ? DropdownButtonFormField<int>(
                            value: _outletId,
                            decoration: InputDecoration(
                              labelText: 'Outlet',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: _outlets
                                .map((outlet) {
                                  final id = _parseInt(outlet['id_outlet'] ?? outlet['id']);
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text(outlet['nama_outlet']?.toString() ?? outlet['name']?.toString() ?? '-'),
                                  );
                                })
                                .where((item) => item.value != null)
                                .toList(),
                            onChanged: _onOutletChanged,
                          )
                        : InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Outlet',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            child: Text(
                              _outletName ?? '-',
                              style: const TextStyle(color: Color(0xFF475569)),
                            ),
                          ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _warehouseOutletId,
                      decoration: InputDecoration(
                        labelText: 'Warehouse Outlet',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _warehouseOutlets
                          .map((wo) => DropdownMenuItem<int>(
                                value: _parseInt(wo['id']),
                                child: Text(wo['name']?.toString() ?? '-'),
                              ))
                          .toList(),
                      onChanged: _outletId == null
                          ? null
                          : (value) {
                              setState(() {
                                _warehouseOutletId = value;
                              });
                            },
                    ),
                  ],
                ),
          if (_outletSelectable && _outletId == null) ...[
            const SizedBox(height: 12),
            _buildWarning('Pilih outlet terlebih dahulu sebelum menambahkan item'),
          ] else if (_outletId != null && _warehouseOutletId == null) ...[
            const SizedBox(height: 12),
            _buildWarning('Pilih warehouse outlet terlebih dahulu sebelum menambahkan item'),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Item Adjustment',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildItemRow(item, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildItemRow(_AdjustmentItemInput item, int index) {
    final canSearch = _outletId != null && _warehouseOutletId != null;

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
                  onTap: canSearch ? () => _openItemSearch(index) : null,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: item.nameController,
                      decoration: InputDecoration(
                        labelText: 'Pilih Item',
                        suffixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeItem(index),
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          if (item.sku != null && item.sku!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
          ],
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: item.availableUnits.isNotEmpty
                    ? DropdownButtonFormField<String>(
                        value: item.availableUnits.contains(item.unit) ? item.unit : null,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: item.availableUnits
                            .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            item.unit = value;
                            item.unitController.text = value ?? '';
                          });
                        },
                      )
                    : TextField(
                        controller: item.unitController,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) => item.unit = value,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.noteController,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Approval Flow',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _openApproverSearch,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Tambah'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoBox(
            'Catatan: Tambahkan Nama Regional dan Cost Control Manager sebagai approver.',
          ),
          const SizedBox(height: 12),
          if (_approvers.isEmpty)
            Text(
              'Belum ada approver',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            ..._approvers.asMap().entries.map((entry) {
              final index = entry.key;
              final approver = entry.value;
              return _buildApproverRow(approver, index);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildApproverRow(OutletStockAdjustmentApprover approver, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(
                'Level ${index + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
              IconButton(
                onPressed: index > 0 ? () => _moveApprover(index, index - 1) : null,
                icon: const Icon(Icons.keyboard_arrow_up),
                color: const Color(0xFF6366F1),
              ),
              IconButton(
                onPressed: index < _approvers.length - 1 ? () => _moveApprover(index, index + 1) : null,
                icon: const Icon(Icons.keyboard_arrow_down),
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approver.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                if (approver.email != null && approver.email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(approver.email!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                if (approver.jabatan != null && approver.jabatan!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(approver.jabatan!, style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _approvers.removeAt(index);
              });
            },
            icon: const Icon(Icons.close),
            color: const Color(0xFFEF4444),
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
            : const Text('Simpan Adjustment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentItemInput {
  int? itemId;
  String? sku;
  String? unit;
  List<String> availableUnits = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController unitController = TextEditingController();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    noteController.dispose();
    unitController.dispose();
  }
}

class _ItemSearchModal extends StatefulWidget {
  final int outletId;
  final int regionId;

  const _ItemSearchModal({required this.outletId, required this.regionId});

  @override
  State<_ItemSearchModal> createState() => _ItemSearchModalState();
}

class _ItemSearchModalState extends State<_ItemSearchModal> {
  final OutletStockAdjustmentService _service = OutletStockAdjustmentService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadItems('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadItems(String query) async {
    setState(() {
      _isLoading = true;
    });

    final results = await _service.searchItems(
      query: query,
      outletId: widget.outletId,
      regionId: widget.regionId,
    );
    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pilih Item',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari nama item atau SKU...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                _searchTimer?.cancel();
                setState(() {
                  _isLoading = true;
                });
                _searchTimer = Timer(const Duration(milliseconds: 500), () {
                  _loadItems(value);
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada item ditemukan',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, itemIndex) {
                          final item = _items[itemIndex];
                          return InkWell(
                            onTap: () => Navigator.pop(context, item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6366F1), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name']?.toString() ?? '-',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['sku']?.toString() ?? '-',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ApproverSearchModal extends StatefulWidget {
  const _ApproverSearchModal();

  @override
  State<_ApproverSearchModal> createState() => _ApproverSearchModalState();
}

class _ApproverSearchModalState extends State<_ApproverSearchModal> {
  final OutletStockAdjustmentService _service = OutletStockAdjustmentService();
  final TextEditingController _searchController = TextEditingController();
  List<OutletStockAdjustmentApprover> _approvers = [];
  bool _isLoading = false;
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadApprovers(String query) async {
    if (query.length < 2) {
      setState(() {
        _approvers = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final results = await _service.getApprovers(query);
    if (mounted) {
      setState(() {
        _approvers = results
            .map((item) => OutletStockAdjustmentApprover.fromJson(item))
            .toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pilih Approver',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari nama, email, atau jabatan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 400), () {
                  _loadApprovers(value);
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _approvers.isEmpty
                    ? Center(
                        child: Text(
                          'Masukkan minimal 2 karakter untuk mencari',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _approvers.length,
                        itemBuilder: (context, index) {
                          final approver = _approvers[index];
                          return InkWell(
                            onTap: () => Navigator.pop(context, approver),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    approver.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  if (approver.email != null && approver.email!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      approver.email!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                  if (approver.jabatan != null && approver.jabatan!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      approver.jabatan!,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
