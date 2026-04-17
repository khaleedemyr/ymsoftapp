import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../services/promo_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';

class PromoFormScreen extends StatefulWidget {
  final int? promoId;
  const PromoFormScreen({super.key, this.promoId});

  @override
  State<PromoFormScreen> createState() => _PromoFormScreenState();
}

class _PromoFormScreenState extends State<PromoFormScreen> {
  final PromoService _service = PromoService();
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _minTrxController = TextEditingController();
  final _maxTrxController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termsController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _type = 'percent';
  String _status = 'active';
  String _isMultiple = 'No';
  String _needMember = 'No';
  bool _allTiers = false;
  String _byType = 'kategori';
  String _outletType = 'region';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _days = [];
  final List<String> _tiers = [];
  XFile? _bannerFile;
  String? _existingBannerPath;
  bool _removeExistingBanner = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _regions = [];

  List<int> _selectedCategoryIds = [];
  List<int> _selectedItemIds = [];
  List<int> _selectedOutletIds = [];
  List<int> _selectedRegionIds = [];
  List<int> _selectedBuyItemIds = [];
  List<int> _selectedGetItemIds = [];

  static const List<String> _tierOptions = ['Silver', 'Loyal', 'Elite'];
  static const List<String> _dayOptions = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  bool get _isEdit => widget.promoId != null;
  bool get _showValue => ['percent', 'nominal', 'bundle'].contains(_type);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _maxDiscountController.dispose();
    _minTrxController.dispose();
    _maxTrxController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _labelById(List<Map<String, dynamic>> source, int id) {
    for (final row in source) {
      if (_toInt(row['id']) == id) return (row['name'] ?? '-').toString();
    }
    return 'ID $id';
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final createData = await _service.getCreateData();
    if (!mounted) return;
    if (createData['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(createData['message']?.toString() ?? 'Gagal load create data'), backgroundColor: Colors.red),
      );
      return;
    }
    _categories = ((createData['categories'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _items = ((createData['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _outlets = ((createData['outlets'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _regions = ((createData['regions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (_isEdit) {
      final detail = await _service.getDetail(widget.promoId!);
      if (!mounted) return;
      if (detail['success'] == true && detail['promo'] is Map) {
        _applyPromo(Map<String, dynamic>.from(detail['promo'] as Map));
      }
    }
    setState(() => _loading = false);
  }

  void _applyPromo(Map<String, dynamic> p) {
    _nameController.text = p['name']?.toString() ?? '';
    _type = p['type']?.toString() ?? 'percent';
    _status = p['status']?.toString() ?? 'active';
    _isMultiple = p['is_multiple']?.toString() == 'Yes' ? 'Yes' : 'No';
    _needMember = p['need_member']?.toString() == 'Yes' ? 'Yes' : 'No';
    _allTiers = p['all_tiers'] == true || p['all_tiers']?.toString() == '1';
    _valueController.text = p['value']?.toString() ?? '';
    _maxDiscountController.text = p['max_discount']?.toString() ?? '';
    _minTrxController.text = p['min_transaction']?.toString() ?? '';
    _maxTrxController.text = p['max_transaction']?.toString() ?? '';
    _startTimeController.text = p['start_time']?.toString() ?? '';
    _endTimeController.text = p['end_time']?.toString() ?? '';
    _descriptionController.text = p['description']?.toString() ?? '';
    _termsController.text = p['terms']?.toString() ?? '';
    _existingBannerPath = p['banner']?.toString();
    final sd = p['start_date']?.toString();
    final ed = p['end_date']?.toString();
    _startDate = (sd == null || sd.isEmpty) ? null : DateTime.tryParse(sd);
    _endDate = (ed == null || ed.isEmpty) ? null : DateTime.tryParse(ed);

    _days
      ..clear()
      ..addAll(((p['days'] as List?) ?? const []).map((e) => e.toString()));
    _tiers
      ..clear()
      ..addAll(((p['tiers'] as List?) ?? const []).map((e) => e.toString()));

    _selectedCategoryIds = ((p['categories'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();
    _selectedItemIds = ((p['items'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();
    _selectedOutletIds = ((p['outlets'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();
    _selectedRegionIds = ((p['regions'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();
    _selectedBuyItemIds = ((p['buy_items'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();
    _selectedGetItemIds = ((p['get_items'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();

    _byType = _selectedCategoryIds.isNotEmpty ? 'kategori' : 'item';
    _outletType = _selectedRegionIds.isNotEmpty ? 'region' : 'outlet';
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() => controller.text = '$hh:$mm');
  }

  Future<void> _pickBanner() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    final fileName = picked.name.toLowerCase();
    final ext = fileName.contains('.') ? fileName.split('.').last : '';
    const allowedExt = {'jpg', 'jpeg', 'png', 'gif'};
    if (!allowedExt.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format banner harus JPG, JPEG, PNG, atau GIF'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final size = await picked.length();
    if (size > 2 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran banner maksimal 2MB'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _bannerFile = picked;
      _removeExistingBanner = false;
    });
  }

  String? _existingBannerUrl() {
    final p = (_existingBannerPath ?? '').trim();
    if (p.isEmpty) return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final normalized = p.startsWith('/') ? p.substring(1) : p;
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  Future<void> _pickMulti({
    required String title,
    required List<Map<String, dynamic>> source,
    required List<int> initial,
    required ValueChanged<List<int>> onChanged,
  }) async {
    final picked = await showMasterMultiSelectPicker(
      context: context,
      title: title,
      source: source,
      initialIds: initial,
      searchHint: 'Cari...',
    );
    if (picked == null) return;
    setState(() => onChanged(picked));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal mulai dan akhir wajib diisi'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_byType == 'kategori' && _selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 kategori'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_byType == 'item' && _selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 item'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_outletType == 'region' && _selectedRegionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 region'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_outletType == 'outlet' && _selectedOutletIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 outlet'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_type == 'bogo' &&
        (_selectedBuyItemIds.isEmpty ||
            _selectedGetItemIds.isEmpty ||
            _selectedBuyItemIds.length != _selectedGetItemIds.length)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BOGO butuh pasangan buy/get item dengan jumlah sama'), backgroundColor: Colors.red),
      );
      return;
    }

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'type': _type,
      'value': _showValue ? (double.tryParse(_valueController.text.trim()) ?? 0) : null,
      'max_discount': _type == 'percent' ? double.tryParse(_maxDiscountController.text.trim()) : null,
      'is_multiple': _isMultiple,
      'min_transaction': double.tryParse(_minTrxController.text.trim()),
      'max_transaction': double.tryParse(_maxTrxController.text.trim()),
      'start_date': '${_startDate!.year.toString().padLeft(4, '0')}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
      'end_date': '${_endDate!.year.toString().padLeft(4, '0')}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
      'start_time': _startTimeController.text.trim().isEmpty ? null : _startTimeController.text.trim(),
      'end_time': _endTimeController.text.trim().isEmpty ? null : _endTimeController.text.trim(),
      'days': _days,
      'description': _descriptionController.text.trim(),
      'terms': _termsController.text.trim(),
      'need_member': _needMember,
      'all_tiers': _allTiers,
      'tiers': _allTiers ? <String>[] : _tiers,
      'remove_banner': _removeExistingBanner,
      'status': _status,
      'by_type': _byType,
      'outlet_type': _outletType,
      'categories': _byType == 'kategori' ? _selectedCategoryIds : <int>[],
      'items': _byType == 'item' ? _selectedItemIds : <int>[],
      'regions': _outletType == 'region' ? _selectedRegionIds : <int>[],
      'outlets': _outletType == 'outlet' ? _selectedOutletIds : <int>[],
      'buy_items': _type == 'bogo' ? _selectedBuyItemIds : <int>[],
      'get_items': _type == 'bogo' ? _selectedGetItemIds : <int>[],
    };

    setState(() => _saving = true);
    final result = _isEdit
        ? await _service.updateMultipart(
            widget.promoId!,
            payload,
            banner: _bannerFile,
          )
        : await _service.createMultipart(
            payload,
            banner: _bannerFile,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (ok ? 'Berhasil disimpan' : 'Gagal menyimpan')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Promo' : 'Tambah Promo',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nama Promo *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Tipe Promo', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('Diskon Persen')),
                      DropdownMenuItem(value: 'nominal', child: Text('Diskon Nominal')),
                      DropdownMenuItem(value: 'bundle', child: Text('Bundling')),
                      DropdownMenuItem(value: 'bogo', child: Text('Buy 1 Get 1')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'percent'),
                  ),
                  if (_showValue) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
                    ),
                  ],
                  if (_type == 'percent') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _maxDiscountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Maximum Diskon', border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minTrxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Minimum Transaksi', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _maxTrxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Maximum Transaksi', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(start: true),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_startDate == null ? 'Tanggal Mulai' : _startDate!.toIso8601String().substring(0, 10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(start: false),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_endDate == null ? 'Tanggal Akhir' : _endDate!.toIso8601String().substring(0, 10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startTimeController,
                          readOnly: true,
                          onTap: () => _pickTime(_startTimeController),
                          decoration: const InputDecoration(labelText: 'Jam Mulai', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _endTimeController,
                          readOnly: true,
                          onTap: () => _pickTime(_endTimeController),
                          decoration: const InputDecoration(labelText: 'Jam Akhir', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dayOptions.map((d) {
                      final selected = _days.contains(d);
                      return FilterChip(
                        label: Text(d),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _days.add(d);
                          } else {
                            _days.remove(d);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _isMultiple,
                    decoration: const InputDecoration(labelText: 'Berlaku Kelipatan?', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'No', child: Text('Tidak')),
                      DropdownMenuItem(value: 'Yes', child: Text('Ya')),
                    ],
                    onChanged: (v) => setState(() => _isMultiple = v ?? 'No'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _needMember,
                    decoration: const InputDecoration(labelText: 'Perlu Member?', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'No', child: Text('Tidak')),
                      DropdownMenuItem(value: 'Yes', child: Text('Ya')),
                    ],
                    onChanged: (v) => setState(() => _needMember = v ?? 'No'),
                  ),
                  if (_needMember == 'Yes') ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _allTiers,
                      onChanged: (v) => setState(() {
                        _allTiers = v == true;
                        if (_allTiers) _tiers.clear();
                      }),
                      title: const Text('Semua Tier'),
                    ),
                    if (!_allTiers)
                      Wrap(
                        spacing: 8,
                        children: _tierOptions.map((tier) {
                          final selected = _tiers.contains(tier);
                          return FilterChip(
                            label: Text(tier),
                            selected: selected,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _tiers.add(tier);
                              } else {
                                _tiers.remove(tier);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _outletType,
                          decoration: const InputDecoration(labelText: 'Outlet Promo', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'region', child: Text('By Region')),
                            DropdownMenuItem(value: 'outlet', child: Text('By Outlet')),
                          ],
                          onChanged: (v) => setState(() => _outletType = v ?? 'region'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMulti(
                            title: _outletType == 'region' ? 'Pilih Region' : 'Pilih Outlet',
                            source: _outletType == 'region' ? _regions : _outlets,
                            initial: _outletType == 'region' ? _selectedRegionIds : _selectedOutletIds,
                            onChanged: (ids) {
                              if (_outletType == 'region') {
                                _selectedRegionIds = ids;
                              } else {
                                _selectedOutletIds = ids;
                              }
                            },
                          ),
                          icon: const Icon(Icons.list_alt),
                          label: Text(_outletType == 'region'
                              ? 'Region (${_selectedRegionIds.length})'
                              : 'Outlet (${_selectedOutletIds.length})'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _byType,
                          decoration: const InputDecoration(labelText: 'Target Promo', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'kategori', child: Text('By Kategori')),
                            DropdownMenuItem(value: 'item', child: Text('By Item')),
                          ],
                          onChanged: (v) => setState(() => _byType = v ?? 'kategori'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMulti(
                            title: _byType == 'kategori' ? 'Pilih Kategori' : 'Pilih Item',
                            source: _byType == 'kategori' ? _categories : _items,
                            initial: _byType == 'kategori' ? _selectedCategoryIds : _selectedItemIds,
                            onChanged: (ids) {
                              if (_byType == 'kategori') {
                                _selectedCategoryIds = ids;
                              } else {
                                _selectedItemIds = ids;
                              }
                            },
                          ),
                          icon: const Icon(Icons.list_alt),
                          label: Text(_byType == 'kategori'
                              ? 'Kategori (${_selectedCategoryIds.length})'
                              : 'Item (${_selectedItemIds.length})'),
                        ),
                      ),
                    ],
                  ),
                  if (_type == 'bogo') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _pickMulti(
                        title: 'Pilih Item Buy',
                        source: _items,
                        initial: _selectedBuyItemIds,
                        onChanged: (ids) => _selectedBuyItemIds = ids,
                      ),
                      icon: const Icon(Icons.shopping_cart),
                      label: Text('Buy Items (${_selectedBuyItemIds.length})'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickMulti(
                        title: 'Pilih Item Get',
                        source: _items,
                        initial: _selectedGetItemIds,
                        onChanged: (ids) => _selectedGetItemIds = ids,
                      ),
                      icon: const Icon(Icons.card_giftcard),
                      label: Text('Get Items (${_selectedGetItemIds.length})'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(value: 'inactive', child: Text('Nonaktif')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'active'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _termsController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Term & Condition', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickBanner,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Pilih Banner Promo'),
                  ),
                  if (_bannerFile != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<List<int>>(
                        future: _bannerFile!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              height: 140,
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return Image.memory(
                            Uint8List.fromList(snapshot.data!),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Banner baru: ${_bannerFile!.name}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _bannerFile = null),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Hapus pilihan'),
                        ),
                      ],
                    ),
                  ] else if (_existingBannerPath != null && _existingBannerPath!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    if (!_removeExistingBanner) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _existingBannerUrl() ?? '',
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 140,
                              alignment: Alignment.center,
                              color: Colors.grey.shade200,
                              child: const Text('Gagal memuat banner'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Banner saat ini: $_existingBannerPath',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _removeExistingBanner = true),
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Hapus banner existing'),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'Banner existing akan dihapus saat disimpan.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _removeExistingBanner = false),
                          icon: const Icon(Icons.undo),
                          label: const Text('Batalkan'),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan Promo'),
                  ),
                  if (_byType == 'kategori' && _selectedCategoryIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Kategori terpilih: ${_selectedCategoryIds.map((e) => _labelById(_categories, e)).join(', ')}'),
                  ],
                  if (_byType == 'item' && _selectedItemIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Item terpilih: ${_selectedItemIds.map((e) => _labelById(_items, e)).join(', ')}'),
                  ],
                ],
              ),
            ),
    );
  }
}
