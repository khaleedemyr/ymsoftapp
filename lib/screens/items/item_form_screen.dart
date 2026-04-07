import 'package:flutter/material.dart';
import '../../services/item_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class ItemFormScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> with SingleTickerProviderStateMixin {
  final ItemService _service = ItemService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specificationController = TextEditingController();
  final _minStockController = TextEditingController();
  final _warehouseDivisionController = TextEditingController();
  final _mediumConversionController = TextEditingController();
  final _smallConversionController = TextEditingController();
  final _expController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  // Create data from API
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _warehouseDivisions = [];
  List<Map<String, dynamic>> _menuTypes = [];
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _bomItems = [];
  List<Map<String, dynamic>> _modifiers = [];

  // Form state - Tab 1 Info
  int? _categoryId;
  int? _subCategoryId;
  String _type = 'product';
  String _status = 'active';

  // Tab 2 Unit
  int? _smallUnitId;
  int? _mediumUnitId;
  int? _largeUnitId;

  // Tab 3 Harga & Ketersediaan
  final List<Map<String, dynamic>> _prices = [];
  final List<Map<String, dynamic>> _availabilities = [];

  // Tab 4 Lainnya
  String _compositionType = 'single';
  bool _modifierEnabled = false;
  final List<int> _modifierOptionIds = [];
  final List<Map<String, dynamic>> _bom = [];

  bool get _isEdit => widget.item != null;
  int? get _itemId {
    if (widget.item == null) return null;
    final id = widget.item!['id'];
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _specificationController.dispose();
    _minStockController.dispose();
    _warehouseDivisionController.dispose();
    _mediumConversionController.dispose();
    _smallConversionController.dispose();
    _expController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final createData = await _service.getCreateData();
      if (!mounted) return;
      if (createData != null) {
        _categories = _toList(createData['categories']);
        _subCategories = _toList(createData['sub_categories']);
        _units = _toList(createData['units']);
        _warehouseDivisions = _toList(createData['warehouse_divisions']);
        _menuTypes = _toList(createData['menu_types']);
        _regions = _toList(createData['regions']);
        _outlets = _toList(createData['outlets']);
        _bomItems = _toList(createData['bom_items']);
        _modifiers = _toList(createData['modifiers']);
      }
      if (_isEdit && _itemId != null) {
        final detail = await _service.getDetail(_itemId!);
        if (mounted && detail != null && detail['item'] != null) {
          _applyItemToForm(detail['item'] as Map<String, dynamic>);
        }
      } else {
        _setDefaults();
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  void _setDefaults() {
    _minStockController.text = '0';
    _mediumConversionController.text = '0';
    _smallConversionController.text = '1';
    _expController.text = '0';
    if (_prices.isEmpty) _prices.add({'region_id': null, 'outlet_id': null, 'price': 0.0});
    if (_availabilities.isEmpty) _availabilities.add({'region_id': null, 'outlet_id': null});
  }

  void _applyItemToForm(Map<String, dynamic> item) {
    _skuController.text = item['sku']?.toString() ?? '';
    _nameController.text = item['name']?.toString() ?? '';
    _descriptionController.text = item['description']?.toString() ?? '';
    _specificationController.text = item['specification']?.toString() ?? '';
    _minStockController.text = item['min_stock']?.toString() ?? '0';
    _warehouseDivisionController.text = item['warehouse_division_id']?.toString() ?? '';
    _mediumConversionController.text = item['medium_conversion_qty']?.toString() ?? '0';
    _smallConversionController.text = item['small_conversion_qty']?.toString() ?? '1';
    _expController.text = item['exp']?.toString() ?? '0';

    _categoryId = _parseId(item['category_id']);
    _subCategoryId = _parseId(item['sub_category_id']);
    _type = item['type']?.toString() ?? 'product';
    _status = item['status']?.toString() ?? 'active';
    _smallUnitId = _parseId(item['small_unit_id']);
    _mediumUnitId = _parseId(item['medium_unit_id']);
    _largeUnitId = _parseId(item['large_unit_id']);
    _compositionType = item['composition_type']?.toString() ?? 'single';
    _modifierEnabled = item['modifier_enabled'] == true || item['modifier_enabled'] == 1;

    final modifierIds = item['modifier_option_ids'];
    if (modifierIds is List) {
      _modifierOptionIds.clear();
      for (final e in modifierIds) {
        final id = e is int ? e : int.tryParse(e.toString());
        if (id != null) _modifierOptionIds.add(id);
      }
    }

    final prices = item['prices'];
    if (prices is List && prices.isNotEmpty) {
      _prices.clear();
      for (final p in prices) {
        if (p is Map) {
          _prices.add({
            'region_id': _parseId(p['region_id']),
            'outlet_id': _parseId(p['outlet_id']),
            'price': (p['price'] is num) ? (p['price'] as num).toDouble() : 0.0,
          });
        }
      }
    }
    if (_prices.isEmpty) _prices.add({'region_id': null, 'outlet_id': null, 'price': 0.0});

    final availabilities = item['availabilities'];
    if (availabilities is List && availabilities.isNotEmpty) {
      _availabilities.clear();
      for (final a in availabilities) {
        if (a is Map) {
          _availabilities.add({
            'region_id': _parseId(a['region_id']),
            'outlet_id': _parseId(a['outlet_id']),
          });
        }
      }
    }
    if (_availabilities.isEmpty) _availabilities.add({'region_id': null, 'outlet_id': null});

    final bom = item['bom'];
    if (bom is List) {
      _bom.clear();
      for (final b in bom) {
        if (b is Map && b['item_id'] != null) {
          _bom.add({
            'item_id': _parseId(b['item_id']) ?? _parseId(b['material_item_id']),
            'qty': (b['qty'] is num) ? (b['qty'] as num).toDouble() : 0.0,
            'unit_id': _parseId(b['unit_id']),
          });
          if (_bom.last['item_id'] == null) _bom.removeLast();
        }
      }
    }
  }

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> _buildBody() {
    final prices = _prices
        .where((p) => (p['price'] as num?) != null && (p['price'] as num) >= 0)
        .map((p) => {
              'region_id': p['region_id'],
              'outlet_id': p['outlet_id'],
              'price': (p['price'] as num).toDouble(),
            })
        .toList();
    if (prices.isEmpty) prices.add({'region_id': null, 'outlet_id': null, 'price': 0.0});

    final availabilities = _availabilities.map((a) => {
          'region_id': a['region_id'],
          'outlet_id': a['outlet_id'],
        }).toList();
    if (availabilities.isEmpty) availabilities.add({'region_id': null, 'outlet_id': null});

    final bom = _compositionType == 'composed'
        ? _bom
            .where((b) => b['item_id'] != null && b['unit_id'] != null && (b['qty'] as num? ?? 0) > 0)
            .map((b) => {
                  'item_id': b['item_id'],
                  'qty': (b['qty'] as num).toDouble(),
                  'unit_id': b['unit_id'],
                })
            .toList()
        : <Map<String, dynamic>>[];

    return {
      'category_id': _categoryId,
      'sub_category_id': _subCategoryId,
      'warehouse_division_id': _warehouseDivisionController.text.trim().isEmpty ? null : _warehouseDivisionController.text.trim(),
      'sku': _skuController.text.trim(),
      'type': _type,
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'specification': _specificationController.text.trim().isEmpty ? null : _specificationController.text.trim(),
      'small_unit_id': _smallUnitId,
      'medium_unit_id': _mediumUnitId ?? _smallUnitId,
      'large_unit_id': _largeUnitId ?? _smallUnitId,
      'medium_conversion_qty': double.tryParse(_mediumConversionController.text) ?? 0,
      'small_conversion_qty': double.tryParse(_smallConversionController.text) ?? 1,
      'min_stock': int.tryParse(_minStockController.text) ?? 0,
      'status': _status,
      'composition_type': _compositionType,
      'modifier_enabled': _modifierEnabled,
      'modifier_option_ids': _modifierEnabled ? _modifierOptionIds : [],
      'prices': prices,
      'availabilities': availabilities,
      'bom': bom,
      'exp': int.tryParse(_expController.text) ?? 0,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_smallUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih unit kecil (Small Unit)'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final body = _buildBody();
      Map<String, dynamic>? res;
      if (_isEdit && _itemId != null) {
        res = await _service.update(_itemId!, body);
      } else {
        res = await _service.create(body);
      }
      if (mounted) {
        setState(() => _isSaving = false);
        if (res != null && res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEdit ? 'Item berhasil diupdate' : 'Item berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          _showValidationErrors(res);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showValidationErrors(Map<String, dynamic>? res) {
    final errors = res?['errors'];
    if (errors is Map) {
      final msg = (errors as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orange, duration: const Duration(seconds: 4)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message']?.toString() ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Item' : 'Tambah Item',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 48, color: Color(0xFF2563EB)))
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF2563EB),
                  tabs: const [
                    Tab(text: 'Info', icon: Icon(Icons.info_outline, size: 20)),
                    Tab(text: 'Unit', icon: Icon(Icons.straighten, size: 20)),
                    Tab(text: 'Harga', icon: Icon(Icons.attach_money, size: 20)),
                    Tab(text: 'Lainnya', icon: Icon(Icons.more_horiz, size: 20)),
                  ],
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabInfo(),
                        _buildTabUnit(),
                        _buildTabPrices(),
                        _buildTabOther(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Item'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            value: _categoryId,
            decoration: const InputDecoration(labelText: 'Kategori *'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-- Pilih Kategori --')),
              ..._categories.map((c) => DropdownMenuItem<int?>(value: _parseId(c['id']), child: Text(c['name']?.toString() ?? ''))),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
            validator: (v) => v == null ? 'Wajib pilih kategori' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _subCategoryId,
            decoration: const InputDecoration(labelText: 'Sub Kategori'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-- Pilih Sub Kategori --')),
              ..._subCategories.map((s) => DropdownMenuItem<int?>(value: _parseId(s['id']), child: Text(s['name']?.toString() ?? ''))),
            ],
            onChanged: (v) => setState(() => _subCategoryId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _warehouseDivisionController,
            decoration: const InputDecoration(labelText: 'Warehouse Division ID'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _skuController,
            decoration: const InputDecoration(labelText: 'SKU *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Tipe'),
            items: [
              const DropdownMenuItem(value: 'product', child: Text('Product')),
              const DropdownMenuItem(value: 'service', child: Text('Service')),
              ..._menuTypes
                  .where((m) => m['type'] != null && m['type'].toString().isNotEmpty)
                  .map((m) => DropdownMenuItem(value: m['type']?.toString(), child: Text(m['type']?.toString() ?? ''))),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'product'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _specificationController,
            decoration: const InputDecoration(labelText: 'Spesifikasi'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _minStockController,
            decoration: const InputDecoration(labelText: 'Minimum Stock'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'active'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabUnit() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            value: _smallUnitId,
            decoration: const InputDecoration(labelText: 'Small Unit *'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-- Pilih Unit --')),
              ..._units.map((u) => DropdownMenuItem<int?>(value: _parseId(u['id']), child: Text('${u['name']} (${u['code']})'))),
            ],
            onChanged: (v) => setState(() => _smallUnitId = v),
            validator: (v) => v == null ? 'Wajib pilih small unit' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _mediumUnitId,
            decoration: const InputDecoration(labelText: 'Medium Unit'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-- Pilih Unit --')),
              ..._units.map((u) => DropdownMenuItem<int?>(value: _parseId(u['id']), child: Text('${u['name']} (${u['code']})'))),
            ],
            onChanged: (v) => setState(() => _mediumUnitId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _largeUnitId,
            decoration: const InputDecoration(labelText: 'Large Unit'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-- Pilih Unit --')),
              ..._units.map((u) => DropdownMenuItem<int?>(value: _parseId(u['id']), child: Text('${u['name']} (${u['code']})'))),
            ],
            onChanged: (v) => setState(() => _largeUnitId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mediumConversionController,
            decoration: const InputDecoration(labelText: 'Medium Conversion Qty'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _smallConversionController,
            decoration: const InputDecoration(labelText: 'Small Conversion Qty'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPrices() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Harga per Region/Outlet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(_prices.length, (i) {
            final p = _prices[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int?>(
                        value: _parseId(p['region_id']),
                        decoration: const InputDecoration(labelText: 'Region', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._regions.map((r) => DropdownMenuItem<int?>(value: _parseId(r['id']), child: Text(r['name']?.toString() ?? ''))),
                        ],
                        onChanged: (v) => setState(() => _prices[i]['region_id'] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int?>(
                        value: _parseId(p['outlet_id']),
                        decoration: const InputDecoration(labelText: 'Outlet', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._outlets.map((o) => DropdownMenuItem<int?>(value: _parseId(o['id_outlet'] ?? o['id']), child: Text(o['nama_outlet']?.toString() ?? ''))),
                        ],
                        onChanged: (v) => setState(() => _prices[i]['outlet_id'] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: (p['price'] as num?)?.toString() ?? '0',
                        decoration: const InputDecoration(labelText: 'Harga', isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => _prices[i]['price'] = double.tryParse(v) ?? 0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: _prices.length > 1 ? () => setState(() => _prices.removeAt(i)) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _prices.add({'region_id': null, 'outlet_id': null, 'price': 0.0})),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Harga'),
          ),
          const SizedBox(height: 16),
          Text('Ketersediaan per Region/Outlet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(_availabilities.length, (i) {
            final a = _availabilities[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _parseId(a['region_id']),
                        decoration: const InputDecoration(labelText: 'Region', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._regions.map((r) => DropdownMenuItem<int?>(value: _parseId(r['id']), child: Text(r['name']?.toString() ?? ''))),
                        ],
                        onChanged: (v) => setState(() => _availabilities[i]['region_id'] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _parseId(a['outlet_id']),
                        decoration: const InputDecoration(labelText: 'Outlet', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._outlets.map((o) => DropdownMenuItem<int?>(value: _parseId(o['id_outlet'] ?? o['id']), child: Text(o['nama_outlet']?.toString() ?? ''))),
                        ],
                        onChanged: (v) => setState(() => _availabilities[i]['outlet_id'] = v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: _availabilities.length > 1 ? () => setState(() => _availabilities.removeAt(i)) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _availabilities.add({'region_id': null, 'outlet_id': null})),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Ketersediaan'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOther() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _compositionType,
            decoration: const InputDecoration(labelText: 'Tipe Komposisi'),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'composed', child: Text('Composed (BOM)')),
            ],
            onChanged: (v) => setState(() => _compositionType = v ?? 'single'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Modifier enabled'),
            value: _modifierEnabled,
            onChanged: (v) => setState(() => _modifierEnabled = v),
          ),
          if (_modifierEnabled) ...[
            ..._modifiers.map((mod) {
              final options = _toList(mod['options']);
              return ExpansionTile(
                title: Text(mod['name']?.toString() ?? 'Modifier'),
                children: options
                    .map((opt) => CheckboxListTile(
                          title: Text(opt['name']?.toString() ?? ''),
                          value: _modifierOptionIds.contains(_parseId(opt['id'])),
                          onChanged: (v) {
                            setState(() {
                              final id = _parseId(opt['id']);
                              if (id == null) return;
                              if (v == true) {
                                if (!_modifierOptionIds.contains(id)) _modifierOptionIds.add(id);
                              } else {
                                _modifierOptionIds.remove(id);
                              }
                            });
                          },
                        ))
                    .toList(),
              );
            }),
          ],
          if (_compositionType == 'composed') ...[
            const SizedBox(height: 16),
            Text('BOM (Bill of Materials)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...List.generate(_bom.length, (i) {
              final b = _bom[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int?>(
                          value: _parseId(b['item_id']),
                          decoration: const InputDecoration(labelText: 'Item', isDense: true),
                          items: _bomItems
                              .where((it) => it['id'] != widget.item?['id'])
                              .map((it) => DropdownMenuItem<int?>(value: _parseId(it['id']), child: Text(it['name']?.toString() ?? '')))
                              .toList(),
                          onChanged: (v) => setState(() => _bom[i]['item_id'] = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: (b['qty'] as num?)?.toString() ?? '0',
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => _bom[i]['qty'] = double.tryParse(v) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _parseId(b['unit_id']),
                          decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('--')),
                            ..._units.map((u) => DropdownMenuItem<int?>(value: _parseId(u['id']), child: Text(u['name']?.toString() ?? ''))),
                          ],
                          onChanged: (v) => setState(() => _bom[i]['unit_id'] = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() => _bom.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _bom.add({'item_id': null, 'qty': 0.0, 'unit_id': null})),
              icon: const Icon(Icons.add),
              label: const Text('Tambah BOM'),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _expController,
            decoration: const InputDecoration(labelText: 'Exp (hari)'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
