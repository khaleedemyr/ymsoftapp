import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/retail_food_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailFoodFormScreen extends StatefulWidget {
  const RetailFoodFormScreen({super.key});

  @override
  State<RetailFoodFormScreen> createState() => _RetailFoodFormScreenState();
}

class _RetailFoodFormScreenState extends State<RetailFoodFormScreen> {
  final RetailFoodService _service = RetailFoodService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController(text: '-- Pilih Supplier --');

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  List<Map<String, dynamic>> _warehouseOutletsFiltered = [];
  List<Map<String, dynamic>> _suppliers = [];
  int? _userOutletId;

  int? _outletId;
  int? _warehouseOutletId;
  int? _supplierId;
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  bool _isLoadingData = true;

  final List<_ItemRow> _items = [];
  final List<XFile> _invoiceFiles = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _items.add(_ItemRow());
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    _supplierNameController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _openSupplierSearch() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplierSearchModal(suppliers: _suppliers),
    );
    if (!mounted) return;
    if (selected == null) return; // dismiss tanpa pilih = tidak ubah
    if (selected['_clear'] == true) {
      setState(() {
        _supplierId = null;
        _supplierNameController.text = '-- Pilih Supplier --';
      });
    } else {
      setState(() {
        _supplierId = selected['id'] as int?;
        _supplierNameController.text = selected['name']?.toString() ?? '-- Pilih Supplier --';
      });
    }
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoadingData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _outlets = List<Map<String, dynamic>>.from(result['outlets'] ?? []);
        _warehouseOutlets = List<Map<String, dynamic>>.from(result['warehouse_outlets'] ?? []);
        _suppliers = List<Map<String, dynamic>>.from(result['suppliers'] ?? []);
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
    if (_warehouseOutletId != null &&
        !_warehouseOutletsFiltered.any((w) => (w['id'] ?? 0) == _warehouseOutletId)) {
      _warehouseOutletId = null;
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
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickInvoiceCamera() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null && mounted) setState(() => _invoiceFiles.add(picked));
  }

  Future<void> _pickInvoiceGallery() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null && mounted) setState(() => _invoiceFiles.add(picked));
  }

  void _removeInvoiceAt(int index) {
    setState(() => _invoiceFiles.removeAt(index));
  }

  Future<void> _openItemSearch(int index) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemSearchModal(service: _service),
    );
    if (selected != null && mounted) {
      final itemId = selected['id'] is int ? selected['id'] as int : (int.tryParse(selected['id']?.toString() ?? '0') ?? 0);
      final itemName = selected['name']?.toString() ?? '';
      final unitsData = await _service.getItemUnits(
        itemId,
        paymentMethod: _paymentMethod,
        outletId: _outletId,
      );
      if (!mounted) return;
      final units = (unitsData?['units'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final defaultUnit = unitsData?['default_unit'] as Map<String, dynamic>?;
      final defaultPrice = (unitsData?['default_price'] ?? 0) is num
          ? (unitsData!['default_price'] as num).toDouble()
          : double.tryParse(unitsData?['default_price']?.toString() ?? '0') ?? 0.0;

      setState(() {
        _items[index].itemId = itemId;
        _items[index].itemName = itemName;
        _items[index].nameController.text = itemName;
        _items[index].units = units;
        _items[index].unitId = defaultUnit?['id'];
        _items[index].unitName = defaultUnit?['name'] ?? (units.isNotEmpty ? units.first['name']?.toString() : null);
        _items[index].priceController.text = defaultPrice > 0 ? defaultPrice.toStringAsFixed(0) : '';
      });
    }
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0;
  }

  void _showMessage(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  Future<void> _submit() async {
    if (_outletId == null) {
      _showMessage('Pilih outlet');
      return;
    }
    if (_warehouseOutletId == null) {
      _showMessage('Pilih warehouse outlet');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final row in _items) {
      final qty = _parseNum(row.qtyController.text);
      final price = _parseNum(row.priceController.text);
      if (row.itemId == null || row.itemName == null || row.itemName!.isEmpty) {
        _showMessage('Pilih item untuk setiap baris');
        return;
      }
      if (qty <= 0 || row.unitId == null || row.unitName == null || row.unitName!.isEmpty) {
        _showMessage('Lengkapi qty dan unit untuk: ${row.itemName}');
        return;
      }
      if (price < 0) {
        _showMessage('Harga tidak valid untuk: ${row.itemName}');
        return;
      }
      itemsPayload.add({
        'item_name': row.itemName,
        'qty': qty,
        'unit': row.unitName,
        'price': price,
        'unit_id': row.unitId,
      });
    }

    await _showPreviewDialog(itemsPayload);
  }

  Future<void> _showPreviewDialog(List<Map<String, dynamic>> itemsPayload) async {
    final total = itemsPayload.fold<double>(
      0,
      (sum, e) => sum + (_parseNum(e['qty']) * _parseNum(e['price'])),
    );
    String outletName = '-';
    for (final o in _outlets) {
      final id = o['id_outlet'] ?? o['id'];
      if ((id is int ? id : int.tryParse(id?.toString() ?? '0')) == _outletId) {
        outletName = o['nama_outlet']?.toString() ?? '-';
        break;
      }
    }
    String warehouseName = '-';
    for (final w in _warehouseOutletsFiltered) {
      if ((w['id'] as int) == _warehouseOutletId) {
        warehouseName = w['name']?.toString() ?? '-';
        break;
      }
    }
    final supplierName = _supplierId != null ? (_supplierNameController.text != '-- Pilih Supplier --' ? _supplierNameController.text : '-') : '-';
    final paymentLabel = _paymentMethod == 'contra_bon' ? 'Contra Bon' : 'Cash';
    final notes = _notesController.text.trim();
    final dateText = _dateController.text;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Preview Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _previewRow('Tanggal', dateText),
                    _previewRow('Outlet', outletName),
                    _previewRow('Gudang', warehouseName),
                    _previewRow('Metode Pembayaran', paymentLabel),
                    if (supplierName.isNotEmpty && supplierName != '-') _previewRow('Supplier', supplierName),
                    if (notes.isNotEmpty) _previewRow('Catatan', notes),
                    const SizedBox(height: 12),
                    const Text('Item', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...itemsPayload.map((e) {
                      final q = _parseNum(e['qty']);
                      final p = _parseNum(e['price']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${e['item_name']} • ${q.toStringAsFixed(0)} ${e['unit']} × ${NumberFormat('#,##0', 'id_ID').format(p)} = Rp ${NumberFormat('#,##0', 'id_ID').format(q * p)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }),
                    if (_invoiceFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Lampiran: ${_invoiceFiles.length} file', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                    const SizedBox(height: 12),
                    Text('Total: Rp ${NumberFormat('#,##0', 'id_ID').format(total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Color(0xFF64748B))),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) await _submitConfirm(itemsPayload);
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Future<void> _submitConfirm(List<Map<String, dynamic>> itemsPayload) async {
    setState(() => _isLoading = true);
    final result = await _service.store(
      outletId: _outletId!,
      transactionDate: _dateController.text,
      warehouseOutletId: _warehouseOutletId,
      paymentMethod: _paymentMethod,
      supplierId: _supplierId,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      items: itemsPayload,
      invoiceFiles: _invoiceFiles.isEmpty ? null : _invoiceFiles,
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tambah Retail Food',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildOutletCard(),
                  const SizedBox(height: 16),
                  _buildPaymentCard(),
                  const SizedBox(height: 16),
                  _buildInvoiceCard(),
                  const SizedBox(height: 16),
                  _buildItemsCard(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
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
                decoration: _inputDecoration('Tanggal Transaksi'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: _inputDecoration('Catatan (opsional)'),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outlet & Gudang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                _warehouseOutletId = null;
                _filterWarehouses();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _warehouseOutletId,
            decoration: _inputDecoration('Warehouse Outlet'),
            items: _warehouseOutletsFiltered.map((w) {
              return DropdownMenuItem<int>(
                value: w['id'] as int,
                child: Text(w['name']?.toString() ?? '-'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _warehouseOutletId = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
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
          const Text('Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            isExpanded: true,
            decoration: _inputDecoration('Metode Pembayaran'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'contra_bon', child: Text('Contra Bon')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openSupplierSearch,
            child: AbsorbPointer(
              child: TextField(
                controller: _supplierNameController,
                decoration: _inputDecoration('Supplier (opsional)').copyWith(
                  suffixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                ),
                readOnly: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
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
          const Text('Upload Invoice / Bon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Foto atau upload bon/invoice (opsional). Format: JPG, PNG.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickInvoiceCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text('Ambil Foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickInvoiceGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Galeri'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          if (_invoiceFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_invoiceFiles.length, (i) {
                final file = _invoiceFiles[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _removeInvoiceAt(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Item', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah Item'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          ...List.generate(_items.length, (i) => _buildItemRow(_items[i], i)),
        ],
      ),
    );
  }

  Widget _buildItemRow(_ItemRow row, int index) {
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
                      controller: row.nameController,
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.qtyController,
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
                child: _buildUnitDropdown(row),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: row.priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Harga',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _unitIdFromMap(Map<String, dynamic> u) {
    if (u['id'] is int) return u['id'] as int;
    return int.tryParse(u['id']?.toString() ?? '0') ?? 0;
  }

  /// Dropdown unit dengan deduplikasi id agar tidak error "2 or more DropdownMenuItem with same value"
  Widget _buildUnitDropdown(_ItemRow row) {
    final seenIds = <int>{};
    final uniqueUnits = row.units.where((u) {
      final id = _unitIdFromMap(u);
      if (seenIds.contains(id)) return false;
      seenIds.add(id);
      return true;
    }).toList();
    final matchCount = row.unitId == null ? 0 : uniqueUnits.where((u) => _unitIdFromMap(u) == row.unitId).length;
    final value = (matchCount == 1) ? row.unitId : null;
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Unit',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      items: uniqueUnits.map((u) {
        final id = _unitIdFromMap(u);
        return DropdownMenuItem<int>(
          value: id,
          child: Text(u['name']?.toString() ?? '-', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (v) {
        setState(() {
          row.unitId = v;
          for (final u in row.units) {
            if (_unitIdFromMap(u) == v) {
              row.unitName = u['name']?.toString();
              break;
            }
          }
        });
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
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

class _ItemRow {
  int? itemId;
  String? itemName;
  List<Map<String, dynamic>> units = [];
  int? unitId;
  String? unitName;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _SupplierSearchModal extends StatefulWidget {
  final List<Map<String, dynamic>> suppliers;

  const _SupplierSearchModal({required this.suppliers});

  @override
  State<_SupplierSearchModal> createState() => _SupplierSearchModalState();
}

class _SupplierSearchModalState extends State<_SupplierSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return widget.suppliers;
    final q = _query.trim().toLowerCase();
    return widget.suppliers.where((s) {
      final name = (s['name']?.toString() ?? '').toLowerCase();
      return name.contains(q);
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
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari supplier...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
            title: const Text('-- Kosongkan supplier --', style: TextStyle(color: Color(0xFF64748B))),
            onTap: () => Navigator.pop(context, {'_clear': true}),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final s = _filtered[i];
                final name = s['name']?.toString() ?? '-';
                return ListTile(
                  title: Text(name, overflow: TextOverflow.ellipsis),
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

class _ItemSearchModal extends StatefulWidget {
  final RetailFoodService service;

  const _ItemSearchModal({required this.service});

  @override
  State<_ItemSearchModal> createState() => _ItemSearchModalState();
}

class _ItemSearchModalState extends State<_ItemSearchModal> {
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
    final res = await widget.service.searchItems(q);
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
                ? const Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF2563EB)))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.length < 2
                              ? 'Ketik min. 2 karakter untuk cari'
                              : 'Tidak ada item ditemukan',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      )
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
