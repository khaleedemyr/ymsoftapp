import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/lost_breakage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

const Color _primaryColor = Color(0xFFE65100);

class LostBreakageFormScreen extends StatefulWidget {
  final int? headerId;
  const LostBreakageFormScreen({super.key, this.headerId});

  @override
  State<LostBreakageFormScreen> createState() => _LostBreakageFormScreenState();
}

class _LostBreakageFormScreenState extends State<LostBreakageFormScreen> {
  final LostBreakageService _service = LostBreakageService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _approverSearchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _submitting = false;
  int? _headerId;
  DateTime _date = DateTime.now();
  int? _ownerOutletId;
  String? _ownerOutletName;
  int? _outletId;
  String? _outletName;
  int? _warehouseOutletId;
  List<Map<String, dynamic>> _warehouseOutlets = [];
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _assetItems = [];
  final List<_FormItem> _formItems = [];
  final List<Map<String, dynamic>> _approvers = [];

  bool get _isAdmin => _userData?['id_outlet']?.toString() == '1';

  bool _unitValueValid(_FormItem fi) {
    if (fi.unitId == null) return false;
    return fi.units.any((u) => int.tryParse(u['id'].toString()) == fi.unitId);
  }

  List<DropdownMenuItem<int>> _dedupUnitItems(_FormItem fi) {
    final seen = <int>{};
    final items = <DropdownMenuItem<int>>[];
    for (final u in fi.units) {
      final id = int.tryParse(u['id'].toString());
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      items.add(DropdownMenuItem<int>(
        value: id,
        child: Text(u['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
      ));
    }
    return items;
  }

  List<DropdownMenuItem<int>> get _outletDropdownItems {
    final seen = <int>{};
    final items = <DropdownMenuItem<int>>[];
    for (final o in _outlets) {
      final id = int.tryParse(o['id']?.toString() ?? o['id_outlet']?.toString() ?? '');
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      items.add(DropdownMenuItem<int>(
        value: id,
        child: Text(o['name']?.toString() ?? o['nama_outlet']?.toString() ?? ''),
      ));
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _headerId = widget.headerId;
    _dateController.text = DateFormat('yyyy-MM-dd').format(_date);
    _init();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    _approverSearchCtrl.dispose();
    for (final item in _formItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final auth = AuthService();
    _userData = await auth.getUserData();
    _assetItems = await _service.getAssetItems();
    final meta = await _service.getFormMeta();
    if (meta != null && meta['warehouse_outlets'] is List) {
      _warehouseOutlets = (meta['warehouse_outlets'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (_isAdmin) {
      _outlets = await _service.getOutlets();
    } else if (_userData != null) {
      _ownerOutletId = int.tryParse(_userData!['id_outlet']?.toString() ?? '');
      _ownerOutletName =
          _userData!['outlet_name']?.toString() ?? _userData!['nama_outlet']?.toString();
      _outletId = _ownerOutletId;
      _outletName = _ownerOutletName;
      _outlets = await _service.getOutlets();
    }

    if (_headerId != null) {
      final res = await _service.getDetail(_headerId!);
      if (res != null && res['success'] == true) {
        final h = Map<String, dynamic>.from(res['header'] as Map);
        _date = DateTime.tryParse(h['date']?.toString() ?? '') ?? DateTime.now();
        _dateController.text = DateFormat('yyyy-MM-dd').format(_date);
        _ownerOutletId = int.tryParse(h['owner_outlet_id']?.toString() ?? '') ?? _ownerOutletId;
        _ownerOutletName = h['owner_outlet_name']?.toString() ?? _ownerOutletName;
        _outletId = int.tryParse(h['outlet_id']?.toString() ?? '');
        _outletName = h['outlet_name']?.toString() ?? _outletName;
        _warehouseOutletId = int.tryParse(h['warehouse_outlet_id']?.toString() ?? '');
        _notesController.text = h['notes']?.toString() ?? '';
        final details = res['details'] as List? ?? [];
        for (final d in details) {
          final dm = Map<String, dynamic>.from(d as Map);
          _formItems.add(_FormItem(
            itemId: int.tryParse(dm['item_id']?.toString() ?? ''),
            itemName: dm['item_name']?.toString(),
            type: dm['type']?.toString() ?? 'lost',
            qty: double.tryParse(dm['qty']?.toString() ?? '') ?? 0,
            unitId: int.tryParse(dm['unit_id']?.toString() ?? ''),
            unitName: dm['unit_name']?.toString(),
            note: dm['note']?.toString() ?? '',
            photoPath: dm['photo']?.toString(),
            units: [],
          ));
        }
        for (final item in _formItems) {
          if (item.itemId != null) {
            item.units = await _service.getItemUnits(item.itemId!);
          }
        }
      }
    }

    if (_formItems.isEmpty) _formItems.add(_FormItem());
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addItem() => setState(() => _formItems.add(_FormItem()));

  void _removeItem(int idx) {
    if (_formItems.length > 1) {
      setState(() {
        _formItems[idx].dispose();
        _formItems.removeAt(idx);
      });
    }
  }

  Future<void> _selectItem(int idx) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemPickerSheet(items: _assetItems),
    );
    if (result == null) return;
    final item = _formItems[idx];
    item.itemId = int.tryParse(result['id'].toString());
    item.itemName = result['name']?.toString();
    item.units = await _service.getItemUnits(item.itemId!);
    if (item.units.isNotEmpty) {
      item.unitId = int.tryParse(item.units.first['id'].toString());
      item.unitName = item.units.first['name']?.toString();
    }
    setState(() {});
  }

  Future<void> _pickPhoto(int idx) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Wrap(children: [
            const SizedBox(height: 8, width: double.infinity),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 8, width: double.infinity),
            ListTile(
              leading: Icon(Icons.photo_library, color: _primaryColor),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: _primaryColor),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    setState(() => _formItems[idx].localPhoto = File(picked.path));
  }

  Future<bool> _save({bool autoSave = false}) async {
    final items = <Map<String, dynamic>>[];
    for (final fi in _formItems) {
      if (fi.itemId == null) continue;
      String? photoPath = fi.photoPath;
      if (fi.localPhoto != null) {
        final uploaded = await _service.uploadPhoto(fi.localPhoto!);
        if (uploaded != null) {
          photoPath = uploaded;
          fi.photoPath = uploaded;
          fi.localPhoto = null;
        }
      }
      items.add({
        'item_id': fi.itemId,
        'type': fi.type,
        'qty': double.tryParse(fi.qtyController.text) ?? 0,
        'unit_id': fi.unitId,
        'note': fi.noteController.text,
        'photo': photoPath,
      });
    }

    final ownerId = _ownerOutletId ?? _outletId;
    if (ownerId == null) return false;

    final payload = {
      'header_id': _headerId,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'owner_outlet_id': ownerId,
      'outlet_id': _outletId,
      if (_warehouseOutletId != null) 'warehouse_outlet_id': _warehouseOutletId,
      'notes': _notesController.text,
      'items': items,
      if (autoSave) 'autosave': true,
    };

    final res = await _service.save(payload);
    if (res != null && res['success'] == true) {
      _headerId = int.tryParse(res['header_id']?.toString() ?? '') ?? _headerId;
      return true;
    }
    if (mounted && !autoSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message'] ?? 'Gagal menyimpan')),
      );
    }
    return false;
  }

  List<DropdownMenuItem<int>> get _warehouseDropdownItems {
    final loc = _outletId;
    final seen = <int>{};
    final items = <DropdownMenuItem<int>>[];
    for (final w in _warehouseOutlets) {
      if (loc != null && int.tryParse(w['outlet_id'].toString()) != loc) continue;
      final id = int.tryParse(w['id'].toString());
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      items.add(DropdownMenuItem<int>(
        value: id,
        child: Text(w['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
      ));
    }
    return items;
  }

  Future<void> _doSave() async {
    if (_outletId == null) {
      _showMessage('Pilih outlet lokasi');
      return;
    }
    setState(() => _saving = true);
    final ok = await _save();
    setState(() => _saving = false);
    if (ok && mounted) {
      _showMessage('Draft berhasil disimpan', success: true);
      Navigator.pop(context, true);
    }
  }

  Future<void> _doSubmit() async {
    if (_outletId == null) {
      _showMessage('Pilih outlet lokasi');
      return;
    }
    final hasItems = _formItems.any((fi) => fi.itemId != null);
    if (!hasItems) {
      _showMessage('Tambahkan minimal 1 item');
      return;
    }
    final breakageNoPhoto = _formItems.where((fi) =>
        fi.itemId != null &&
        fi.type == 'breakage' &&
        fi.photoPath == null &&
        fi.localPhoto == null).toList();
    if (breakageNoPhoto.isNotEmpty) {
      _showMessage('Item bertipe Breakage wajib foto');
      return;
    }
    if (_approvers.isEmpty) {
      _showMessage('Tambahkan minimal 1 approver');
      return;
    }

    setState(() => _submitting = true);
    final saved = await _save();
    if (!saved || _headerId == null) {
      setState(() => _submitting = false);
      return;
    }
    final res = await _service.submit(
      _headerId!,
      _approvers.map((a) => int.parse(a['id'].toString())).toList(),
    );
    setState(() => _submitting = false);
    if (mounted) {
      final success = res?['success'] == true;
      _showMessage(res?['message'] ?? 'Gagal submit', success: success);
      if (success) Navigator.pop(context, true);
    }
  }

  Future<void> _searchApprover() async {
    final q = _approverSearchCtrl.text.trim();
    if (q.isEmpty) return;
    final res = await _service.searchApprovers(q);
    if (res == null || res['users'] == null) return;
    final users = (res['users'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Pilih Approver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              ...users.map((u) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _primaryColor.withOpacity(0.1),
                    child: Text(
                      u['name']?.toString().substring(0, 1) ?? '?',
                      style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(u['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    u['jabatan']?.toString() ?? u['email']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, u),
                ),
              )),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      final alreadyAdded = _approvers.any(
        (a) => a['id'].toString() == selected['id'].toString(),
      );
      if (!alreadyAdded) {
        setState(() => _approvers.add(selected));
        _approverSearchCtrl.clear();
      }
    }
  }

  void _showMessage(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _headerId != null ? 'Edit Asset L&B' : 'Buat Asset L&B',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32, color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildItemsCard(),
                  const SizedBox(height: 16),
                  _buildApproverCard(),
                  const SizedBox(height: 20),
                  _buildButtons(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Umum', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextField(
                controller: _dateController,
                decoration: _inputDecoration(
                  'Tanggal',
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isAdmin)
            InputDecorator(
              decoration: _inputDecoration('Outlet Pemilik *'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _outletDropdownItems.any((d) => d.value == _ownerOutletId) ? _ownerOutletId : null,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Pilih pemilik'),
                  items: _outletDropdownItems,
                  onChanged: (v) => setState(() => _ownerOutletId = v),
                ),
              ),
            )
          else
            TextField(
              readOnly: true,
              controller: TextEditingController(text: _ownerOutletName ?? '-'),
              decoration: _inputDecoration('Outlet Pemilik *'),
            ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: _inputDecoration('Outlet Lokasi *'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _outletDropdownItems.any((d) => d.value == _outletId) ? _outletId : null,
                isExpanded: true,
                isDense: true,
                hint: const Text('Pilih lokasi'),
                items: _outletDropdownItems,
                onChanged: (v) => setState(() {
                  _outletId = v;
                  _warehouseOutletId = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: _inputDecoration('Gudang (opsional)'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _warehouseDropdownItems.any((d) => d.value == _warehouseOutletId)
                    ? _warehouseOutletId
                    : null,
                isExpanded: true,
                isDense: true,
                hint: const Text('— Opsional —'),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('— Opsional —')),
                  ..._warehouseDropdownItems,
                ],
                onChanged: (v) => setState(() => _warehouseOutletId = v),
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

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah'),
                style: TextButton.styleFrom(foregroundColor: _primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_formItems.length, (i) => _buildItemTile(i)),
        ],
      ),
    );
  }

  Widget _buildItemTile(int idx) {
    final fi = _formItems[idx];
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
              CircleAvatar(
                radius: 14,
                backgroundColor: _primaryColor.withOpacity(0.1),
                child: Text(
                  '${idx + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectItem(idx),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(text: fi.itemName ?? ''),
                      decoration: InputDecoration(
                        hintText: 'Pilih item...',
                        suffixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
              if (_formItems.length > 1)
                IconButton(
                  onPressed: () => _removeItem(idx),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: const Color(0xFFEF4444),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tipe',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: fi.type,
                isExpanded: true,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'lost', child: Text('Lost', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'breakage', child: Text('Breakage', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => fi.type = v ?? 'lost'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: fi.qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: fi.units.isNotEmpty
                    ? InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          isDense: true,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _unitValueValid(fi) ? fi.unitId : null,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('-', style: TextStyle(fontSize: 13)),
                            items: _dedupUnitItems(fi),
                            onChanged: (v) => setState(() {
                              fi.unitId = v;
                              fi.unitName = fi.units.firstWhere(
                                (u) => int.tryParse(u['id'].toString()) == v,
                                orElse: () => {},
                              )['name']?.toString();
                            }),
                          ),
                        ),
                      )
                    : TextField(
                        readOnly: true,
                        controller: TextEditingController(text: fi.unitName ?? '-'),
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: fi.noteController,
            decoration: InputDecoration(
              labelText: 'Keterangan (opsional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (fi.localPhoto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(fi.localPhoto!, width: 56, height: 56, fit: BoxFit.cover),
                )
              else if (fi.photoPath != null && fi.photoPath!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    '${AuthService.storageUrl}/storage/${fi.photoPath}',
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.broken_image, size: 24, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image, color: Color(0xFF94A3B8)),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(idx),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: Text(
                    fi.type == 'breakage' ? 'Foto Bukti *' : 'Foto (opsional)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fi.type == 'breakage' ? const Color(0xFFEF4444) : _primaryColor,
                    side: BorderSide(
                      color: fi.type == 'breakage' ? const Color(0xFFEF4444) : _primaryColor,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApproverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approver (min. 1)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _approverSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nama approver...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _searchApprover(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _searchApprover,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Icon(Icons.search, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_approvers.isEmpty)
            Text(
              'Belum ada approver dipilih',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _approvers.asMap().entries.map((e) {
                final a = e.value;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: _primaryColor,
                    child: Text(
                      '${e.key + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  label: Text(
                    a['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _approvers.removeAt(e.key)),
                  backgroundColor: _primaryColor.withOpacity(0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _doSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const AppLoadingIndicator(size: 20, color: Colors.white, useLogo: false)
                : const Text('Submit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _saving ? null : _doSave,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: const BorderSide(color: _primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const AppLoadingIndicator(size: 20, color: _primaryColor, useLogo: false)
                : const Text('Simpan Draft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _FormItem {
  int? itemId;
  String? itemName;
  String type;
  int? unitId;
  String? unitName;
  String? photoPath;
  File? localPhoto;
  List<Map<String, dynamic>> units;
  final TextEditingController qtyController;
  final TextEditingController noteController;

  _FormItem({
    this.itemId,
    this.itemName,
    this.type = 'lost',
    double qty = 0,
    this.unitId,
    this.unitName,
    String note = '',
    this.photoPath,
    this.units = const [],
  })  : qtyController = TextEditingController(text: qty > 0 ? qty.toString() : ''),
        noteController = TextEditingController(text: note);

  void dispose() {
    qtyController.dispose();
    noteController.dispose();
  }
}

class _ItemPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _ItemPickerSheet({required this.items});

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = widget.items.where((i) {
        final name = i['name']?.toString().toLowerCase() ?? '';
        final sku = i['sku']?.toString().toLowerCase() ?? '';
        return name.contains(lower) || sku.contains(lower);
      }).toList();
    });
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
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari item...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final item = _filtered[i];
                final hasImage = item['image'] != null && item['image'].toString().isNotEmpty;
                return ListTile(
                  leading: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${AuthService.storageUrl}/storage/${item['image']}',
                            width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      : Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2, size: 20, color: Color(0xFF94A3B8)),
                        ),
                  title: Text(
                    item['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${item['sku'] ?? ''} • ${item['category_name'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  onTap: () => Navigator.pop(ctx, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
