import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_food_return_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletFoodReturnFormScreen extends StatefulWidget {
  const OutletFoodReturnFormScreen({super.key});

  @override
  State<OutletFoodReturnFormScreen> createState() => _OutletFoodReturnFormScreenState();
}

class _OutletFoodReturnFormScreenState extends State<OutletFoodReturnFormScreen> {
  final OutletFoodReturnService _service = OutletFoodReturnService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<dynamic> _warehouseOutlets = [];
  List<dynamic> _goodReceives = [];
  List<dynamic> _grItems = [];
  int? _userOutletId;

  int? _outletId;
  int? _warehouseOutletId;
  int? _goodReceiveId;
  bool _isLoadingData = true;
  bool _isLoadingWarehouses = false;
  bool _isLoadingGR = false;
  bool _isLoadingItems = false;
  bool _isSubmitting = false;

  // gr_item_id -> return_qty (string from TextField)
  final Map<int, TextEditingController> _returnQtyControllers = {};

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    for (final c in _returnQtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoadingData = true);
    final result = await _service.getCreateData();
    if (mounted && result != null && result['success'] == true) {
      setState(() {
        _outlets = result['outlets'] != null ? List<Map<String, dynamic>>.from(result['outlets'] as List) : [];
        _userOutletId = result['user_outlet_id'] is int ? result['user_outlet_id'] as int : int.tryParse(result['user_outlet_id']?.toString() ?? '');
        _isLoadingData = false;
        if (_userOutletId != null && _userOutletId != 1 && _outlets.isNotEmpty) {
          _outletId = _outlets.first['id_outlet'] ?? _outlets.first['id'];
          _onOutletChanged();
        }
      });
    } else if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _onOutletChanged() async {
    setState(() {
      _warehouseOutletId = null;
      _goodReceiveId = null;
      _goodReceives = [];
      _grItems = [];
      _warehouseOutlets = [];
      _clearReturnQtyControllers();
    });
    if (_outletId == null) return;
    setState(() => _isLoadingWarehouses = true);
    final list = await _service.getWarehouseOutlets(_outletId!);
    if (mounted) {
      setState(() {
        _warehouseOutlets = list;
        _isLoadingWarehouses = false;
      });
    }
  }

  Future<void> _onWarehouseChanged() async {
    setState(() {
      _goodReceiveId = null;
      _goodReceives = [];
      _grItems = [];
      _clearReturnQtyControllers();
    });
    if (_outletId == null || _warehouseOutletId == null) return;
    setState(() => _isLoadingGR = true);
    final list = await _service.getGoodReceives(outletId: _outletId!, warehouseOutletId: _warehouseOutletId!);
    if (mounted) {
      setState(() {
        _goodReceives = list;
        _isLoadingGR = false;
      });
    }
  }

  Future<void> _onGoodReceiveChanged() async {
    for (final c in _returnQtyControllers.values) {
      c.dispose();
    }
    _returnQtyControllers.clear();
    setState(() => _grItems = []);
    if (_goodReceiveId == null || _outletId == null || _warehouseOutletId == null) return;
    setState(() => _isLoadingItems = true);
    final list = await _service.getGoodReceiveItems(
      goodReceiveId: _goodReceiveId!,
      outletId: _outletId!,
      warehouseOutletId: _warehouseOutletId!,
    );
    if (mounted) {
      for (final it in list) {
        final m = it is Map ? Map<String, dynamic>.from(it as Map) : {};
        final grItemId = m['gr_item_id'] is int ? m['gr_item_id'] as int : int.tryParse(m['gr_item_id']?.toString() ?? '');
        if (grItemId != null) {
          _returnQtyControllers[grItemId] = TextEditingController(text: '0');
        }
      }
      setState(() {
        _grItems = list;
        _isLoadingItems = false;
      });
    }
  }

