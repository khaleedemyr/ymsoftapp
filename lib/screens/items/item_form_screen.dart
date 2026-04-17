import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/item_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class ItemFormScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxImages = 10;

  final ItemService _service = ItemService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  static const _tabs = <String>[
    'Info',
    'UoM',
    'Modifier',
    'BOM',
    'Price',
    'Availability',
    'SPS',
    'Preview',
  ];

  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specificationController = TextEditingController();
  final _minStockController = TextEditingController();
  final _mediumConversionController = TextEditingController();
  final _smallConversionController = TextEditingController();
  final _expController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _warehouseDivisions = [];
  List<Map<String, dynamic>> _menuTypes = [];
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _bomItems = [];
  List<Map<String, dynamic>> _modifiers = [];

  int? _categoryId;
  int? _subCategoryId;
  int? _warehouseDivisionId;
  String _type = 'product';
  String _status = 'active';
  String _compositionType = 'single';
  bool _modifierEnabled = false;

  int? _smallUnitId;
  int? _mediumUnitId;
  int? _largeUnitId;

  final List<int> _modifierOptionIds = [];
  final List<Map<String, dynamic>> _prices = [];
  final List<Map<String, dynamic>> _availabilities = [];
  final List<Map<String, dynamic>> _bom = [];
  final List<Map<String, dynamic>> _existingImages = [];
  final List<XFile> _newImages = [];
  final List<String> _deletedImagePaths = [];
  final ImagePicker _imagePicker = ImagePicker();

  int get _totalImageCount => _existingImages.length + _newImages.length;

  bool get _isEdit => widget.item != null;

  int? get _itemId {
    final id = widget.item?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Map<String, dynamic>? get _selectedCategory {
    for (final c in _categories) {
      if (_parseId(c['id']) == _categoryId) return c;
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredSubCategories {
    if (_categoryId == null) return const [];
    return _subCategories.where((s) {
      return _parseId(s['category_id']) == _categoryId &&
          (s['status']?.toString().toLowerCase() != 'inactive');
    }).toList();
  }

  bool get _hasSubCategories => _filteredSubCategories.isNotEmpty;

  bool get _requiresWarehouseDivision {
    final showPos = _selectedCategory?['show_pos']?.toString();
    return showPos == '0';
  }

  bool get _canUseModifier {
    final showPos = _selectedCategory?['show_pos']?.toString();
    return showPos == '1';
  }

  bool get _showBomTabContent => _compositionType == 'composed';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
      if (createData != null && createData['success'] == true) {
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
        if (mounted && detail != null && detail['item'] is Map) {
          _applyItemToForm(Map<String, dynamic>.from(detail['item'] as Map));
        }
      } else {
        _setDefaults();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic v) {
    if (v is! List) return [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _labelById(
    List<Map<String, dynamic>> list,
    int? id, {
    String idKey = 'id',
    String labelKey = 'name',
  }) {
    if (id == null) return '-';
    for (final row in list) {
      final rowId = _parseId(row[idKey]);
      if (rowId == id) return row[labelKey]?.toString() ?? '-';
    }
    return '-';
  }

  String _outletLabel(int? id) {
    if (id == null) return 'All';
    for (final o in _outlets) {
      final rowId = _parseId(o['id_outlet'] ?? o['id']);
      if (rowId == id) return o['nama_outlet']?.toString() ?? '-';
    }
    return '-';
  }

  String _regionLabel(int? id) {
    return id == null ? 'All' : _labelById(_regions, id);
  }

  String _tabLabel(String base, {bool required = false}) {
    return required ? '$base *' : base;
  }

  String _storageImageUrl(String? path) {
    final p = (path ?? '').trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final normalized = p.startsWith('/') ? p.substring(1) : p;
    return '${ItemService.baseUrl}/storage/$normalized';
  }

  Future<void> _pickImageFromCamera() async {
    if (_totalImageCount >= _maxImages) {
      _showWarn('Maksimal $_maxImages gambar per item.');
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _newImages.add(picked));
  }

  Future<void> _pickImageFromGallery() async {
    if (_totalImageCount >= _maxImages) {
      _showWarn('Maksimal $_maxImages gambar per item.');
      return;
    }
    final remaining = _maxImages - _totalImageCount;
    final picked = await _imagePicker.pickMultiImage(
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked.isEmpty || !mounted) return;
    final accepted = picked.take(remaining).toList();
    setState(() => _newImages.addAll(accepted));
    if (picked.length > accepted.length) {
      _showWarn(
        'Sebagian gambar tidak ditambahkan karena limit $_maxImages gambar.',
      );
    }
  }

  void _removeExistingImageAt(int index) {
    if (index < 0 || index >= _existingImages.length) return;
    final path = _existingImages[index]['path']?.toString();
    if (path != null && path.isNotEmpty && !_deletedImagePaths.contains(path)) {
      _deletedImagePaths.add(path);
    }
    setState(() => _existingImages.removeAt(index));
  }

  void _removeNewImageAt(int index) {
    if (index < 0 || index >= _newImages.length) return;
    setState(() => _newImages.removeAt(index));
  }

  void _moveNewImageLeft(int index) {
    if (index <= 0 || index >= _newImages.length) return;
    setState(() {
      final item = _newImages.removeAt(index);
      _newImages.insert(index - 1, item);
    });
  }

  void _moveNewImageRight(int index) {
    if (index < 0 || index >= _newImages.length - 1) return;
    setState(() {
      final item = _newImages.removeAt(index);
      _newImages.insert(index + 1, item);
    });
  }

  void _setDefaults() {
    _minStockController.text = '0';
    _mediumConversionController.text = '0';
    _smallConversionController.text = '0';
    _expController.text = '0';
    if (_menuTypes.isNotEmpty) {
      final firstType = _menuTypes.first['type']?.toString();
      if (firstType != null && firstType.trim().isNotEmpty) {
        _type = firstType.trim();
      }
    }
    _generateSkuFromCategory();
    if (_prices.isEmpty) {
      _prices.add({
        'price_type': 'specific',
        'region_id': null,
        'outlet_id': null,
        'price': 0.0,
      });
    }
  }

  void _generateSkuFromCategory() {
    if (_isEdit) return;
    final cat = _selectedCategory;
    if (cat == null) {
      _skuController.clear();
      return;
    }
    final code = (cat['code']?.toString() ?? '').trim();
    if (code.isEmpty) {
      _skuController.clear();
      return;
    }
    final now = DateTime.now();
    final ymd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = 1000 + Random().nextInt(9000);
    _skuController.text = '$code-$ymd-$rand';
  }

  void _applyItemToForm(Map<String, dynamic> item) {
    _skuController.text = item['sku']?.toString() ?? '';
    _nameController.text = item['name']?.toString() ?? '';
    _descriptionController.text = item['description']?.toString() ?? '';
    _specificationController.text = item['specification']?.toString() ?? '';
    _minStockController.text = item['min_stock']?.toString() ?? '0';
    _mediumConversionController.text =
        item['medium_conversion_qty']?.toString() ?? '0';
    _smallConversionController.text =
        item['small_conversion_qty']?.toString() ?? '0';
    _expController.text = item['exp']?.toString() ?? '0';

    _categoryId = _parseId(item['category_id']);
    _subCategoryId = _parseId(item['sub_category_id']);
    _warehouseDivisionId = _parseId(item['warehouse_division_id']);
    _type = (item['type']?.toString() ?? 'product').trim();
    _status = (item['status']?.toString() ?? 'active').trim();
    _compositionType =
        (item['composition_type']?.toString() ?? 'single').trim();
    _modifierEnabled = item['modifier_enabled'] == true ||
        item['modifier_enabled'] == 1 ||
        item['modifier_enabled']?.toString() == '1';

    _smallUnitId = _parseId(item['small_unit_id']);
    _mediumUnitId = _parseId(item['medium_unit_id']);
    _largeUnitId = _parseId(item['large_unit_id']);

    _modifierOptionIds
      ..clear()
      ..addAll((item['modifier_option_ids'] is List)
          ? (item['modifier_option_ids'] as List)
              .map(_parseId)
              .whereType<int>()
              .toList()
          : <int>[]);

    _prices.clear();
    final prices = item['prices'];
    if (prices is List && prices.isNotEmpty) {
      for (final p in prices) {
        if (p is! Map) continue;
        _prices.add({
          'price_type': ((_parseId(p['region_id']) == null &&
                      _parseId(p['outlet_id']) == null)
                  ? 'all'
                  : 'specific')
              .toString(),
          'region_id': _parseId(p['region_id']),
          'outlet_id': _parseId(p['outlet_id']),
          'price': _toDouble(p['price']),
        });
      }
    }
    if (_prices.isEmpty) {
      _prices.add({
        'price_type': 'specific',
        'region_id': null,
        'outlet_id': null,
        'price': 0.0,
      });
    }

    _availabilities.clear();
    final availabilities = item['availabilities'];
    if (availabilities is List) {
      for (final a in availabilities) {
        if (a is! Map) continue;
        _availabilities.add({
          'region_id': _parseId(a['region_id']),
          'outlet_id': _parseId(a['outlet_id']),
          'status': 'available',
        });
      }
    }

    _bom.clear();
    final bom = item['bom'];
    if (bom is List) {
      for (final b in bom) {
        if (b is! Map) continue;
        final itemId = _parseId(b['item_id'] ?? b['material_item_id']);
        if (itemId == null) continue;
        _bom.add({
          'item_id': itemId,
          'qty': _toDouble(b['qty']),
          'unit_id': _parseId(b['unit_id']),
          'stock_cut': b['stock_cut'] == true ||
              b['stock_cut'] == 1 ||
              b['stock_cut']?.toString() == '1',
        });
      }
    }

    _existingImages
      ..clear()
      ..addAll((item['images'] is List)
          ? (item['images'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((img) => (img['path']?.toString().isNotEmpty ?? false))
              .toList()
          : const []);
    _newImages.clear();
    _deletedImagePaths.clear();
  }

  Map<String, dynamic> _buildBody() {
    final prices = _prices
        .where((p) => _toDouble(p['price'], fallback: -1) >= 0)
        .map((p) {
          final priceType = p['price_type']?.toString() ?? 'specific';
          if (priceType == 'all') {
            return {
              'price_type': 'all',
              'region_id': null,
              'outlet_id': null,
              'price': _toDouble(p['price']),
            };
          }
          return {
            'price_type': 'specific',
            'region_id': _parseId(p['region_id']),
            'outlet_id': _parseId(p['outlet_id']),
            'price': _toDouble(p['price']),
          };
        })
        .toList();

    final availabilities = _availabilities.map((a) {
      final rid = _parseId(a['region_id']);
      final oid = _parseId(a['outlet_id']);
      return {
        'region_id': rid,
        'outlet_id': oid,
        'status': 'available',
      };
    }).toList();

    final bom = _showBomTabContent
        ? _bom
            .where((b) =>
                _parseId(b['item_id']) != null &&
                _parseId(b['unit_id']) != null &&
                _toDouble(b['qty']) > 0)
            .map((b) => {
                  'item_id': _parseId(b['item_id']),
                  'unit_id': _parseId(b['unit_id']),
                  'qty': _toDouble(b['qty']),
                  'stock_cut': b['stock_cut'] == true,
                })
            .toList()
        : <Map<String, dynamic>>[];

    return {
      'category_id': _categoryId,
      'sub_category_id': _subCategoryId,
      'warehouse_division_id': _warehouseDivisionId,
      'sku': _skuController.text.trim(),
      'type': _type.trim().isEmpty ? null : _type.trim(),
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'specification': _specificationController.text.trim().isEmpty
          ? null
          : _specificationController.text.trim(),
      'small_unit_id': _smallUnitId,
      'medium_unit_id': _mediumUnitId ?? _smallUnitId,
      'large_unit_id': _largeUnitId ?? _smallUnitId,
      'medium_conversion_qty':
          double.tryParse(_mediumConversionController.text.trim()) ?? 0,
      'small_conversion_qty':
          double.tryParse(_smallConversionController.text.trim()) ?? 0,
      'min_stock': int.tryParse(_minStockController.text.trim()) ?? 0,
      'status': _status,
      'composition_type': _compositionType,
      'modifier_enabled': _canUseModifier ? _modifierEnabled : false,
      'modifier_option_ids':
          (_canUseModifier && _modifierEnabled) ? _modifierOptionIds : <int>[],
      'prices': prices,
      'availabilities': availabilities,
      'bom': bom,
      'exp': int.tryParse(_expController.text.trim()) ?? 0,
    };
  }

  bool _validateMandatoryBeforeSubmit() {
    if (!_formKey.currentState!.validate()) return false;
    if (_categoryId == null) {
      _showWarn('Kategori wajib dipilih.');
      _tabController.animateTo(0);
      return false;
    }
    if (_hasSubCategories && _subCategoryId == null) {
      _showWarn('Sub kategori wajib dipilih karena kategori ini punya sub kategori aktif.');
      _tabController.animateTo(0);
      return false;
    }
    if (_requiresWarehouseDivision && _warehouseDivisionId == null) {
      _showWarn('Warehouse Division wajib dipilih untuk kategori ini.');
      _tabController.animateTo(0);
      return false;
    }
    if (_smallUnitId == null) {
      _showWarn('Small Unit wajib dipilih.');
      _tabController.animateTo(1);
      return false;
    }
    if (_showBomTabContent) {
      final invalidBom = _bom.any((b) =>
          _parseId(b['item_id']) == null ||
          _parseId(b['unit_id']) == null ||
          _toDouble(b['qty']) <= 0);
      if (invalidBom) {
        _showWarn('Semua baris BOM harus isi item, qty > 0, dan unit.');
        _tabController.animateTo(3);
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateMandatoryBeforeSubmit()) return;
    setState(() => _isSaving = true);
    try {
      final body = _buildBody();
      Map<String, dynamic>? res;
      if (_isEdit && _itemId != null) {
        if (_newImages.isNotEmpty || _deletedImagePaths.isNotEmpty) {
          res = await _service.updateWithImages(
            _itemId!,
            body,
            images: _newImages,
            deletedImages: _deletedImagePaths,
          );
        } else {
          res = await _service.update(_itemId!, body);
        }
      } else {
        if (_newImages.isNotEmpty) {
          res = await _service.createWithImages(body, images: _newImages);
        } else {
          res = await _service.create(body);
        }
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Item berhasil diupdate.'
                : 'Item berhasil ditambahkan.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      _showValidationErrors(res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showWarn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showValidationErrors(Map<String, dynamic>? res) {
    final errors = res?['errors'];
    if (errors is Map) {
      final msg = errors.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res?['message']?.toString() ?? 'Gagal menyimpan data item.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Item' : 'Tambah Item',
      showDrawer: false,
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(
                size: 48,
                color: Color(0xFF2563EB),
              ),
            )
          : Column(
              children: [
                Material(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    controller: _tabController,
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF2563EB),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.info_outline, size: 20),
                        text: _tabLabel(
                          'Info',
                          required: true,
                        ),
                      ),
                      const Tab(
                        icon: Icon(Icons.straighten, size: 20),
                        text: 'UoM *',
                      ),
                      const Tab(
                        icon: Icon(Icons.tune, size: 20),
                        text: 'Modifier',
                      ),
                      const Tab(
                        icon: Icon(Icons.build_circle_outlined, size: 20),
                        text: 'BOM',
                      ),
                      const Tab(
                        icon: Icon(Icons.attach_money, size: 20),
                        text: 'Price',
                      ),
                      const Tab(
                        icon: Icon(Icons.store_mall_directory_outlined, size: 20),
                        text: 'Availability',
                      ),
                      const Tab(
                        icon: Icon(Icons.description_outlined, size: 20),
                        text: 'SPS',
                      ),
                      const Tab(
                        icon: Icon(Icons.preview_outlined, size: 20),
                        text: 'Preview',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabInfo(),
                        _buildTabUom(),
                        _buildTabModifier(),
                        _buildTabBom(),
                        _buildTabPrice(),
                        _buildTabAvailability(),
                        _buildTabSps(),
                        _buildTabPreview(),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving
                              ? 'Menyimpan...'
                              : (_isEdit ? 'Simpan Perubahan' : 'Simpan Item'),
                        ),
                      ),
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
          DropdownButtonFormField<String>(
            initialValue: _compositionType,
            decoration: const InputDecoration(labelText: 'Composition Type *'),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'composed', child: Text('Composed')),
            ],
            onChanged: (v) {
              setState(() {
                _compositionType = v ?? 'single';
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Select Category'),
              ),
              ..._categories.map((c) {
                return DropdownMenuItem<int?>(
                  value: _parseId(c['id']),
                  child: Text(c['name']?.toString() ?? '-'),
                );
              }),
            ],
            onChanged: (v) {
              setState(() {
                _categoryId = v;
                if (!_hasSubCategories) _subCategoryId = null;
                if (!_requiresWarehouseDivision) _warehouseDivisionId = null;
                if (!_canUseModifier) {
                  _modifierEnabled = false;
                  _modifierOptionIds.clear();
                }
                _generateSkuFromCategory();
              });
            },
            validator: (v) => v == null ? 'Category wajib dipilih' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _subCategoryId,
            decoration: InputDecoration(
              labelText: _hasSubCategories ? 'Sub Category *' : 'Sub Category',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Select Sub Category'),
              ),
              ..._filteredSubCategories.map((s) {
                return DropdownMenuItem<int?>(
                  value: _parseId(s['id']),
                  child: Text(s['name']?.toString() ?? '-'),
                );
              }),
            ],
            onChanged: (v) => setState(() => _subCategoryId = v),
          ),
          if (_requiresWarehouseDivision) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _warehouseDivisionId,
              decoration: const InputDecoration(
                labelText: 'Warehouse Division *',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Select Warehouse Division'),
                ),
                ..._warehouseDivisions.map((w) {
                  return DropdownMenuItem<int?>(
                    value: _parseId(w['id']),
                    child: Text(w['name']?.toString() ?? '-'),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _warehouseDivisionId = v),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _skuController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'SKU *',
              helperText: 'Auto-generated mengikuti kategori',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'SKU wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type *'),
            items: [
              ..._menuTypes
                  .where((m) => (m['type']?.toString().trim().isNotEmpty ?? false))
                  .map((m) => DropdownMenuItem<String>(
                        value: m['type']?.toString(),
                        child: Text(m['type']?.toString() ?? '-'),
                      )),
              if (_menuTypes.isEmpty) ...const [
                DropdownMenuItem(value: 'product', child: Text('product')),
                DropdownMenuItem(value: 'service', child: Text('service')),
              ],
            ],
            onChanged: (v) => setState(() => _type = v ?? 'product'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Type wajib dipilih' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama item wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _minStockController,
            decoration: const InputDecoration(labelText: 'Minimum Stock *'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final parsed = int.tryParse(v?.trim() ?? '');
              if (parsed == null || parsed < 0) return 'Minimum stock harus >= 0';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status *'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'active'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _expController,
            decoration: const InputDecoration(
              labelText: 'Expiry Days (optional)',
            ),
            keyboardType: TextInputType.number,
          ),
          if (_canUseModifier) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktifkan Modifier'),
              subtitle: const Text('Sama seperti toggle di web'),
              value: _modifierEnabled,
              onChanged: (v) => setState(() => _modifierEnabled = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabUom() {
    final unitItems = [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Select Unit'),
      ),
      ..._units.map((u) {
        final name = u['name']?.toString() ?? '-';
        final code = u['code']?.toString();
        return DropdownMenuItem<int?>(
          value: _parseId(u['id']),
          child: Text(
            code == null || code.isEmpty ? name : '$name ($code)',
          ),
        );
      }),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _smallUnitId,
            decoration: const InputDecoration(labelText: 'Small Unit *'),
            items: unitItems,
            onChanged: (v) => setState(() => _smallUnitId = v),
            validator: (v) => v == null ? 'Small unit wajib dipilih' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _mediumUnitId,
            decoration: const InputDecoration(
              labelText: 'Medium Unit (optional)',
            ),
            items: unitItems,
            onChanged: (v) => setState(() => _mediumUnitId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _largeUnitId,
            decoration: const InputDecoration(
              labelText: 'Large Unit (optional)',
            ),
            items: unitItems,
            onChanged: (v) => setState(() => _largeUnitId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mediumConversionController,
            decoration: const InputDecoration(
              labelText: 'Medium Conversion Qty',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _smallConversionController,
            decoration: const InputDecoration(
              labelText: 'Small Conversion Qty',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabModifier() {
    if (!_canUseModifier) {
      return _buildInfoMessage(
        'Modifier hanya aktif untuk kategori POS (show_pos = 1).',
      );
    }
    if (!_modifierEnabled) {
      return _buildInfoMessage(
        'Toggle "Aktifkan Modifier" di tab Info untuk memilih modifier option.',
      );
    }
    if (_modifiers.isEmpty) {
      return _buildInfoMessage('Tidak ada data modifier.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _modifiers.map((m) {
        final options = _toList(m['options']);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(m['name']?.toString() ?? 'Modifier'),
            children: options.map((opt) {
              final optId = _parseId(opt['id']);
              final selected = optId != null && _modifierOptionIds.contains(optId);
              return CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                value: selected,
                title: Text(
                  opt['name']?.toString() ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                controlAffinity: ListTileControlAffinity.trailing,
                onChanged: (checked) {
                  if (optId == null) return;
                  setState(() {
                    if (checked == true) {
                      if (!_modifierOptionIds.contains(optId)) {
                        _modifierOptionIds.add(optId);
                      }
                    } else {
                      _modifierOptionIds.remove(optId);
                    }
                  });
                },
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabBom() {
    if (!_showBomTabContent) {
      return _buildInfoMessage(
        'Tab BOM aktif jika Composition Type = Composed.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_bom.length, (index) {
            final row = _bom[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: _parseId(row['item_id']),
                      decoration: const InputDecoration(labelText: 'Bahan Item'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Pilih Item'),
                        ),
                        ..._bomItems
                            .where((it) => _parseId(it['id']) != _itemId)
                            .map((it) => DropdownMenuItem<int?>(
                                  value: _parseId(it['id']),
                                  child: Text(
                                    it['name']?.toString() ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                      ],
                      onChanged: (v) => setState(() => row['item_id'] = v),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 430;
                        final qtyField = TextFormField(
                          initialValue: _toDouble(row['qty']).toString(),
                          decoration: const InputDecoration(labelText: 'Qty'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (v) =>
                              row['qty'] = double.tryParse(v.trim()) ?? 0,
                        );
                        final unitField = DropdownButtonFormField<int?>(
                          initialValue: _parseId(row['unit_id']),
                          decoration: const InputDecoration(labelText: 'Unit'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Pilih Unit'),
                            ),
                            ..._units.map((u) => DropdownMenuItem<int?>(
                                  value: _parseId(u['id']),
                                  child: Text(
                                    u['name']?.toString() ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => row['unit_id'] = v),
                        );
                        if (isNarrow) {
                          return Column(
                            children: [
                              qtyField,
                              const SizedBox(height: 8),
                              unitField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: qtyField),
                            const SizedBox(width: 8),
                            Expanded(child: unitField),
                          ],
                        );
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: row['stock_cut'] == true,
                      title: const Text('Stock Cut'),
                      onChanged: (v) => setState(() => row['stock_cut'] = v == true),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => setState(() => _bom.removeAt(index)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _bom.add({
                  'item_id': null,
                  'qty': 0.0,
                  'unit_id': null,
                  'stock_cut': false,
                });
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Bahan BOM'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPrice() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...List.generate(_prices.length, (index) {
            final row = _prices[index];
            final priceType = row['price_type']?.toString() ?? 'specific';
            final isAll = priceType == 'all';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: priceType,
                      decoration: const InputDecoration(labelText: 'Price Type'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'All',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'specific',
                          child: Text(
                            'Specific Region/Outlet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selectedItemBuilder: (context) => const [
                        Text('All', maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          'Specific Region/Outlet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          row['price_type'] = v ?? 'specific';
                          if (row['price_type'] == 'all') {
                            row['region_id'] = null;
                            row['outlet_id'] = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 700;
                        final regionField = DropdownButtonFormField<int?>(
                          initialValue: _parseId(row['region_id']),
                          decoration: const InputDecoration(labelText: 'Region'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All'),
                            ),
                            ..._regions.map((r) => DropdownMenuItem<int?>(
                                  value: _parseId(r['id']),
                                  child: Text(
                                    r['name']?.toString() ?? '-',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: isAll
                              ? null
                              : (v) {
                                  setState(() {
                                    row['region_id'] = v;
                                    if (v != null) row['outlet_id'] = null;
                                  });
                                },
                        );
                        final outletField = DropdownButtonFormField<int?>(
                          initialValue: _parseId(row['outlet_id']),
                          decoration: const InputDecoration(labelText: 'Outlet'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All'),
                            ),
                            ..._outlets.map((o) => DropdownMenuItem<int?>(
                                  value: _parseId(o['id_outlet'] ?? o['id']),
                                  child: Text(
                                    o['nama_outlet']?.toString() ?? '-',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: isAll
                              ? null
                              : (v) {
                                  setState(() {
                                    row['outlet_id'] = v;
                                    if (v != null) row['region_id'] = null;
                                  });
                                },
                        );
                        if (isNarrow) {
                          return Column(
                            children: [
                              regionField,
                              const SizedBox(height: 8),
                              outletField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: regionField),
                            const SizedBox(width: 8),
                            Expanded(child: outletField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 700;
                        final priceField = TextFormField(
                          initialValue: _toDouble(row['price']).toString(),
                          decoration: const InputDecoration(labelText: 'Harga *'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final parsed = double.tryParse(v?.trim() ?? '');
                            if (parsed == null || parsed < 0) {
                              return 'Harga harus >= 0';
                            }
                            return null;
                          },
                          onChanged: (v) =>
                              row['price'] = double.tryParse(v.trim()) ?? 0,
                        );
                        final removeBtn = IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: _prices.length > 1
                              ? () => setState(() => _prices.removeAt(index))
                              : null,
                        );
                        if (isNarrow) {
                          return Column(
                            children: [
                              priceField,
                              Align(
                                alignment: Alignment.centerRight,
                                child: removeBtn,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: priceField),
                            removeBtn,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _prices.add({
                  'price_type': 'specific',
                  'region_id': null,
                  'outlet_id': null,
                  'price': 0.0,
                });
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Harga'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabAvailability() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...List.generate(_availabilities.length, (index) {
            final row = _availabilities[index];
            final regionId = _parseId(row['region_id']);
            final outletId = _parseId(row['outlet_id']);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    final regionField = DropdownButtonFormField<int?>(
                      initialValue: regionId,
                      decoration: const InputDecoration(labelText: 'Region'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All'),
                        ),
                        ..._regions.map((r) => DropdownMenuItem<int?>(
                              value: _parseId(r['id']),
                              child: Text(
                                r['name']?.toString() ?? '-',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (v) => setState(() {
                        row['region_id'] = v;
                        if (v != null) row['outlet_id'] = null;
                      }),
                    );
                    final outletField = DropdownButtonFormField<int?>(
                      initialValue: outletId,
                      decoration: const InputDecoration(labelText: 'Outlet'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All'),
                        ),
                        ..._outlets.map((o) => DropdownMenuItem<int?>(
                              value: _parseId(o['id_outlet'] ?? o['id']),
                              child: Text(
                                o['nama_outlet']?.toString() ?? '-',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (v) => setState(() {
                        row['outlet_id'] = v;
                        if (v != null) row['region_id'] = null;
                      }),
                    );
                    final removeBtn = IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () => setState(
                        () => _availabilities.removeAt(index),
                      ),
                    );
                    if (isNarrow) {
                      return Column(
                        children: [
                          regionField,
                          const SizedBox(height: 8),
                          outletField,
                          Align(
                            alignment: Alignment.centerRight,
                            child: removeBtn,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: regionField),
                        const SizedBox(width: 8),
                        Expanded(child: outletField),
                        removeBtn,
                      ],
                    );
                  },
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _availabilities.add({
                  'region_id': null,
                  'outlet_id': null,
                  'status': 'available',
                });
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Availability'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSps() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _specificationController,
            decoration: const InputDecoration(labelText: 'Specification'),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          Text(
            'Images',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jumlah gambar: $_totalImageCount / $_maxImages',
            style: TextStyle(
              fontSize: 12,
              color: _totalImageCount >= _maxImages
                  ? Colors.orange.shade700
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _totalImageCount >= _maxImages
                    ? null
                    : _pickImageFromCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _totalImageCount >= _maxImages
                    ? null
                    : _pickImageFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
              ),
            ],
          ),
          if (_existingImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Gambar tersimpan',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_existingImages.length, (index) {
                final image = _existingImages[index];
                final imageUrl = _storageImageUrl(image['path']?.toString());
                return _imageTile(
                  indexLabel: '#${index + 1}',
                  child: imageUrl.isEmpty
                      ? const Center(child: Icon(Icons.broken_image_outlined))
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                  onRemove: () => _removeExistingImageAt(index),
                );
              }),
            ),
          ],
          if (_newImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Gambar baru',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_newImages.length, (index) {
                final file = File(_newImages[index].path);
                return _imageTile(
                  indexLabel: '#${_existingImages.length + index + 1}',
                  showReorderControls: true,
                  onMoveLeft: () => _moveNewImageLeft(index),
                  onMoveRight: () => _moveNewImageRight(index),
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  onRemove: () => _removeNewImageAt(index),
                );
              }),
            ),
          ],
          if (_existingImages.isEmpty && _newImages.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Belum ada gambar.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          if (_deletedImagePaths.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${_deletedImagePaths.length} gambar akan dihapus saat simpan.',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageTile({
    required Widget child,
    required VoidCallback onRemove,
    String? indexLabel,
    bool showReorderControls = false,
    VoidCallback? onMoveLeft,
    VoidCallback? onMoveRight,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 96,
            child: ColoredBox(
              color: Colors.grey.shade100,
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
        if (showReorderControls)
          Positioned(
            left: 2,
            top: 2,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onMoveLeft,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onMoveRight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (indexLabel != null && indexLabel.isNotEmpty)
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                indexLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabPreview() {
    final bomPreview = _showBomTabContent
        ? _bom
            .where((b) => _parseId(b['item_id']) != null)
            .map((b) {
              final itemName = _labelById(_bomItems, _parseId(b['item_id']));
              final unitName = _labelById(_units, _parseId(b['unit_id']));
              return '• $itemName - ${_toDouble(b['qty'])} $unitName'
                  '${b['stock_cut'] == true ? ' (Stock Cut)' : ''}';
            })
            .toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: 'Item Information',
            children: [
              _kv('Composition Type', _compositionType),
              _kv('Category', _labelById(_categories, _categoryId)),
              _kv('Sub Category', _labelById(_subCategories, _subCategoryId)),
              _kv('Warehouse Division',
                  _labelById(_warehouseDivisions, _warehouseDivisionId)),
              _kv('SKU', _skuController.text.trim().isEmpty ? '-' : _skuController.text.trim()),
              _kv('Type', _type),
              _kv('Name', _nameController.text.trim()),
              _kv('Minimum Stock', _minStockController.text.trim()),
              _kv('Status', _status),
              _kv('Exp', _expController.text.trim()),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'UoM',
            children: [
              _kv('Small Unit', _labelById(_units, _smallUnitId)),
              _kv('Medium Unit', _labelById(_units, _mediumUnitId)),
              _kv('Large Unit', _labelById(_units, _largeUnitId)),
              _kv('Medium Conversion', _mediumConversionController.text.trim()),
              _kv('Small Conversion', _smallConversionController.text.trim()),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Modifier',
            children: [
              _kv('Modifier Enabled', _modifierEnabled ? 'Yes' : 'No'),
              _kv('Total Option', _modifierOptionIds.length.toString()),
            ],
          ),
          if (_showBomTabContent) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'BOM',
              children: bomPreview.isEmpty
                  ? [const Text('Belum ada BOM')]
                  : bomPreview.map((e) => Text(e)).toList(),
            ),
          ],
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Prices',
            children: _prices.map((p) {
              final price = _toDouble(p['price']);
              final priceType = p['price_type']?.toString() ?? 'specific';
              final target = priceType == 'all'
                  ? 'All'
                  : (_parseId(p['region_id']) != null
                      ? 'Region: ${_regionLabel(_parseId(p['region_id']))}'
                      : (_parseId(p['outlet_id']) != null
                          ? 'Outlet: ${_outletLabel(_parseId(p['outlet_id']))}'
                          : 'All'));
              return Text('• $target -> Rp $price');
            }).toList(),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Availability',
            children: _availabilities.isEmpty
                ? [const Text('All (default)')]
                : _availabilities.map((a) {
                    final text = _parseId(a['region_id']) != null
                        ? 'Region: ${_regionLabel(_parseId(a['region_id']))}'
                        : (_parseId(a['outlet_id']) != null
                            ? 'Outlet: ${_outletLabel(_parseId(a['outlet_id']))}'
                            : 'All');
                    return Text('• $text');
                  }).toList(),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'SPS',
            children: [
              _kv('Description', _descriptionController.text.trim().isEmpty
                  ? '-'
                  : _descriptionController.text.trim()),
              _kv('Specification', _specificationController.text.trim().isEmpty
                  ? '-'
                  : _specificationController.text.trim()),
              _kv('Existing Images', _existingImages.length.toString()),
              _kv('New Images', _newImages.length.toString()),
              _kv('Delete Images', _deletedImagePaths.length.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
          children: [
            TextSpan(
              text: '$key: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ),
    );
  }
}
