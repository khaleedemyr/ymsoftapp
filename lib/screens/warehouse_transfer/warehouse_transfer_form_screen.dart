import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../services/warehouse_transfer_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseTransferFormScreen extends StatefulWidget {
  const WarehouseTransferFormScreen({super.key});

  @override
  State<WarehouseTransferFormScreen> createState() => _WarehouseTransferFormScreenState();
}

class _WarehouseTransferFormScreenState extends State<WarehouseTransferFormScreen> {
  final WarehouseTransferService _service = WarehouseTransferService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  int? _warehouseFromId;
  int? _warehouseToId;
  bool _isLoading = false;
  bool _isLoadingWarehouses = true;

  final List<_TransferItemInput> _items = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _items.add(_TransferItemInput());
    _loadWarehouses();
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

  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoadingWarehouses = true;
    });
    final warehouses = await _service.getWarehouses();
    if (mounted) {
      setState(() {
        _warehouses = warehouses;
        _isLoadingWarehouses = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
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
  }

  void _addItem() {
    setState(() {
      _items.add(_TransferItemInput());
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  void _swapWarehouses() {
    if (_warehouseFromId == null && _warehouseToId == null) return;
    setState(() {
      final temp = _warehouseFromId;
      _warehouseFromId = _warehouseToId;
      _warehouseToId = temp;
    });
    _refreshAllStocks();
  }

  Future<void> _refreshAllStocks() async {
    if (_warehouseFromId == null) return;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].itemId != null) {
        await _loadStock(i);
      }
    }
  }

  Future<void> _loadStock(int index) async {
    if (_warehouseFromId == null || _items[index].itemId == null) return;
    final stock = await _service.getStock(
      itemId: _items[index].itemId!,
      warehouseId: _warehouseFromId!,
    );
    if (mounted) {
      setState(() {
        _items[index].stock = stock;
      });
    }
  }

  Future<void> _openItemSearch(int index) async {
    if (_warehouseFromId == null) {
      _showMessage('Pilih gudang asal terlebih dahulu');
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ItemSearchModal(
          warehouseId: _warehouseFromId!,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _items[index].itemId = selected['id'] as int;
        _items[index].nameController.text = selected['name']?.toString() ?? '';
        _items[index].sku = selected['sku']?.toString();
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
        _items[index].availableUnits = units.toList();
        _items[index].unit = _items[index].availableUnits.isNotEmpty
            ? _items[index].availableUnits.first
            : null;
      });
      await _loadStock(index);
    }
  }

  Future<void> _submit() async {
    if (_warehouseFromId == null || _warehouseToId == null) {
      _showMessage('Pilih gudang asal dan tujuan');
      return;
    }
    if (_warehouseFromId == _warehouseToId) {
      _showMessage('Gudang asal dan tujuan tidak boleh sama');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];

    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '')) ?? 0;
      if (item.itemId == null || qty <= 0 || (item.unit == null || item.unit!.isEmpty)) {
        _showMessage('Lengkapi semua item dengan qty & unit');
        return;
      }

      final availableStock = _getAvailableStock(item);
      if (availableStock != null && qty > availableStock) {
        _showMessage('Qty melebihi stok tersedia (${availableStock.toStringAsFixed(2)})');
        return;
      }

      itemsPayload.add({
        'item_id': item.itemId,
        'qty': qty,
        'unit': item.unit,
        if (item.noteController.text.isNotEmpty) 'note': item.noteController.text,
      });
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _service.createTransfer(
      transferDate: _dateController.text,
      warehouseFromId: _warehouseFromId!,
      warehouseToId: _warehouseToId!,
      notes: _notesController.text,
      items: itemsPayload,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _showMessage('Transfer berhasil disimpan', success: true);
        Navigator.pop(context, true);
      } else {
        _showMessage(result['message']?.toString() ?? 'Gagal menyimpan transfer');
      }
    }
  }

  double? _getAvailableStock(_TransferItemInput item) {
    if (item.stock == null || item.unit == null) return null;
    final stock = item.stock!;
    if (item.unit == stock['unit_small']) return _parseNumber(stock['qty_small']);
    if (item.unit == stock['unit_medium']) return _parseNumber(stock['qty_medium']);
    if (item.unit == stock['unit_large']) return _parseNumber(stock['qty_large']);
    return null;
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Pindah Gudang',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildWarehouseCard(),
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
            onTap: _selectDate,
            child: AbsorbPointer(
              child: TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Tanggal Transfer',
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
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Keterangan (opsional)',
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

  Widget _buildWarehouseCard() {
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
              const Icon(Icons.warehouse_rounded, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Gudang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _swapWarehouses,
                icon: const Icon(Icons.swap_vert_rounded),
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingWarehouses
              ? const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)))
              : Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: _warehouseFromId,
                      decoration: InputDecoration(
                        labelText: 'Gudang Asal',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _warehouses
                          .map((w) => DropdownMenuItem<int>(
                                value: w['id'] as int,
                                child: Text(w['name']?.toString() ?? '-'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _warehouseFromId = value;
                        });
                        _refreshAllStocks();
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _warehouseToId,
                      decoration: InputDecoration(
                        labelText: 'Gudang Tujuan',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _warehouses
                          .map((w) => DropdownMenuItem<int>(
                                value: w['id'] as int,
                                child: Text(w['name']?.toString() ?? '-'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _warehouseToId = value;
                        });
                      },
                    ),
                  ],
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
                  'Item Transfer',
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
                child: DropdownButtonFormField<String>(
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
                    });
                  },
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
          const SizedBox(height: 10),
          _buildStockInfo(item),
        ],
      ),
    );
  }

  Widget _buildStockInfo(_TransferItemInput item) {
    if (item.stock == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Stok: -', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      );
    }

    final stock = item.stock!;
    final small = _parseNumber(stock['qty_small']);
    final medium = _parseNumber(stock['qty_medium']);
    final large = _parseNumber(stock['qty_large']);
    final unitSmall = stock['unit_small']?.toString() ?? '';
    final unitMedium = stock['unit_medium']?.toString() ?? '';
    final unitLarge = stock['unit_large']?.toString() ?? '';

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Stok: ${small.toStringAsFixed(2)} $unitSmall | ${medium.toStringAsFixed(2)} $unitMedium | ${large.toStringAsFixed(2)} $unitLarge',
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
            : const Text('Simpan Transfer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
  final int warehouseId;

  const _ItemSearchModal({required this.warehouseId});

  @override
  State<_ItemSearchModal> createState() => _ItemSearchModalState();
}

class _ItemSearchModalState extends State<_ItemSearchModal> {
  final WarehouseTransferService _service = WarehouseTransferService();
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

    final results = await _service.searchItems(query, warehouseId: widget.warehouseId);
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
