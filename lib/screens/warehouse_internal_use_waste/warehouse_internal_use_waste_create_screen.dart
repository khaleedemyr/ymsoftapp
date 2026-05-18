import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/native_barcode_scanner.dart';
import '../../services/warehouse_internal_use_waste_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class _LineEntry {
  int? itemId;
  String itemName;
  final TextEditingController qtyController;
  final TextEditingController lineNotesController;
  int? unitId;
  List<Map<String, dynamic>> unitOptions;

  _LineEntry()
      : qtyController = TextEditingController(),
        lineNotesController = TextEditingController(),
        itemName = '',
        unitOptions = [];

  void dispose() {
    qtyController.dispose();
    lineNotesController.dispose();
  }
}

/// Selaras web `InternalUseWaste/Create.vue` — satu dokumen, banyak baris item + catatan dokumen.
class WarehouseInternalUseWasteCreateScreen extends StatefulWidget {
  const WarehouseInternalUseWasteCreateScreen({super.key});

  @override
  State<WarehouseInternalUseWasteCreateScreen> createState() => _WarehouseInternalUseWasteCreateScreenState();
}

class _WarehouseInternalUseWasteCreateScreenState extends State<WarehouseInternalUseWasteCreateScreen> {
  final WarehouseInternalUseWasteService _service = WarehouseInternalUseWasteService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _docNotesController = TextEditingController();

  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _rukos = [];

  final List<_LineEntry> _lines = [_LineEntry()];

  bool _loadingCreateData = true;
  bool _saving = false;
  String _type = '';
  int? _warehouseId;
  int? _rukoId;

  bool _serialMode = false;
  final TextEditingController _serialInputController = TextEditingController();
  final FocusNode _serialFocusNode = FocusNode();
  final List<Map<String, dynamic>> _scannedSerials = [];
  bool _serialScanning = false;
  String _serialFeedback = '';
  bool _serialFeedbackSuccess = false;