  void _clearReturnQtyControllers() {
    for (final c in _returnQtyControllers.values) {
      c.dispose();
    }
    _returnQtyControllers.clear();
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int? _getGrItemId(dynamic item) {
    final m = item is Map ? Map<String, dynamic>.from(item as Map) : {};
    final v = m['gr_item_id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  Future<void> _submit() async {
    if (_outletId == null || _warehouseOutletId == null || _goodReceiveId == null) {
      _showMessage('Pilih outlet, gudang, dan good receive');
      return;
    }
    final returnDate = _dateController.text.trim();
    if (returnDate.isEmpty) {
      _showMessage('Pilih tanggal return');
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final it in _grItems) {
      final m = it is Map ? Map<String, dynamic>.from(it as Map) : {};
      final grItemId = _getGrItemId(it);
      final itemId = m['item_id'] is int ? m['item_id'] as int : int.tryParse(m['item_id']?.toString() ?? '');
      final unitId = m['unit_id'] is int ? m['unit_id'] as int : int.tryParse(m['unit_id']?.toString() ?? '');
      if (grItemId == null || itemId == null || unitId == null) continue;
      final c = _returnQtyControllers[grItemId];
      final qty = c != null ? (_parseNum(double.tryParse(c.text.trim().replaceAll(',', '.')))) : 0;
      if (qty <= 0) continue;
      final receivedQty = _parseNum(m['received_qty']);
      if (qty > receivedQty) {
        _showMessage('Qty return tidak boleh melebihi qty terima (${receivedQty.toInt()})');
        return;
      }
      items.add({
        'gr_item_id': grItemId,
        'item_id': itemId,
        'unit_id': unitId,
        'return_qty': qty,
      });
    }
    if (items.isEmpty) {
      _showMessage('Pilih minimal 1 item dengan qty return > 0');
      return;
    }
    setState(() => _isSubmitting = true);
    final result = await _service.store(
      outletFoodGoodReceiveId: _goodReceiveId!,
      outletId: _outletId!,
      warehouseOutletId: _warehouseOutletId!,
      returnDate: returnDate,
      items: items,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return berhasil disimpan'), backgroundColor: Color(0xFF059669)),
        );
        Navigator.pop(context, true);
      } else {
        _showMessage(result['message']?.toString() ?? 'Gagal menyimpan return');
      }
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Outlet Food Return',
      showDrawer: false,
      body: _isLoadingData
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFFEA580C)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Outlet', _buildOutletDropdown()),
                  _buildSection('Gudang Outlet', _buildWarehouseDropdown()),
                  _buildSection('Good Receive', _buildGoodReceiveDropdown()),
                  _buildSection('Tanggal Return', _buildDateField()),
                  _buildSection('Keterangan', _buildNotesField()),
                  if (_grItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildItemsSection(),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan Return'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildOutletDropdown() {
    final isSingleOutlet = _userOutletId != null && _userOutletId != 1 && _outlets.length <= 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _outletId,
          isExpanded: true,
          hint: const Text('Pilih outlet'),
          items: _outlets.map((o) {
            final id = o['id_outlet'] is int ? o['id_outlet'] as int : int.tryParse(o['id_outlet']?.toString() ?? '');
            final name = (o['nama_outlet'] ?? '-').toString();
            return DropdownMenuItem<int>(value: id, child: Text(name));
          }).toList(),
          onChanged: isSingleOutlet ? null : (v) {
            setState(() {
              _outletId = v;
              _onOutletChanged();
            });
          },
        ),
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    if (_outletId == null) return const SizedBox.shrink();
    if (_isLoadingWarehouses) return const Padding(padding: EdgeInsets.all(12), child: Center(child: AppLoadingIndicator(size: 22, color: Color(0xFFEA580C))));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _warehouseOutletId,
          isExpanded: true,
          hint: const Text('Pilih gudang'),
          items: _warehouseOutlets.map((w) {
            final m = w is Map ? Map<String, dynamic>.from(w as Map) : {};
            final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '');
            final name = (m['name'] ?? m['code'] ?? '-').toString();
            return DropdownMenuItem<int>(value: id, child: Text(name));
          }).toList(),
          onChanged: (v) {
            setState(() {
              _warehouseOutletId = v;
              _onWarehouseChanged();
            });
          },
        ),
      ),
    );
  }

  Widget _buildGoodReceiveDropdown() {
    if (_warehouseOutletId == null) return const SizedBox.shrink();
    if (_isLoadingGR) return const Padding(padding: EdgeInsets.all(12), child: Center(child: AppLoadingIndicator(size: 22, color: Color(0xFFEA580C))));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _goodReceiveId,
          isExpanded: true,
          hint: const Text('Pilih good receive (GR 24 jam terakhir)'),
          items: _goodReceives.map((g) {
            final m = g is Map ? Map<String, dynamic>.from(g as Map) : {};
            final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '');
            final number = (m['number'] ?? '-').toString();
            final date = m['receive_date']?.toString();
            final label = date != null ? '$number (${DateFormat('dd/MM/yy').format(DateTime.tryParse(date) ?? DateTime.now())})' : number;
            return DropdownMenuItem<int>(value: id, child: Text(label));
          }).toList(),
          onChanged: (v) {
            setState(() {
              _goodReceiveId = v;
              _onGoodReceiveChanged();
            });
          },
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: Color(0xFF64748B)),
            const SizedBox(width: 12),
            Text(_dateController.text.isEmpty ? 'Pilih tanggal' : _dateController.text, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: 'Catatan (opsional)',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }

  Widget _buildItemsSection() {
    if (_isLoadingItems) return const Center(child: Padding(padding: EdgeInsets.all(24), child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB))));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Item Return (isi qty yang di-return)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          ..._grItems.asMap().entries.map((e) {
            final it = e.value;
            final m = it is Map ? Map<String, dynamic>.from(it as Map) : {};
            final grItemId = _getGrItemId(it);
            final name = (m['item_name'] ?? '-').toString();
            final sku = (m['sku'] ?? '').toString();
            final receivedQty = _parseNum(m['received_qty']);
            final unitName = (m['unit_name'] ?? '').toString();
            final controller = grItemId != null ? _returnQtyControllers[grItemId] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (sku.isNotEmpty) Text('SKU: $sku', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Terima: ${receivedQty.toInt()} $unitName', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(
                        labelText: 'Qty return',
                        hintText: '0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
