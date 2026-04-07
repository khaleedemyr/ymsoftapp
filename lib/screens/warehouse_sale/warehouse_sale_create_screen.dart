import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/warehouse_sale_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class _LineItem {
  int itemId;
  String itemName;
  double qty;
  String selectedUnit;
  double price;
  TextEditingController qtyController = TextEditingController();

  _LineItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.selectedUnit,
    required this.price,
  }) {
    qtyController.text = qty.toString();
  }

  void dispose() {
    qtyController.dispose();
  }
}

class WarehouseSaleCreateScreen extends StatefulWidget {
  const WarehouseSaleCreateScreen({super.key});

  @override
  State<WarehouseSaleCreateScreen> createState() => _WarehouseSaleCreateScreenState();
}

class _WarehouseSaleCreateScreenState extends State<WarehouseSaleCreateScreen> {
  final WarehouseSaleService _service = WarehouseSaleService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  bool _loadingCreateData = true;
  int? _sourceWarehouseId;
  int? _targetWarehouseId;
  String _saleDate = '';
  final List<_LineItem> _items = [];
  bool _saving = false;

  static const _primary = Color(0xFF0EA5E9);
  static const _primaryDark = Color(0xFF0369A1);

  @override
  void initState() {
    super.initState();
    _saleDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateController.text = _saleDate;
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _noteController.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _warehouseName(Map<String, dynamic> w) =>
      w['name']?.toString() ?? w['nama']?.toString() ?? '-';

  Future<void> _loadCreateData() async {
    setState(() => _loadingCreateData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      final list = result['warehouses'];
      setState(() {
        _warehouses = list is List ? list.map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _loadingCreateData = false;
      });
    } else if (mounted) {
      setState(() => _loadingCreateData = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate.isNotEmpty ? (DateTime.tryParse(_saleDate) ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _saleDate = DateFormat('yyyy-MM-dd').format(picked);
        _dateController.text = _saleDate;
      });
    }
  }

  Future<void> _addItem() async {
    if (_sourceWarehouseId == null) {
      _showSnack('Pilih gudang asal dulu', isError: true);
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemSearchSheet(service: _service),
    );
    if (selected != null && mounted) {
      final itemId = _int(selected['id'])!;
      final price = await _service.getItemPrice(itemId: itemId, warehouseId: _sourceWarehouseId);
      final p = (price ?? 0).toDouble();
      final unitSmall = selected['unit_small']?.toString();
      final unitMedium = selected['unit_medium']?.toString();
      final unitLarge = selected['unit_large']?.toString();
      String unit = unitMedium ?? unitSmall ?? unitLarge ?? '';
      if (unit.isEmpty && (unitSmall != null || unitLarge != null)) {
        unit = unitSmall ?? unitLarge ?? '';
      }
      setState(() {
        _items.add(_LineItem(
          itemId: itemId,
          itemName: selected['name']?.toString() ?? '-',
          qty: 1,
          selectedUnit: unit,
          price: p,
        ));
      });
    }
  }

  void _removeItem(int index) {
    if (index >= _items.length) return;
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  void _updateItemQty(int index, double qty) {
    if (index >= _items.length) return;
    setState(() {
      _items[index].qty = qty > 0 ? qty : 1;
      _items[index].qtyController.text = _items[index].qty.toString();
    });
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, i) => sum + (i.qty * i.price));

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : null),
    );
  }

  Future<void> _submit() async {
    if (_sourceWarehouseId == null) {
      _showSnack('Pilih gudang asal', isError: true);
      return;
    }
    if (_targetWarehouseId == null) {
      _showSnack('Pilih gudang tujuan', isError: true);
      return;
    }
    if (_sourceWarehouseId == _targetWarehouseId) {
      _showSnack('Gudang asal dan tujuan tidak boleh sama', isError: true);
      return;
    }
    if (_items.isEmpty) {
      _showSnack('Tambahkan minimal 1 item', isError: true);
      return;
    }
    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '.')) ?? item.qty;
      if (qty <= 0) {
        _showSnack('Qty item "${item.itemName}" harus > 0', isError: true);
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan penjualan antar gudang?'),
        content: Text(
          'Total ${_items.length} item. Total nilai: Rp ${NumberFormat('#,##0', 'id_ID').format(_totalAmount)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final itemsPayload = _items.map((i) {
      final qty = double.tryParse(i.qtyController.text.replaceAll(',', '.')) ?? i.qty;
      return {
        'item_id': i.itemId,
        'qty': qty,
        'selected_unit': i.selectedUnit,
        'price': i.price,
      };
    }).toList();

    final result = await _service.store(
      sourceWarehouseId: _sourceWarehouseId!,
      targetWarehouseId: _targetWarehouseId!,
      date: _saleDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      items: itemsPayload,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      _showSnack(result['message']?.toString() ?? 'Berhasil disimpan');
      Navigator.pop(context, true);
    } else {
      _showSnack(result['message']?.toString() ?? 'Gagal menyimpan', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCreateData) {
      return AppScaffold(
        title: 'Buat Penjualan Antar Gudang',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9))),
      );
    }

    return AppScaffold(
      title: 'Buat Penjualan Antar Gudang',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.warehouse_rounded, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Penjualan Antar Gudang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('Gudang asal → Gudang tujuan', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Informasi',
              icon: Icons.info_outline_rounded,
              children: [
                DropdownButtonFormField<int>(
                  value: _sourceWarehouseId,
                  decoration: _inputDecoration('Gudang Asal'),
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Pilih gudang asal')),
                    for (final w in _warehouses)
                      if (_int(w['id']) != null)
                        DropdownMenuItem<int>(value: _int(w['id']), child: Text(_warehouseName(w))),
                  ],
                  onChanged: (v) => setState(() => _sourceWarehouseId = v),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _targetWarehouseId,
                  decoration: _inputDecoration('Gudang Tujuan'),
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Pilih gudang tujuan')),
                    for (final w in _warehouses)
                      if (_int(w['id']) != null && _int(w['id']) != _sourceWarehouseId)
                        DropdownMenuItem<int>(value: _int(w['id']), child: Text(_warehouseName(w))),
                  ],
                  onChanged: (v) => setState(() => _targetWarehouseId = v),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateController,
                      decoration: _inputDecoration('Tanggal', suffixIcon: const Icon(Icons.calendar_today_rounded, color: _primary)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: _inputDecoration('Catatan (opsional)'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Item',
              icon: Icons.shopping_cart_outlined,
              children: [
                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Tambah Item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Belum ada item', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text('Pilih gudang asal lalu tap "Tambah Item"', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_items.length, (i) => _buildItemRow(i)),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          'Rp ${NumberFormat('#,##0', 'id_ID').format(_totalAmount)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            Material(
              elevation: 4,
              shadowColor: _primary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _saving ? null : _submit,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _saving ? null : const LinearGradient(colors: [_primary, _primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    color: _saving ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _saving
                      ? const SizedBox(height: 24, width: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : const Text('Simpan Penjualan', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: _primary),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
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
          Row(
            children: [
              Expanded(child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  controller: item.qtyController,
                  onChanged: (v) {
                    final q = double.tryParse(v.replaceAll(',', '.'));
                    if (q != null && q > 0) _updateItemQty(index, q);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(item.selectedUnit, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const Spacer(),
              Text(
                'Rp ${NumberFormat('#,##0', 'id_ID').format(item.price)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Subtotal: Rp ${NumberFormat('#,##0', 'id_ID').format(item.qty * item.price)}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: _primary),
          ),
        ],
      ),
    );
  }
}

class _ItemSearchSheet extends StatefulWidget {
  final WarehouseSaleService service;

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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.length >= 2) {
      _doSearch(q);
    } else {
      setState(() => _items = []);
    }
  }

  Future<void> _doSearch(String q) async {
    setState(() => _searching = true);
    final list = await widget.service.searchItems(q);
    if (mounted) {
      setState(() {
        _items = list;
        _searching = false;
      });
    }
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
                    ? Center(
                        child: Text(
                          _searchController.text.trim().length < 2 ? 'Ketik minimal 2 karakter' : 'Tidak ada hasil',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
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