  static const Color _primaryGreen = Color(0xFF059669);

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _docNotesController.dispose();
    _serialInputController.dispose();
    _serialFocusNode.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _loadingCreateData = true);
    final result = await _service.getCreateData();
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _warehouses = result['warehouses'] is List
            ? (result['warehouses'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : [];
        _items = result['items'] is List
            ? (result['items'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : [];
        _rukos = result['rukos'] is List
            ? (result['rukos'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : [];
      }
      _loadingCreateData = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _addRow() {
    setState(() => _lines.add(_LineEntry()));
  }

  void _removeRow(int idx) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[idx].dispose();
      _lines.removeAt(idx);
    });
  }

  Future<void> _openItemPicker(int lineIndex) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data item tidak tersedia'), backgroundColor: Colors.orange),
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ItemPickerSheet(items: _items),
    );
    if (selected == null || !mounted) return;
    final itemId = _int(selected['id']);
    final name = selected['name']?.toString() ?? selected['nama']?.toString() ?? '-';
    if (itemId == null) return;

    final line = _lines[lineIndex];
    setState(() {
      line.itemId = itemId;
      line.itemName = name;
      line.unitId = null;
      line.unitOptions = [];
    });

    final units = await _service.getItemUnits(itemId);
    if (!mounted) return;
    final seenIds = <int>{};
    final deduped = <Map<String, dynamic>>[];
    for (final u in units) {
      final id = _int(u['id']);
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        deduped.add(u);
      }
    }
    setState(() {
      line.unitOptions = deduped;
      if (line.unitOptions.isNotEmpty) {
        line.unitId = _int(line.unitOptions.first['id']);
      }
    });
  }

  Future<void> _onSerialScan() async {
    final input = _serialInputController.text.trim();
    if (input.isEmpty) return;
    if (_warehouseId == null) {
      setState(() {
        _serialFeedback = 'Pilih warehouse dulu';
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
    final result = await _service.validateSerialForIUW(
      serialNumber: input,
      warehouseId: _warehouseId!,
    );
    if (!mounted) return;
    if (result['valid'] == true) {
      final serial = result['serial'] as Map<String, dynamic>? ?? {};
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
        });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan kamera tersedia di aplikasi Android/iOS')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal buka scanner: $e')));
    }
  }

  void _removeSerial(int index) {
    setState(() => _scannedSerials.removeAt(index));
  }

  Future<void> _submit() async {
    if (_saving) return;
    final date = _dateController.text.trim();
    if (_type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tipe'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal wajib diisi'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warehouse wajib dipilih'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_type == 'internal_use' && _rukoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruko wajib dipilih untuk Internal Use'), backgroundColor: Colors.orange),
      );
      return;
    }

    final payloadItems = <Map<String, dynamic>>[];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.itemId == null) continue;
      if (l.unitId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lengkapi baris ${i + 1}: item dan unit wajib.'), backgroundColor: Colors.orange),
        );
        return;
      }
      final qty = double.tryParse(l.qtyController.text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Baris ${i + 1}: qty harus lebih dari 0.'), backgroundColor: Colors.orange),
        );
        return;
      }
      final row = <String, dynamic>{
        'item_id': l.itemId,
        'qty': qty,
        'unit_id': l.unitId,
      };
      final ln = l.lineNotesController.text.trim();
      if (ln.isNotEmpty) row['notes'] = ln;
      payloadItems.add(row);
    }

    if (payloadItems.isEmpty && _scannedSerials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal 1 baris item (qty) atau 1 nomor seri'), backgroundColor: Colors.orange),
      );
      return;
    }

    final serialPayload = _scannedSerials.map((s) => {
      'serial_id': s['serial_id'],
      'serial_number': s['serial_number'],
      'item_id': s['item_id'],
      'unit_id': s['unit_id'],
      'unit_name': s['unit_name'],
      'qty': s['qty'],
      'qty_small': s['qty_small'],
    }).toList();

    setState(() => _saving = true);
    final result = await _service.storeDocument(
      type: _type,
      date: date,
      warehouseId: _warehouseId!,
      rukoId: _type == 'internal_use' ? _rukoId : null,
      notes: _docNotesController.text.trim().isEmpty ? null : _docNotesController.text.trim(),
      items: payloadItems.isNotEmpty ? payloadItems : null,
      serialItems: serialPayload.isNotEmpty ? serialPayload : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Data berhasil disimpan!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['message']?.toString() ?? 'Gagal menyimpan data.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCreateData) {
      return AppScaffold(
        title: 'Input Internal Use & Waste',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    return AppScaffold(
      title: 'Input Internal Use & Waste',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Satu dokumen bisa berisi banyak item. Tanggal, tipe, warehouse, dan ruko (jika internal use) sama untuk semua baris.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Dokumen',
              icon: Icons.description_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('Tipe'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _type,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Pilih Tipe')),
                      DropdownMenuItem(value: 'internal_use', child: Text('Internal Use')),
                      DropdownMenuItem(value: 'spoil', child: Text('Spoil')),
                      DropdownMenuItem(value: 'waste', child: Text('Waste')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _type = v ?? '';
                        if (_type != 'internal_use') _rukoId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _label('Tanggal'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: _inputDecoration(),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_dateController.text, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.calendar_today, size: 20, color: _primaryGreen),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Warehouse'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _warehouseId,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Pilih Warehouse --', overflow: TextOverflow.ellipsis)),
                      ..._warehouses.map((w) {
                        final id = _int(w['id']);
                        final name = w['name']?.toString() ?? '-';
                        return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                      }),
                    ],
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                  if (_type == 'internal_use') ...[
                    const SizedBox(height: 16),
                    _label('Ruko'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _rukoId,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-- Pilih Ruko --', overflow: TextOverflow.ellipsis)),
                        ..._rukos.map((r) {
                          final id = _int(r['id'] ?? r['id_ruko']);
                          final name = r['name']?.toString() ?? r['nama_ruko']?.toString() ?? '-';
                          return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                        }),
                      ],
                      onChanged: (v) => setState(() => _rukoId = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _label('Catatan dokumen'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _docNotesController,
                    maxLines: 2,
                    decoration: _inputDecoration(hint: 'Opsional, berlaku untuk seluruh dokumen'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSerialModeCard(),
            if (_serialMode) ...[
              const SizedBox(height: 12),
              _buildSerialScanCard(),
            ],
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Daftar item (qty)',
              icon: Icons.inventory_2_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _primaryGreen, foregroundColor: Colors.white),
                      onPressed: _addRow,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah item'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_lines.length, (idx) => _buildLineCard(idx)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSerialModeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode Nomor Seri', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Scan serial dari gudang terpilih', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: _serialMode,
            activeColor: const Color(0xFF6366F1),
            onChanged: (v) {
              setState(() => _serialMode = v);
              if (v) Future.delayed(const Duration(milliseconds: 100), () => _serialFocusNode.requestFocus());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSerialScanCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan Nomor Seri', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
          if (_warehouseId == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Pilih warehouse terlebih dahulu', style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serialInputController,
                  focusNode: _serialFocusNode,
                  enabled: !_serialScanning && _warehouseId != null,
                  onSubmitted: (_) => _onSerialScan(),
                  decoration: const InputDecoration(
                    hintText: 'Scan / ketik serial...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(onPressed: _serialScanning ? null : _openCameraSerial, icon: const Icon(Icons.camera_alt_outlined)),
              IconButton(onPressed: _serialScanning ? null : _onSerialScan, icon: const Icon(Icons.check_circle_outline)),
            ],
          ),
          if (_serialFeedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_serialFeedback, style: TextStyle(fontSize: 12, color: _serialFeedbackSuccess ? Colors.green : Colors.red)),
            ),
          if (_scannedSerials.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${_scannedSerials.length} serial discan', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            ...List.generate(_scannedSerials.length, (i) {
              final s = _scannedSerials[i];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s['serial_number']?.toString() ?? '-', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                subtitle: Text('${s['item_name']} — ${s['qty']} ${s['unit_name']}'),
                trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => _removeSerial(i)),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildLineCard(int idx) {
    final line = _lines[idx];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Baris ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  onPressed: () => _removeRow(idx),
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Hapus baris',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _label('Item'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openItemPicker(idx),
            child: InputDecorator(
              decoration: _inputDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.itemName.isEmpty ? 'Pilih item' : line.itemName,
                      style: TextStyle(color: line.itemName.isEmpty ? Colors.grey : null),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _label('Qty'),
          const SizedBox(height: 6),
          TextFormField(
            controller: line.qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 12),
          _label('Unit'),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: line.unitId != null && line.unitOptions.any((u) => _int(u['id']) == line.unitId) ? line.unitId : null,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('-- Pilih Unit --', overflow: TextOverflow.ellipsis)),
              ...line.unitOptions.map((u) {
                final id = _int(u['id']);
                final name = u['name']?.toString() ?? '-';
                if (id == null) return null;
                return DropdownMenuItem<int>(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
              }).whereType<DropdownMenuItem<int>>(),
            ],
            onChanged: (v) => setState(() => line.unitId = v),
          ),
          const SizedBox(height: 12),
          _label('Catatan baris'),
          const SizedBox(height: 6),
          TextFormField(
            controller: line.lineNotesController,
            decoration: _inputDecoration(hint: 'Opsional'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: _primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)));
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}

class _ItemPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _ItemPickerSheet({required this.items});

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((item) {
      final name = (item['name']?.toString() ?? item['nama']?.toString() ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  static String _itemName(Map<String, dynamic> item) => item['name']?.toString() ?? item['nama']?.toString() ?? '-';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Pilih Item', style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Ketik untuk mencari item...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty ? 'Tidak ada item' : 'Tidak ada hasil untuk "${_searchController.text.trim()}"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredItems.length,
                      itemBuilder: (_, i) {
                        final item = _filteredItems[i];
                        return ListTile(
                          title: Text(_itemName(item), overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
