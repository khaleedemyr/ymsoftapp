import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/retail_nono_food_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailNonoFoodFormScreen extends StatefulWidget {
  const RetailNonoFoodFormScreen({super.key});

  @override
  State<RetailNonoFoodFormScreen> createState() => _RetailNonoFoodFormScreenState();
}

class _RetailNonoFoodFormScreenState extends State<RetailNonoFoodFormScreen> {
  final RetailNonFoodService _service = RetailNonFoodService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _categoryBudgetNameController = TextEditingController(text: '-- Pilih Kategori Budget --');
  final TextEditingController _supplierNameController = TextEditingController(text: '-- Pilih Supplier --');

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _categoryBudgets = [];
  List<Map<String, dynamic>> _suppliers = [];
  int? _userOutletId;

  int? _outletId;
  int? _categoryBudgetId;
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
    _categoryBudgetNameController.dispose();
    _supplierNameController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoadingData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _outlets = List<Map<String, dynamic>>.from(result['outlets'] ?? []);
        _categoryBudgets = List<Map<String, dynamic>>.from(result['category_budgets'] ?? []);
        _suppliers = List<Map<String, dynamic>>.from(result['suppliers'] ?? []);
        _userOutletId = result['user_outlet_id'] is int ? result['user_outlet_id'] as int : null;
        if (_userOutletId != null && _userOutletId != 1 && _outlets.isNotEmpty) {
          final firstId = _outlets.first['id_outlet'] ?? _outlets.first['id'];
          _outletId = firstId is int ? firstId : int.tryParse(firstId.toString());
        }
        _isLoadingData = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingData = false);
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

  String _categoryBudgetDisplayText(Map<String, dynamic> c) {
    return '${c['division'] ?? ''} - ${c['name'] ?? '-'}'.trim();
  }

  Future<void> _openCategoryBudgetSearch() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryBudgetSearchModal(categoryBudgets: _categoryBudgets, displayText: _categoryBudgetDisplayText),
    );
    if (!mounted) return;
    if (selected == null) return;
    if (selected['_clear'] == true) {
      setState(() {
        _categoryBudgetId = null;
        _categoryBudgetNameController.text = '-- Pilih Kategori Budget --';
      });
    } else {
      final id = selected['id'] is int ? selected['id'] as int : int.tryParse(selected['id']?.toString() ?? '0');
      setState(() {
        _categoryBudgetId = id;
        _categoryBudgetNameController.text = _categoryBudgetDisplayText(selected);
      });
    }
  }

  Future<void> _openSupplierSearch() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplierSearchModal(suppliers: _suppliers),
    );
    if (!mounted) return;
    if (selected == null) return;
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
    if (_categoryBudgetId == null) {
      _showMessage('Pilih kategori budget');
      return;
    }
    if (_supplierId == null) {
      _showMessage('Pilih supplier');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final row in _items) {
      final qty = _parseNum(row.qtyController.text);
      final price = _parseNum(row.priceController.text);
      final itemName = row.nameController.text.trim();
      if (itemName.isEmpty) {
        _showMessage('Isi nama item untuk setiap baris');
        return;
      }
      if (qty <= 0) {
        _showMessage('Qty harus > 0 untuk: $itemName');
        return;
      }
      if (row.unitController.text.trim().isEmpty) {
        _showMessage('Isi unit untuk: $itemName');
        return;
      }
      if (price < 0) {
        _showMessage('Harga tidak valid untuk: $itemName');
        return;
      }
      itemsPayload.add({
        'item_name': itemName,
        'qty': qty,
        'unit': row.unitController.text.trim(),
        'price': price,
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
    String categoryText = '-';
    for (final c in _categoryBudgets) {
      final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id']?.toString() ?? '0');
      if (id == _categoryBudgetId) {
        categoryText = _categoryBudgetDisplayText(c);
        break;
      }
    }
    String supplierName = '-';
    for (final s in _suppliers) {
      final id = s['id'] is int ? s['id'] as int : int.tryParse(s['id']?.toString() ?? '0');
      if (id == _supplierId) {
        supplierName = s['name']?.toString() ?? '-';
        break;
      }
    }
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
                    _previewRow('Kategori Budget', categoryText),
                    _previewRow('Metode Pembayaran', paymentLabel),
                    _previewRow('Supplier', supplierName),
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
                    Text('Total: Rp ${NumberFormat('#,##0', 'id_ID').format(total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 14)),
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
      categoryBudgetId: _categoryBudgetId!,
      paymentMethod: _paymentMethod,
      supplierId: _supplierId!,
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
      title: 'Tambah Retail Non Food',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF16A34A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildOutletCard(),
                  const SizedBox(height: 16),
                  _buildCategoryAndPaymentCard(),
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
          const Text('Outlet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _outletId,
            isExpanded: true,
            decoration: _inputDecoration('Outlet'),
            items: _outlets.map((o) {
              final id = o['id_outlet'] ?? o['id'];
              return DropdownMenuItem<int>(
                value: id is int ? id : int.tryParse(id.toString()),
                child: Text(o['nama_outlet']?.toString() ?? '-', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) => setState(() => _outletId = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAndPaymentCard() {
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
          const Text('Kategori Budget & Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openCategoryBudgetSearch,
            child: AbsorbPointer(
              child: TextField(
                controller: _categoryBudgetNameController,
                decoration: _inputDecoration('Kategori Budget').copyWith(
                  suffixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                ),
                readOnly: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                decoration: _inputDecoration('Supplier').copyWith(
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
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
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
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
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
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF16A34A)),
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
                flex: 2,
                child: TextField(
                  controller: row.nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama item',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                child: TextField(
                  controller: row.unitController,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    hintText: 'pcs, kg, dll',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
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
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    unitController.dispose();
    priceController.dispose();
  }
}

class _CategoryBudgetSearchModal extends StatefulWidget {
  final List<Map<String, dynamic>> categoryBudgets;
  final String Function(Map<String, dynamic>) displayText;

  const _CategoryBudgetSearchModal({required this.categoryBudgets, required this.displayText});

  @override
  State<_CategoryBudgetSearchModal> createState() => _CategoryBudgetSearchModalState();
}

class _CategoryBudgetSearchModalState extends State<_CategoryBudgetSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return widget.categoryBudgets;
    final q = _query.trim().toLowerCase();
    return widget.categoryBudgets.where((c) {
      final text = widget.displayText(c).toLowerCase();
      final name = (c['name']?.toString() ?? '').toLowerCase();
      final division = (c['division']?.toString() ?? '').toLowerCase();
      return text.contains(q) || name.contains(q) || division.contains(q);
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
                hintText: 'Cari kategori budget...',
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
            title: const Text('-- Kosongkan kategori --', style: TextStyle(color: Color(0xFF64748B))),
            onTap: () => Navigator.pop(context, {'_clear': true}),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final c = _filtered[i];
                final text = widget.displayText(c);
                return ListTile(
                  title: Text(text, overflow: TextOverflow.ellipsis),
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
