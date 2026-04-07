import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/warehouse_stock_adjustment_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseStockAdjustmentCreateScreen extends StatefulWidget {
  const WarehouseStockAdjustmentCreateScreen({super.key});

  @override
  State<WarehouseStockAdjustmentCreateScreen> createState() =>
      _WarehouseStockAdjustmentCreateScreenState();
}

class _WarehouseStockAdjustmentCreateScreenState
    extends State<WarehouseStockAdjustmentCreateScreen> {
  final WarehouseStockAdjustmentService _service = WarehouseStockAdjustmentService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  List<_ItemRow> _items = [];
  bool _isLoading = false;
  bool _isLoadingWarehouses = true;
  int? _warehouseId;
  String? _type;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _items.add(_ItemRow());
    _loadWarehouses();
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

  Future<void> _loadWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
    final list = await _service.getWarehouses();
    if (mounted) {
      setState(() {
        _warehouses = list;
        _isLoadingWarehouses = false;
      });
    }
  }

  void _addItem() {
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  Future<void> _openItemSearch(int index) async {
    if (_warehouseId == null) {
      _showMessage('Pilih gudang terlebih dahulu');
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
    if (selected != null && mounted) {
      setState(() {
        final row = _items[index];
        row.itemId = _parseInt(selected['id']);
        row.itemName = selected['name']?.toString() ?? '';
        final units = <String>{};
        for (final u in [
          selected['unit_small'],
          selected['unit_medium'],
          selected['unit_large'],
        ]) {
          if (u != null && u.toString().trim().isNotEmpty) units.add(u.toString());
        }
        row.availableUnits = units.toList();
        row.selectedUnit = row.availableUnits.isNotEmpty ? row.availableUnits.first : null;
      });
    }
  }

  String? _warehouseName() {
    if (_warehouseId == null) return null;
    for (final w in _warehouses) {
      if (_parseInt(w['id']) == _warehouseId) return w['name']?.toString();
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (_dateController.text.isEmpty ||
        _warehouseId == null ||
        _type == null ||
        _reasonController.text.trim().isEmpty) {
      _showMessage('Tanggal, Gudang, Tipe, dan Alasan wajib diisi');
      return;
    }
    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '.')) ?? 0;
      if (item.itemId == null || qty <= 0 || item.selectedUnit == null || item.selectedUnit!.isEmpty) {
        _showMessage('Setiap item wajib dipilih dengan qty dan unit');
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PreviewDialog(
        date: _dateController.text,
        warehouseName: _warehouseName() ?? '-',
        type: _type!,
        items: _items.map((r) => _PreviewItem(
          name: r.itemName,
          qty: double.tryParse(r.qtyController.text.replaceAll(',', '.')) ?? 0,
          unit: r.selectedUnit ?? '-',
          note: r.noteController.text.trim(),
        )).toList(),
        reason: _reasonController.text.trim(),
      ),
    );
    if (confirm != true || !mounted) return;

    await _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _isLoading = true);
    final itemsPayload = _items.map((item) {
      final qty = double.tryParse(item.qtyController.text.replaceAll(',', '.')) ?? 0;
      return {
        'item_id': item.itemId,
        'qty': qty,
        'selected_unit': item.selectedUnit,
        if (item.noteController.text.trim().isNotEmpty) 'note': item.noteController.text.trim(),
      };
    }).toList();

    final result = await _service.store(
      date: _dateController.text,
      warehouseId: _warehouseId!,
      type: _type!,
      reason: _reasonController.text.trim(),
      items: itemsPayload,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil disimpan'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal menyimpan');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static const _primary = Color(0xFF6366F1);
  static const _primaryDark = Color(0xFF4F46E5);
  static const _infoBg = Color(0xFFEEF2FF);
  static const _itemsBg = Color(0xFFF5F3FF);
  static const _reasonBg = Color(0xFFFFFBEB);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Stock Adjustment',
      showDrawer: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primary.withOpacity(0.06),
              Colors.white,
            ],
          ),
        ),
        child: _isLoadingWarehouses
            ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
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
                      iconColor: const Color(0xFF4F46E5),
                      child: Column(
                        children: [
                          _buildDateField(),
                          const SizedBox(height: 14),
                          _buildWarehouseDropdown(),
                          const SizedBox(height: 14),
                          _buildTypeDropdown(),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Alasan / Catatan',
                      icon: Icons.note_alt_outlined,
                      iconBg: _reasonBg,
                      iconColor: const Color(0xFFD97706),
                      child: TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Masukkan alasan penyesuaian stok...',
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
                        onTap: _isLoading ? null : _submit,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: _isLoading ? null : const LinearGradient(
                              colors: [_primary, _primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            color: _isLoading ? Colors.grey.shade300 : null,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Simpan Adjustment',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Stock Adjustment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buat penyesuaian stok gudang',
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                ),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
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
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dateController.text.isNotEmpty
              ? (DateTime.tryParse(_dateController.text) ?? DateTime.now())
              : DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: _dateController,
          decoration: _inputDecoration('Tanggal', suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: _primary)),
        ),
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return DropdownButtonFormField<int>(
      value: _warehouseId,
      decoration: _inputDecoration('Gudang'),
      dropdownColor: Colors.white,
      items: [
        const DropdownMenuItem(value: null, child: Text('Pilih Gudang')),
        ..._warehouses.map((w) {
          final id = _parseInt(w['id']);
          final name = w['name']?.toString() ?? '-';
          return DropdownMenuItem(value: id, child: Text(name));
        }),
      ],
      onChanged: (v) => setState(() => _warehouseId = v),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: _inputDecoration('Tipe'),
      dropdownColor: Colors.white,
      items: const [
        DropdownMenuItem(value: null, child: Text('Pilih Tipe')),
        DropdownMenuItem(value: 'in', child: Text('Stock In')),
        DropdownMenuItem(value: 'out', child: Text('Stock Out')),
      ],
      onChanged: (v) => setState(() => _type = v),
    );
  }

  Widget _buildItemRow(int index) {
    final row = _items[index];
    final hasItem = row.itemName.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: hasItem ? _itemsBg.withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasItem ? _primary.withOpacity(0.3) : Colors.grey.shade200,
          width: hasItem ? 1.5 : 1,
        ),
        boxShadow: hasItem
            ? [BoxShadow(color: _primary.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Icon(Icons.shopping_basket_outlined, size: 18, color: hasItem ? _primary : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Item ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasItem ? _primary : Colors.grey.shade600,
                  ),
                ),
                if (_items.length > 1) ...[
                  const Spacer(),
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: Icon(Icons.delete_outline_rounded, size: 22, color: Colors.red.shade400),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _openItemSearch(index),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration('Item', suffixIcon: const Icon(Icons.search_rounded, size: 20, color: _primary)),
                    child: Text(
                      row.itemName.isEmpty ? 'Tap untuk cari item...' : row.itemName,
                      style: TextStyle(
                        fontSize: 14,
                        color: row.itemName.isEmpty ? Colors.grey : const Color(0xFF0F172A),
                        fontWeight: row.itemName.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('Qty'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: row.selectedUnit,
                        decoration: _inputDecoration('Unit'),
                        dropdownColor: Colors.white,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Unit')),
                          ...(row.availableUnits.map((u) => DropdownMenuItem(value: u, child: Text(u)))),
                        ],
                        onChanged: (v) => setState(() => row.selectedUnit = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: row.noteController,
                  decoration: _inputDecoration('Catatan (opsional)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewItem {
  final String name;
  final double qty;
  final String unit;
  final String note;

  const _PreviewItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.note,
  });
}

class _PreviewDialog extends StatelessWidget {
  static const _primary = Color(0xFF6366F1);
  static const _primaryDark = Color(0xFF4F46E5);

  final String date;
  final String warehouseName;
  final String type;
  final List<_PreviewItem> items;
  final String reason;

  const _PreviewDialog({
    required this.date,
    required this.warehouseName,
    required this.type,
    required this.items,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = type == 'in' ? 'Stock In' : 'Stock Out';
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
                gradient: const LinearGradient(
                  colors: [_primary, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.preview_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Preview Adjustment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                    _previewRow(Icons.calendar_today_rounded, 'Tanggal', date),
                    const SizedBox(height: 10),
                    _previewRow(Icons.warehouse_rounded, 'Gudang', warehouseName),
                    const SizedBox(height: 10),
                    _previewRow(Icons.swap_horiz_rounded, 'Tipe', typeLabel),
                    const SizedBox(height: 16),
                    const Text(
                      'Detail Item',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.asMap().entries.map((e) {
                      final i = e.key + 1;
                      final item = e.value;
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
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '${item.qty} ${item.unit}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (item.note.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Catatan: ${item.note}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    const Text(
                      'Alasan / Catatan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
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

  Widget _previewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow {
  int? itemId;
  String itemName = '';
  List<String> availableUnits = [];
  String? selectedUnit;
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    noteController.dispose();
  }
}

class _ItemSearchSheet extends StatefulWidget {
  final int warehouseId;
  final WarehouseStockAdjustmentService service;

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
    if (q.isEmpty) {
      setState(() => _list = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final list = await widget.service.searchItems(q, warehouseId: widget.warehouseId);
      if (mounted) {
        setState(() {
          _list = list;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Cari nama item (min. 1 karakter)',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onChanged: (_) => _search(),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: const Text('Cari'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _searching
                ? const Center(child: AppLoadingIndicator(size: 28, color: Color(0xFF6366F1)))
                : _list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchController.text.trim().isEmpty
                                ? 'Ketik nama item lalu tap Cari atau tekan Enter'
                                : 'Tidak ada item untuk "${_searchController.text.trim()}". Coba kata kunci lain.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _list.length,
                        itemBuilder: (ctx, i) {
                          final item = _list[i];
                          final name = item['name']?.toString() ?? '-';
                          final sku = item['sku']?.toString();
                          final unit = item['unit_small']?.toString() ?? item['unit_medium']?.toString() ?? item['unit_large']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: sku != null && sku.isNotEmpty
                                  ? Text('SKU: $sku', style: const TextStyle(fontSize: 12))
                                  : null,
                              trailing: unit.isNotEmpty
                                  ? Chip(
                                      label: Text(unit, style: const TextStyle(fontSize: 12)),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(ctx, item),
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
