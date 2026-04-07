import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/retail_warehouse_sale_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailWarehouseSaleCreateScreen extends StatefulWidget {
  const RetailWarehouseSaleCreateScreen({super.key});

  @override
  State<RetailWarehouseSaleCreateScreen> createState() =>
      _RetailWarehouseSaleCreateScreenState();
}

class _RetailWarehouseSaleCreateScreenState extends State<RetailWarehouseSaleCreateScreen> {
  final RetailWarehouseSaleService _service = RetailWarehouseSaleService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _customers = [];
  bool _loadingCreateData = true;

  int? _customerId;
  String _customerName = '';
  String _saleDate = '';
  int? _warehouseId;
  int? _divisionId;
  final List<_CartItem> _items = [];
  bool _saving = false;

  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);
  static const _infoBg = Color(0xFFEFF6FF);
  static const _itemsBg = Color(0xFFF5F3FF);

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
    _notesController.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _loadingCreateData = true);
    final result = await _service.getCreateData();
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      setState(() {
        _warehouses = _parseList(result['warehouses']);
        _divisions = _parseList(result['warehouse_divisions']);
        _customers = _parseList(result['customers']);
        _loadingCreateData = false;
      });
    } else {
      setState(() => _loadingCreateData = false);
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  String _warehouseName(Map<String, dynamic> w) =>
      w['name']?.toString() ?? w['nama']?.toString() ?? '-';

  List<Map<String, dynamic>> get _filteredDivisions {
    if (_warehouseId == null) return [];
    return _divisions.where((d) => _int(d['warehouse_id']) == _warehouseId).toList();
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, i) => sum + (i.qty * i.price));

  String _warehouseNameById(int? id) {
    if (id == null) return '-';
    for (final w in _warehouses) {
      if (_int(w['id']) == id) return _warehouseName(w);
    }
    return '-';
  }

  String _divisionNameById(int? id) {
    if (id == null) return '-';
    for (final d in _divisions) {
      if (_int(d['id']) == id) return d['name']?.toString() ?? d['nama']?.toString() ?? '-';
    }
    return '-';
  }

  Future<void> _pickCustomer() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerSheet(
        initialCustomers: _customers,
        service: _service,
        onReloadCustomers: () async {
          final r = await _service.getCreateData();
          if (r != null && r['success'] == true) {
            _customers = _parseList(r['customers']);
          }
        },
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _customerId = _int(selected['id']);
        _customerName = selected['name']?.toString() ?? '';
      });
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
    if (_warehouseId == null) {
      _showSnack('Pilih gudang dulu', isError: true);
      return;
    }
    final item = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemSearchSheet(
        warehouseId: _warehouseId!,
        service: _service,
      ),
    );
    if (item != null && mounted) {
      setState(() {
        final unitMedium = item['unit_medium']?.toString() ?? '';
        final price = (item['price'] is num) ? (item['price'] as num).toDouble() : double.tryParse(item['price']?.toString() ?? '') ?? 0;
        _items.add(_CartItem(
          itemId: _int(item['item_id'])!,
          itemName: item['item_name']?.toString() ?? '-',
          qty: 1,
          unit: unitMedium,
          price: price,
          unitSmall: item['unit_small']?.toString(),
          unitLarge: item['unit_large']?.toString(),
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (_customerId == null) {
      _showSnack('Pilih customer', isError: true);
      return;
    }
    if (_warehouseId == null) {
      _showSnack('Pilih gudang', isError: true);
      return;
    }
    if (_items.isEmpty) {
      _showSnack('Tambahkan minimal 1 item', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PreviewSaleDialog(
        customerName: _customerName,
        saleDate: _saleDate,
        warehouseName: _warehouseNameById(_warehouseId),
        divisionName: _divisionNameById(_divisionId),
        notes: _notesController.text.trim(),
        items: _items.map((i) => _PreviewSaleItem(name: i.itemName, qty: i.qty, unit: i.unit, price: i.price, subtotal: i.qty * i.price)).toList(),
        totalAmount: _totalAmount,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final itemsPayload = _items.map((i) => {
      'item_id': i.itemId,
      'qty': i.qty,
      'unit': i.unit,
      'price': i.price,
      'subtotal': i.qty * i.price,
    }).toList();

    final result = await _service.store(
      customerId: _customerId!,
      saleDate: _saleDate,
      warehouseId: _warehouseId!,
      warehouseDivisionId: _divisionId,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: itemsPayload,
      totalAmount: _totalAmount,
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
        title: 'Buat Penjualan',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB))),
      );
    }

    return AppScaffold(
      title: 'Buat Penjualan Warehouse Retail',
      showDrawer: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primary.withOpacity(0.08), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildSection(
                title: 'Informasi',
                icon: Icons.info_outline_rounded,
                iconBg: _infoBg,
                iconColor: _primary,
                children: [
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration('Customer', suffixIcon: const Icon(Icons.person_outline_rounded, color: _primary)),
                      child: Text(
                        _customerName.isEmpty ? 'Tap pilih customer' : _customerName,
                        style: TextStyle(
                          fontSize: 14,
                          color: _customerName.isEmpty ? Colors.grey : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
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
                  DropdownButtonFormField<int>(
                    value: _warehouseId,
                    decoration: _inputDecoration('Gudang'),
                    dropdownColor: Colors.white,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Pilih gudang')),
                      for (final w in _warehouses)
                        if (_int(w['id']) != null)
                          DropdownMenuItem<int>(
                            value: _int(w['id']),
                            child: Text(_warehouseName(w)),
                          ),
                    ],
                    onChanged: (v) => setState(() {
                      _warehouseId = v;
                      _divisionId = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _divisionId,
                    decoration: _inputDecoration('Divisi (opsional)'),
                    dropdownColor: Colors.white,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Pilih divisi')),
                      for (final d in _filteredDivisions)
                        if (_int(d['id']) != null)
                          DropdownMenuItem<int>(
                            value: _int(d['id']),
                            child: Text(d['name']?.toString() ?? d['nama']?.toString() ?? '-'),
                          ),
                    ],
                    onChanged: (v) => setState(() => _divisionId = v),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: _inputDecoration('Catatan (opsional)'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: 'Item',
                icon: Icons.shopping_cart_outlined,
                iconBg: _itemsBg,
                iconColor: const Color(0xFF7C3AED),
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
                            Text('Tap "Tambah Item" lalu pilih gudang', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (i) => _buildCartRow(i)),
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
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, _primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.shopping_bag_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buat Penjualan Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Text('Warehouse retail', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required List<Widget> children,
  }) {
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
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: iconColor),
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

  Widget _buildCartRow(int index) {
    final item = _items[index];
    final units = [item.unit];
    if (item.unitSmall != null && item.unitSmall!.isNotEmpty && !units.contains(item.unitSmall)) units.add(item.unitSmall!);
    if (item.unitLarge != null && item.unitLarge!.isNotEmpty && !units.contains(item.unitLarge)) units.add(item.unitLarge!);

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
                width: 80,
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  controller: item.qtyController,
                  onChanged: (v) {
                    final q = double.tryParse(v.replaceAll(',', '.'));
                    if (q != null && q > 0) setState(() => _items[index].qty = q);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.unit,
                  decoration: const InputDecoration(isDense: true),
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => item.unit = v ?? item.unit),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rp ${NumberFormat('#,##0', 'id_ID').format(item.price)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Subtotal: Rp ${NumberFormat('#,##0', 'id_ID').format(item.qty * item.price)}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }
}

class _PreviewSaleItem {
  final String name;
  final double qty;
  final String unit;
  final double price;
  final double subtotal;

  const _PreviewSaleItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.subtotal,
  });
}

class _PreviewSaleDialog extends StatelessWidget {
  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);

  final String customerName;
  final String saleDate;
  final String warehouseName;
  final String divisionName;
  final String notes;
  final List<_PreviewSaleItem> items;
  final double totalAmount;

  const _PreviewSaleDialog({
    required this.customerName,
    required this.saleDate,
    required this.warehouseName,
    required this.divisionName,
    required this.notes,
    required this.items,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.preview_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Preview Penjualan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(Icons.person_outline_rounded, 'Customer', customerName),
                    const SizedBox(height: 10),
                    _row(Icons.calendar_today_rounded, 'Tanggal', saleDate),
                    const SizedBox(height: 10),
                    _row(Icons.warehouse_rounded, 'Gudang', warehouseName),
                    if (divisionName.isNotEmpty && divisionName != '-') ...[
                      const SizedBox(height: 10),
                      _row(Icons.business_rounded, 'Divisi', divisionName),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _row(Icons.note_alt_outlined, 'Catatan', notes),
                    ],
                    const SizedBox(height: 16),
                    const Text('Detail Item', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    ...items.map((item) => Container(
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
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 14)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('${item.qty} ${item.unit} x Rp ${NumberFormat('#,##0', 'id_ID').format(item.price)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              const Spacer(),
                              Text('Rp ${NumberFormat('#,##0', 'id_ID').format(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB), fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('Rp ${NumberFormat('#,##0', 'id_ID').format(totalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text('Kembali'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ya, Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItem {
  final int itemId;
  final String itemName;
  double qty;
  String unit;
  final double price;
  final String? unitSmall;
  final String? unitLarge;
  final TextEditingController qtyController;

  _CartItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.price,
    this.unitSmall,
    this.unitLarge,
  }) : qtyController = TextEditingController(text: qty.toString());

  void dispose() => qtyController.dispose();
}

class _CustomerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialCustomers;
  final RetailWarehouseSaleService service;
  final VoidCallback? onReloadCustomers;

  const _CustomerSheet({
    required this.initialCustomers,
    required this.service,
    this.onReloadCustomers,
  });

  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.initialCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _list = List.from(widget.initialCustomers));
      return;
    }
    setState(() => _searching = true);
    final results = await widget.service.searchCustomers(q);
    if (mounted) {
      setState(() {
        _list = results;
        _searching = false;
      });
    }
  }

  Future<void> _createNew() async {
    final codeC = TextEditingController();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode *')),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama *')),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Telepon'), keyboardType: TextInputType.phone),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isEmpty || codeC.text.trim().isEmpty) return;
              final r = await widget.service.storeCustomer(
                code: codeC.text.trim(),
                name: nameC.text.trim(),
                type: 'customer',
                phone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
              );
              if (r != null && r['success'] == true && r['customer'] != null) {
                final customer = Map<String, dynamic>.from(r['customer'] as Map);
                if (ctx.mounted) Navigator.pop(ctx, customer);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari customer...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _createNew,
            icon: const Icon(Icons.add),
            label: const Text('Tambah customer baru'),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) {
                      final c = _list[i];
                      final name = c['name']?.toString() ?? '-';
                      final code = c['code']?.toString() ?? '';
                      return ListTile(
                        title: Text(name),
                        subtitle: code.isNotEmpty ? Text(code) : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemSearchSheet extends StatefulWidget {
  final int warehouseId;
  final RetailWarehouseSaleService service;

  const _ItemSearchSheet({required this.warehouseId, required this.service});

  @override
  State<_ItemSearchSheet> createState() => _ItemSearchSheetState();
}

class _ItemSearchSheetState extends State<_ItemSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _searching = false;

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      setState(() => _list = []);
      return;
    }
    setState(() => _searching = true);
    final results = await widget.service.searchItemsByName(search: q, warehouseId: widget.warehouseId);
    if (mounted) {
      setState(() {
        _list = results;
        _searching = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ketik nama barang (min 2 karakter)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          ElevatedButton(
            onPressed: _search,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Cari'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(child: Text('Ketik dan cari item'))
                    : ListView.builder(
                        itemCount: _list.length,
                        itemBuilder: (ctx, i) {
                          final item = _list[i];
                          final name = item['item_name']?.toString() ?? '-';
                          final price = item['price'];
                          final p = price is num ? price.toDouble() : double.tryParse(price?.toString() ?? '') ?? 0;
                          final unit = item['unit_medium']?.toString() ?? '';
                          final stock = item['qty_medium'] ?? item['qty_small'] ?? 0;
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('Stok: ${_fmt(stock)} $unit • Rp ${NumberFormat('#,##0', 'id_ID').format(p)}'),
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
