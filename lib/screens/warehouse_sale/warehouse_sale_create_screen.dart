import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/native_barcode_scanner.dart';
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

  bool _serialMode = false;
  final TextEditingController _serialInputController = TextEditingController();
  final FocusNode _serialFocusNode = FocusNode();
  final List<Map<String, dynamic>> _scannedSerials = [];
  final Map<int, TextEditingController> _serialPriceControllers = {};
  bool _serialScanning = false;
  String _serialFeedback = '';
  bool _serialFeedbackSuccess = false;

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
    _serialInputController.dispose();
    _serialFocusNode.dispose();
    for (final item in _items) item.dispose();
    for (final c in _serialPriceControllers.values) {
      c.dispose();
    }
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

  double get _totalAmount {
    final qtyTotal = _items.fold(0.0, (sum, i) {
      final q = double.tryParse(i.qtyController.text.replaceAll(',', '.')) ?? i.qty;
      return sum + (q * i.price);
    });
    final serialTotal = _scannedSerials.fold<double>(
      0,
      (sum, s) => sum + ((s['subtotal'] as num?)?.toDouble() ?? 0),
    );
    return qtyTotal + serialTotal;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : null),
    );
  }

  void _updateSerialSubtotal(int index) {
    if (index >= _scannedSerials.length) return;
    final price = double.tryParse(_serialPriceControllers[index]?.text.replaceAll(',', '.') ?? '') ?? 0;
    final qty = (_scannedSerials[index]['qty'] as num?)?.toDouble() ?? 1;
    setState(() {
      _scannedSerials[index]['price'] = price;
      _scannedSerials[index]['subtotal'] = price * qty;
    });
  }

  void _rebuildSerialPriceControllers() {
    for (final c in _serialPriceControllers.values) {
      c.dispose();
    }
    _serialPriceControllers.clear();
    for (var i = 0; i < _scannedSerials.length; i++) {
      final price = (_scannedSerials[i]['price'] as num?)?.toDouble() ?? 0;
      _serialPriceControllers[i] = TextEditingController(text: price > 0 ? price.toString() : '');
    }
  }

  void _removeSerial(int index) {
    setState(() {
      _scannedSerials.removeAt(index);
      _rebuildSerialPriceControllers();
    });
  }

  Future<void> _onSerialScan() async {
    final input = _serialInputController.text.trim();
    if (input.isEmpty) return;
    if (_sourceWarehouseId == null) {
      setState(() {
        _serialFeedback = 'Pilih gudang asal dulu';
        _serialFeedbackSuccess = false;
      });
      return;
    }
    if (_scannedSerials.any((s) => s['serial_number'] == input)) {
      setState(() {
        _serialFeedback = 'Serial "$input" sudah discan';
        _serialFeedbackSuccess = false;
      });
      _serialInputController.clear();
      return;
    }
    setState(() => _serialScanning = true);
    final result = await _service.validateSerialForWHS(
      serialNumber: input,
      sourceWarehouseId: _sourceWarehouseId!,
    );
    if (!mounted) return;
    if (result['valid'] == true) {
      final serial = result['serial'] as Map<String, dynamic>? ?? {};
      final price = (serial['price'] as num?)?.toDouble() ?? 0;
      final idx = _scannedSerials.length;
      setState(() {
        _scannedSerials.add({
          'serial_id': serial['id'],
          'serial_number': serial['serial_number'] ?? input,
          'item_id': serial['item_id'],
          'item_name': serial['item_name'] ?? '-',
          'unit_id': serial['unit_id'],
          'unit_name': serial['unit_name'] ?? '-',
          'qty': serial['qty'] ?? 1,
          'qty_small': serial['qty_small'] ?? 1,
          'price': price,
          'subtotal': (serial['subtotal'] as num?)?.toDouble() ?? (price * ((serial['qty'] as num?)?.toDouble() ?? 1)),
        });
        _serialPriceControllers[idx] = TextEditingController(text: price > 0 ? price.toString() : '');
        _serialFeedback = 'Serial "$input" valid';
        _serialFeedbackSuccess = true;
        _serialScanning = false;
      });
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _serialFeedback = result['message']?.toString() ?? 'Serial tidak valid';
        _serialFeedbackSuccess = false;
        _serialScanning = false;
      });
      HapticFeedback.heavyImpact();
    }
    _serialInputController.clear();
    _serialFocusNode.requestFocus();
  }

  Future<void> _openCameraSerial() async {
    if (kIsWeb) {
      _showSnack('Scan kamera tersedia di aplikasi Android/iOS', isError: true);
      return;
    }
    try {
      final scanned = await NativeBarcodeScanner.scanBarcode();
      if (!mounted) return;
      if (scanned != null && scanned.isNotEmpty) {
        _serialInputController.text = scanned;
        await _onSerialScan();
      }
    } catch (e) {
      _showSnack('Gagal buka scanner: $e', isError: true);
    }
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

    final validItems = <_LineItem>[];
    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '.')) ?? item.qty;
      if (qty > 0) validItems.add(item);
    }
    final hasSerials = _scannedSerials.isNotEmpty;

    if (validItems.isEmpty && !hasSerials) {
      _showSnack('Minimal 1 item (qty) atau 1 nomor seri', isError: true);
      return;
    }

    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '.')) ?? 0;
      if (item.itemId > 0 && qty <= 0) {
        _showSnack('Qty item "${item.itemName}" harus > 0', isError: true);
        return;
      }
    }

    if (hasSerials && _scannedSerials.any((s) => ((s['price'] as num?)?.toDouble() ?? 0) <= 0)) {
      _showSnack('Semua serial harus memiliki harga', isError: true);
      return;
    }

    final lineCount = validItems.length + _scannedSerials.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan penjualan antar gudang?'),
        content: Text(
          'Total $lineCount baris. Total nilai: Rp ${NumberFormat('#,##0', 'id_ID').format(_totalAmount)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final itemsPayload = validItems.map((i) {
      final qty = double.tryParse(i.qtyController.text.replaceAll(',', '.')) ?? i.qty;
      return {
        'item_id': i.itemId,
        'qty': qty,
        'selected_unit': i.selectedUnit,
        'price': i.price,
      };
    }).toList();

    final serialPayload = _scannedSerials.map((s) => {
      'serial_id': s['serial_id'],
      'serial_number': s['serial_number'],
      'item_id': s['item_id'],
      'unit_id': s['unit_id'],
      'unit_name': s['unit_name'],
      'qty': s['qty'],
      'qty_small': s['qty_small'],
      'price': s['price'],
      'subtotal': s['subtotal'],
    }).toList();

    final result = await _service.store(
      sourceWarehouseId: _sourceWarehouseId!,
      targetWarehouseId: _targetWarehouseId!,
      date: _saleDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      items: itemsPayload.isNotEmpty ? itemsPayload : null,
      serialItems: serialPayload.isNotEmpty ? serialPayload : null,
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
            _buildSerialModeCard(),
            if (_serialMode) ...[
              const SizedBox(height: 12),
              _buildSerialScanCard(),
            ],
            const SizedBox(height: 20),
            _buildSection(
              title: 'Item (qty)',
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Opsional jika sudah scan serial',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ...List.generate(_items.length, (i) => _buildItemRow(i)),
                if (_items.isNotEmpty || _scannedSerials.isNotEmpty) ...[
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

  Widget _buildSerialModeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode Nomor Seri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Scan serial dari gudang asal', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Switch(
            value: _serialMode,
            activeColor: const Color(0xFF6366F1),
            onChanged: (v) {
              setState(() => _serialMode = v);
              if (v) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) _serialFocusNode.requestFocus();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSerialScanCard() {
    final canScan = _sourceWarehouseId != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan Nomor Seri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
          if (!canScan)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Pilih gudang asal terlebih dahulu', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serialInputController,
                  focusNode: _serialFocusNode,
                  enabled: !_serialScanning && canScan,
                  onSubmitted: (_) => _onSerialScan(),
                  decoration: const InputDecoration(
                    hintText: 'Scan / ketik serial...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: (!_serialScanning && canScan) ? _openCameraSerial : null,
                icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF6366F1)),
              ),
              IconButton(
                onPressed: (!_serialScanning && canScan) ? _onSerialScan : null,
                icon: _serialScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          if (_serialFeedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _serialFeedback,
                style: TextStyle(fontSize: 12, color: _serialFeedbackSuccess ? Colors.green : Colors.red),
              ),
            ),
          if (_scannedSerials.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${_scannedSerials.length} serial discan', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            ...List.generate(_scannedSerials.length, (i) {
              final s = _scannedSerials[i];
              _serialPriceControllers.putIfAbsent(
                i,
                () => TextEditingController(text: ((s['price'] as num?)?.toDouble() ?? 0) > 0 ? '${s['price']}' : ''),
              );
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['serial_number']?.toString() ?? '-', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(s['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text('${s['qty']} ${s['unit_name']}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeSerial(i),
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Harga', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _serialPriceControllers[i],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                            onChanged: (_) => _updateSerialSubtotal(i),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rp ${NumberFormat('#,##0', 'id_ID').format((s['subtotal'] as num?)?.toDouble() ?? 0)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
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
