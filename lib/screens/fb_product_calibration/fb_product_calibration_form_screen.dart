import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/fb_product_calibration_models.dart';
import '../../services/fb_product_calibration_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'fb_product_calibration_ui.dart';

class FbProductCalibrationFormScreen extends StatefulWidget {
  final int? recordId;
  final String? scheduledDate;

  const FbProductCalibrationFormScreen({super.key, this.recordId, this.scheduledDate});

  @override
  State<FbProductCalibrationFormScreen> createState() => _FbProductCalibrationFormScreenState();
}

class _FbProductCalibrationFormScreenState extends State<FbProductCalibrationFormScreen> {
  final _service = FbProductCalibrationService();
  final _conductorSearchController = TextEditingController();
  final _productSearchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _showConductorSuggestions = false;
  bool _showProductSuggestions = false;
  Timer? _conductorTimer;
  Timer? _productTimer;

  List<Map<String, dynamic>> _outlets = [];
  List<UserSuggestion> _conductorSuggestions = [];
  List<CalibrationProductLine> _selectedProducts = [];
  List<Map<String, dynamic>> _productSuggestions = [];

  int? _outletId;
  String? _scheduledDate;
  int? _conductorId;
  String _mode = 'kitchen';

  bool get _isEdit => widget.recordId != null;

  String get _minDate {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.scheduledDate ?? _minDate;
    _loadFormData();
  }

  @override
  void dispose() {
    _conductorTimer?.cancel();
    _productTimer?.cancel();
    _conductorSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _loading = true);
    final res = await _service.getCreateData(recordId: widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat form')));
      return;
    }

    _outlets = (res['outlets'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final record = res['record'] as Map?;
    if (record != null) {
      _outletId = record['outlet_id'] as int?;
      _scheduledDate = record['scheduled_date']?.toString() ?? _scheduledDate;
      _conductorId = record['conductor_id'] as int?;
      _conductorSearchController.text = record['conductor_name']?.toString() ?? '';
      _mode = record['mode']?.toString() ?? 'kitchen';
      _selectedProducts = (record['products'] as List? ?? [])
          .map((e) => CalibrationProductLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    setState(() => _loading = false);
  }

  void _onConductorSearch(String value) {
    _conductorTimer?.cancel();
    _conductorTimer = Timer(const Duration(milliseconds: 300), () async {
      final q = value.trim();
      if (q.length < 2) {
        if (mounted) setState(() { _conductorSuggestions = []; _showConductorSuggestions = false; });
        return;
      }
      final results = await _service.searchConductors(q);
      if (!mounted) return;
      setState(() {
        _conductorSuggestions = results.map(UserSuggestion.fromJson).toList();
        _showConductorSuggestions = _conductorSuggestions.isNotEmpty;
      });
    });
  }

  void _onProductSearch(String value) {
    if (_outletId == null) return;
    _productTimer?.cancel();
    _productTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _service.searchProducts(
        outletId: _outletId!,
        query: value.trim(),
        excludeIds: _selectedProducts.map((p) => p.itemId).toList(),
      );
      if (!mounted) return;
      setState(() {
        _productSuggestions = results;
        _showProductSuggestions = results.isNotEmpty;
      });
    });
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    if (_scheduledDate != null && _scheduledDate!.length >= 10) {
      final p = _scheduledDate!.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _isEdit ? DateTime(2000) : DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scheduledDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _selectProduct(Map<String, dynamic> item) {
    final id = item['id'] as int? ?? item['item_id'] as int? ?? 0;
    if (_selectedProducts.any((p) => p.itemId == id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product sudah ditambahkan')));
      return;
    }
    setState(() {
      _selectedProducts.add(CalibrationProductLine(
        itemId: id,
        itemName: item['item_name']?.toString() ?? '',
        categoryName: item['category_name']?.toString(),
        subCategoryName: item['sub_category_name']?.toString(),
      ));
      _productSearchController.clear();
      _showProductSuggestions = false;
      _productSuggestions = [];
    });
  }

  Future<void> _save() async {
    if (_outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet')));
      return;
    }
    if (_conductorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conducted By wajib dipilih')));
      return;
    }
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal satu product')));
      return;
    }

    setState(() => _saving = true);
    final payload = {
      'outlet_id': _outletId,
      'scheduled_date': _scheduledDate,
      'conductor_id': _conductorId,
      'mode': _mode,
      'products': _selectedProducts.map((p) => p.toPayload()).toList(),
    };

    final res = await _service.saveSchedule(payload: payload, recordId: widget.recordId);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Jadwal' : 'Tambah Jadwal',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: FbCalibrationUi.cardDecoration,
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Mode Calibration *', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'kitchen', label: Text('Kitchen')),
                                  ButtonSegment(value: 'bar', label: Text('Bar')),
                                ],
                                selected: {_mode},
                                onSelectionChanged: (s) => setState(() => _mode = s.first),
                              ),
                              const SizedBox(height: 4),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Kitchen: Cooking Method & Temperature. Bar: Beverage Method, Thickness & Freshness.',
                                  style: TextStyle(fontSize: 11, color: FbCalibrationUi.textMuted),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                value: _outletId,
                                decoration: const InputDecoration(labelText: 'Outlet *', border: OutlineInputBorder()),
                                items: _outlets
                                    .map((o) => DropdownMenuItem<int>(
                                          value: o['id_outlet'] as int?,
                                          child: Text(o['nama_outlet']?.toString() ?? ''),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _outletId = v;
                                  _selectedProducts = [];
                                }),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Tanggal Calibration *',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(FbCalibrationUi.formatDate(_scheduledDate)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: FbCalibrationUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Conducted By *', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _conductorSearchController,
                                decoration: const InputDecoration(
                                  hintText: 'Cari user conductor...',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  _conductorId = null;
                                  _onConductorSearch(v);
                                },
                              ),
                              if (_showConductorSuggestions)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  constraints: const BoxConstraints(maxHeight: 160),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: FbCalibrationUi.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _conductorSuggestions.length,
                                    itemBuilder: (_, i) {
                                      final u = _conductorSuggestions[i];
                                      return ListTile(
                                        dense: true,
                                        title: Text(u.namaLengkap),
                                        subtitle: Text(u.jabatanName),
                                        onTap: () => setState(() {
                                          _conductorId = u.id;
                                          _conductorSearchController.text = u.namaLengkap;
                                          _showConductorSuggestions = false;
                                        }),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: FbCalibrationUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Product *', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _productSearchController,
                                enabled: _outletId != null,
                                decoration: InputDecoration(
                                  hintText: _outletId == null ? 'Pilih outlet dulu' : 'Cari product...',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: _onProductSearch,
                                onTap: () {
                                  if (_outletId != null) _onProductSearch(_productSearchController.text);
                                },
                              ),
                              if (_showProductSuggestions)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  constraints: const BoxConstraints(maxHeight: 160),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: FbCalibrationUi.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _productSuggestions.length,
                                    itemBuilder: (_, i) {
                                      final item = _productSuggestions[i];
                                      return ListTile(
                                        dense: true,
                                        title: Text(item['item_name']?.toString() ?? ''),
                                        subtitle: Text(item['display_label']?.toString() ?? ''),
                                        onTap: () => _selectProduct(item),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 12),
                              ..._selectedProducts.map((p) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: FbCalibrationUi.border),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Text(
                                                [p.categoryName, p.subCategoryName].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                                                style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          onPressed: () => setState(() => _selectedProducts.remove(p)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: FbCalibrationUi.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isEdit ? 'Update' : 'Simpan'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
