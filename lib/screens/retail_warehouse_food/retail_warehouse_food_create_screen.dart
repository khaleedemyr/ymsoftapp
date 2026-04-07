import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/retail_warehouse_food_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailWarehouseFoodCreateScreen extends StatefulWidget {
  const RetailWarehouseFoodCreateScreen({super.key});

  @override
  State<RetailWarehouseFoodCreateScreen> createState() =>
      _RetailWarehouseFoodCreateScreenState();
}

class _RwfItemRow {
  int? itemId;
  String itemName = '';
  int? unitId;
  String unitName = '';
  List<Map<String, dynamic>> unitOptions = [];
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController(text: '0');

  double get qty => (double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0);
  double get price => (double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0);
  double get subtotal => qty * price;

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}

class _RetailWarehouseFoodCreateScreenState extends State<RetailWarehouseFoodCreateScreen> {
  final RetailWarehouseFoodService _service = RetailWarehouseFoodService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _loadingCreateData = true;

  String _transactionDate = '';
  int? _warehouseId;
  int? _divisionId;
  String _paymentMethod = 'cash';
  int? _supplierId;
  String _supplierName = '';
  final List<_RwfItemRow> _items = [];
  bool _saving = false;

  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);
  static const _infoBg = Color(0xFFEFF6FF);
  static const _itemsBg = Color(0xFFF5F3FF);

  @override
  void initState() {
    super.initState();
    _transactionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateController.text = _transactionDate;
    _items.add(_RwfItemRow());
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
    if (result != null && (result['success'] == true || result['warehouses'] != null)) {
      setState(() {
        _warehouses = _parseList(result['warehouses']);
        _divisions = _parseList(result['warehouse_divisions']);
        _suppliers = _parseList(result['suppliers']);
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

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _name(Map<String, dynamic> m) => m['name']?.toString() ?? m['nama']?.toString() ?? '-';

  /// Nilai dropdown unit: hanya gunakan row.unitId jika ada di daftar option (hindari assertion error).
  int? _unitDropdownValue(_RwfItemRow row) {
    if (row.unitId == null) return null;
    final hasMatch = row.unitOptions.any((u) => _int(u['id']) == row.unitId);
    return hasMatch ? row.unitId : null;
  }

  /// Item dropdown unit (sudah deduplikat saat load).
  List<DropdownMenuItem<int?>> _unitDropdownItems(_RwfItemRow row) {
    return row.unitOptions.map((u) {
      final id = _int(u['id']);
      final name = u['name']?.toString() ?? '-';
      return DropdownMenuItem<int?>(value: id, child: Text(name));
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredDivisions {
    if (_warehouseId == null) return _divisions;
    // Filter by warehouse_id if backend sends it; otherwise show all
    final hasWarehouseId = _divisions.any((d) => d.containsKey('warehouse_id'));
    if (!hasWarehouseId) return _divisions;
    return _divisions.where((d) => _int(d['warehouse_id']) == _warehouseId).toList();
  }

  double get _totalAmount => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate.isNotEmpty ? (DateTime.tryParse(_transactionDate) ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _transactionDate = DateFormat('yyyy-MM-dd').format(picked);
        _dateController.text = _transactionDate;
      });
    }
  }

  Future<void> _pickItem(int index) async {
    if (_warehouseId == null) {
      _showSnack('Pilih gudang terlebih dahulu', isError: true);
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemSearchSheet(
        warehouseId: _warehouseId!,
        service: _service,
      ),
    );
    if (selected == null || !mounted) return;
    final itemId = _int(selected['id']);
    final itemName = _name(selected);
    if (itemId == null) return;

    final unitsResult = await _service.getItemUnits(itemId, paymentMethod: _paymentMethod);
    if (!mounted) return;
    List<Map<String, dynamic>> units = [];
    dynamic defaultUnit;
    num defaultPrice = 0;
    if (unitsResult != null) {
      final u = unitsResult['units'];
      if (u is List) {
        final raw = (u as List).map((e) => Map<String, dynamic>.from(e)).toList();
        // Deduplicate by id so dropdown never has duplicate values
        final seenIds = <int>{};
        for (final e in raw) {
          final id = _int(e['id']);
          if (id != null && !seenIds.contains(id)) {
            seenIds.add(id);
            units.add(e);
          }
        }
      }
      defaultUnit = unitsResult['default_unit'];
      final dp = unitsResult['default_price'];
      if (dp is num) defaultPrice = dp;
      if (dp != null && dp is! num) defaultPrice = double.tryParse(dp.toString()) ?? 0;
    }

    setState(() {
      final row = _items[index];
      row.itemId = itemId;
      row.itemName = itemName;
      row.unitOptions = units;
      row.unitId = null;
      row.unitName = '';
      if (defaultUnit is Map && (defaultUnit as Map).isNotEmpty) {
        row.unitId = _int((defaultUnit as Map)['id']);
        row.unitName = (defaultUnit as Map)['name']?.toString() ?? '';
        if (defaultPrice > 0) row.priceController.text = defaultPrice.toString();
      } else if (units.isNotEmpty) {
        final first = units.first;
        row.unitId = _int(first['id']);
        row.unitName = first['name']?.toString() ?? '';
      }
      // Ensure unitId exists in unitOptions (avoid dropdown assertion)
      if (row.unitId != null && !units.any((e) => _int(e['id']) == row.unitId)) {
        row.unitId = null;
        row.unitName = '';
      }
      row.qtyController.text = '1';
    });
  }

  void _addItem() {
    setState(() => _items.add(_RwfItemRow()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _warehouseNameById(int? id) {
    if (id == null) return '-';
    for (final w in _warehouses) {
      if (_int(w['id']) == id) return _name(w);
    }
    return '-';
  }

  String _divisionNameById(int? id) {
    if (id == null) return '-';
    for (final d in _divisions) {
      if (_int(d['id']) == id) return _name(d);
    }
    return '-';
  }

  Future<void> _pickSupplier() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SupplierSearchSheet(
        suppliers: _suppliers,
        currentId: _supplierId,
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        if (selected.isEmpty) {
          _supplierId = null;
          _supplierName = '';
        } else {
          _supplierId = _int(selected['id']);
          _supplierName = _name(selected);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_transactionDate.isEmpty || _warehouseId == null || _paymentMethod.isEmpty) {
      _showSnack('Tanggal, Gudang, dan Metode Pembayaran wajib diisi', isError: true);
      return;
    }
    for (int i = 0; i < _items.length; i++) {
      final row = _items[i];
      if (row.itemId == null || row.itemName.isEmpty) {
        _showSnack('Baris ${i + 1}: Pilih item', isError: true);
        return;
      }
      if (row.unitId == null || row.unitName.isEmpty) {
        _showSnack('Baris ${i + 1}: Pilih unit', isError: true);
        return;
      }
      if (row.qty <= 0) {
        _showSnack('Baris ${i + 1}: Qty harus > 0', isError: true);
        return;
      }
      if (row.price < 0) {
        _showSnack('Baris ${i + 1}: Harga tidak valid', isError: true);
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PreviewDialog(
        date: _transactionDate,
        warehouseName: _warehouseNameById(_warehouseId),
        divisionName: _divisionNameById(_divisionId),
        paymentMethod: _paymentMethod,
        supplierName: _supplierName.isEmpty ? null : _supplierName,
        items: _items.map((r) => _PreviewItem(
          name: r.itemName,
          qty: r.qty,
          unit: r.unitName,
          price: r.price,
          subtotal: r.subtotal,
        )).toList(),
        total: _totalAmount,
        notes: _notesController.text.trim(),
      ),
    );
    if (confirm != true || !mounted) return;

    await _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _saving = true);
    final itemsPayload = _items.map((row) => {
      'item_name': row.itemName,
      'qty': row.qty,
      'unit': row.unitName,
      'unit_id': row.unitId,
      'price': row.price,
    }).toList();

    final result = await _service.store(
      warehouseId: _warehouseId!,
      warehouseDivisionId: _divisionId,
      transactionDate: _transactionDate,
      paymentMethod: _paymentMethod,
      supplierId: _supplierId,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
    return AppScaffold(
      title: 'Buat Warehouse Retail Food',
      showDrawer: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primary.withOpacity(0.06), Colors.white],
          ),
        ),
        child: _loadingCreateData
            ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB)))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Informasi Dasar',
                      icon: Icons.info_outline_rounded,
                      iconBg: _infoBg,
                      iconColor: _primary,
                      child: Column(
                        children: [
                          _buildDateField(),
                          const SizedBox(height: 14),
                          _buildWarehouseDropdown(),
                          const SizedBox(height: 14),
                          _buildDivisionDropdown(),
                          const SizedBox(height: 14),
                          _buildPaymentMethodDropdown(),
                          const SizedBox(height: 14),
                          _buildSupplierField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Detail Item',
                      icon: Icons.inventory_2_outlined,
                      iconBg: _itemsBg,
                      iconColor: const Color(0xFF7C3AED),
                      child: Column(
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
                          ...List.generate(_items.length, (i) => _buildItemRow(i)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Total: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Flexible(
                                child: Text(
                                  'Rp ${NumberFormat('#,##0', 'id_ID').format(_totalAmount)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Catatan',
                      icon: Icons.note_alt_outlined,
                      iconBg: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFD97706),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Catatan (opsional)...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _primary, width: 2),
                          ),
                        ),
                      ),
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
                            gradient: _saving ? null : const LinearGradient(
                              colors: [_primary, _primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            color: _saving ? Colors.grey.shade300 : null,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Simpan Transaksi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
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
            child: const Icon(Icons.warehouse_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Warehouse Retail Food', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Text('Buat transaksi retail food gudang', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Widget child,
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          controller: _dateController,
          decoration: InputDecoration(
            labelText: 'Tanggal Transaksi',
            prefixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    final validWarehouses = _warehouses.where((w) => _int(w['id']) != null).toList();
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      value: _warehouseId,
      decoration: InputDecoration(
        labelText: 'Gudang',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Pilih Gudang --')),
        ...validWarehouses.map((w) => DropdownMenuItem(value: _int(w['id']), child: Text(_name(w)))),
      ],
      onChanged: (v) {
        setState(() {
          _warehouseId = v;
          _divisionId = null;
        });
      },
    );
  }

  Widget _buildDivisionDropdown() {
    final options = _filteredDivisions.where((d) => _int(d['id']) != null).toList();
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      value: _divisionId,
      decoration: InputDecoration(
        labelText: 'Divisi Gudang (opsional)',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Tidak ada --')),
        ...options.map((d) => DropdownMenuItem(value: _int(d['id']), child: Text(_name(d)))),
      ],
      onChanged: (v) => setState(() => _divisionId = v),
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _paymentMethod,
      decoration: InputDecoration(
        labelText: 'Metode Pembayaran',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
      ),
      items: const [
        DropdownMenuItem(value: 'cash', child: Text('Cash')),
        DropdownMenuItem(value: 'contra_bon', child: Text('Contra Bon')),
      ],
      onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
    );
  }

  Widget _buildSupplierField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supplier (opsional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickSupplier,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _supplierName.isEmpty ? 'Cari atau pilih supplier...' : _supplierName,
                    style: TextStyle(
                      fontSize: 14,
                      color: _supplierName.isEmpty ? Colors.grey : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_supplierName.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      _supplierId = null;
                      _supplierName = '';
                    }),
                    child: const Icon(Icons.clear, size: 20, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(int index) {
    final row = _items[index];
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
              Expanded(
                child: InkWell(
                  onTap: () => _pickItem(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row.itemName.isEmpty ? 'Pilih item...' : row.itemName,
                            style: TextStyle(
                              fontSize: 14,
                              color: row.itemName.isEmpty ? Colors.grey : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          if (row.itemId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _unitDropdownValue(row),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Unit',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Unit --')),
                      ..._unitDropdownItems(row),
                    ],
                    onChanged: (v) {
                      setState(() {
                        row.unitId = v;
                        for (final u in row.unitOptions) {
                          if (_int(u['id']) == v) {
                            row.unitName = u['name']?.toString() ?? '';
                            break;
                          }
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Qty',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Harga',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Subtotal: Rp ${NumberFormat('#,##0', 'id_ID').format(row.subtotal)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Preview dialog ---
class _PreviewItem {
  final String name;
  final double qty;
  final String unit;
  final double price;
  final double subtotal;

  _PreviewItem({required this.name, required this.qty, required this.unit, required this.price, required this.subtotal});
}

class _PreviewDialog extends StatelessWidget {
  final String date;
  final String warehouseName;
  final String divisionName;
  final String paymentMethod;
  final String? supplierName;
  final List<_PreviewItem> items;
  final double total;
  final String notes;

  const _PreviewDialog({
    required this.date,
    required this.warehouseName,
    required this.divisionName,
    required this.paymentMethod,
    this.supplierName,
    required this.items,
    required this.total,
    required this.notes,
  });

  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);
  static const _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview Transaksi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Periksa data sebelum menyimpan',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info section
                    _buildPreviewSection(
                      icon: Icons.info_outline_rounded,
                      iconColor: _primary,
                      title: 'Informasi',
                      child: Column(
                        children: [
                          _buildPreviewRow(Icons.calendar_today_rounded, 'Tanggal', date),
                          _buildPreviewRow(Icons.warehouse_rounded, 'Gudang', warehouseName),
                          _buildPreviewRow(Icons.category_rounded, 'Divisi', divisionName),
                          _buildPreviewRow(
                            Icons.payment_rounded,
                            'Pembayaran',
                            paymentMethod == 'contra_bon' ? 'Contra Bon' : 'Cash',
                          ),
                          if (supplierName != null && supplierName!.isNotEmpty)
                            _buildPreviewRow(Icons.local_shipping_rounded, 'Supplier', supplierName!),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Items section
                    _buildPreviewSection(
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Detail Item',
                      child: Column(
                        children: items.map((i) {
                          final priceStr = NumberFormat('#,##0', 'id_ID').format(i.price);
                          final subtotalStr = NumberFormat('#,##0', 'id_ID').format(i.subtotal);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        i.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${i.qty} ${i.unit} x Rp $priceStr',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rp $subtotalStr',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _green,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Total
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Rp ${NumberFormat('#,##0', 'id_ID').format(total)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPreviewSection(
                        icon: Icons.note_alt_outlined,
                        iconColor: const Color(0xFFD97706),
                        title: 'Catatan',
                        child: Text(
                          notes,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        elevation: 0,
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

  Widget _buildPreviewSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Item search sheet ---
class _ItemSearchSheet extends StatefulWidget {
  final int warehouseId;
  final RetailWarehouseFoodService service;

  const _ItemSearchSheet({required this.warehouseId, required this.service});

  @override
  State<_ItemSearchSheet> createState() => _ItemSearchSheetState();
}

class _ItemSearchSheetState extends State<_ItemSearchSheet> {
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    final list = await widget.service.searchItems(q, warehouseId: widget.warehouseId);
    if (mounted) setState(() {
      _suggestions = list;
      _loading = false;
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
            controller: _queryController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Cari item (min. 2 karakter)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _search(),
            onChanged: (_) => _search(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _suggestions.isEmpty
                ? Center(
                    child: Text(
                      _queryController.text.trim().length < 2 ? 'Ketik minimal 2 karakter' : (_loading ? 'Memuat...' : 'Tidak ada hasil'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, i) {
                      final item = _suggestions[i];
                      final name = item['name']?.toString() ?? item['item_name']?.toString() ?? '-';
                      final id = item['id'];
                      return ListTile(
                        title: Text(name),
                        subtitle: item['code'] != null ? Text(item['code'].toString()) : null,
                        onTap: () => Navigator.pop(context, {'id': id, 'name': name, 'item_name': name}),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- Supplier search sheet ---
class _SupplierSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> suppliers;
  final int? currentId;

  const _SupplierSearchSheet({required this.suppliers, this.currentId});

  @override
  State<_SupplierSearchSheet> createState() => _SupplierSearchSheetState();
}

class _SupplierSearchSheetState extends State<_SupplierSearchSheet> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String _name(Map<String, dynamic> m) =>
      m['name']?.toString() ?? m['nama']?.toString() ?? '-';

  List<Map<String, dynamic>> get _filtered {
    final q = _queryController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.suppliers;
    return widget.suppliers.where((s) {
      final name = _name(s).toLowerCase();
      final code = (s['code']?.toString() ?? '').toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari supplier (nama atau kode)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.clear, color: Color(0xFF64748B)),
            title: const Text('Tidak ada supplier', style: TextStyle(color: Color(0xFF64748B))),
            onTap: () => Navigator.pop(context, <String, dynamic>{}),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada hasil',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      final id = s['id'];
                      final name = _name(s);
                      final code = s['code']?.toString();
                      return ListTile(
                        title: Text(name),
                        subtitle: code != null && code.isNotEmpty
                            ? Text(code, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                            : null,
                        selected: widget.currentId != null &&
                            (id == widget.currentId ||
                                (id is int && widget.currentId == id) ||
                                (id != null && id.toString() == widget.currentId.toString())),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
