import 'package:flutter/material.dart';
import '../../services/sub_category_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class SubCategoryFormScreen extends StatefulWidget {
  final Map<String, dynamic>? subCategory;
  final List<Map<String, dynamic>> categories;

  const SubCategoryFormScreen({super.key, this.subCategory, required this.categories});

  @override
  State<SubCategoryFormScreen> createState() => _SubCategoryFormScreenState();
}

class _SubCategoryFormScreenState extends State<SubCategoryFormScreen> {
  final SubCategoryService _service = SubCategoryService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String _status = 'active';
  int _showPos = 1;
  int? _categoryId;
  String _availabilityType = 'byRegion';
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _selectedRegions = [];
  List<Map<String, dynamic>> _selectedOutlets = [];

  bool get _isEdit => widget.subCategory != null;

  @override
  void initState() {
    super.initState();
    if (widget.subCategory != null) {
      _nameController.text = widget.subCategory!['name']?.toString() ?? '';
      _descriptionController.text = widget.subCategory!['description']?.toString() ?? '';
      _status = widget.subCategory!['status']?.toString() ?? 'active';
      _showPos = widget.subCategory!['show_pos'] is int
          ? widget.subCategory!['show_pos'] as int
          : int.tryParse(widget.subCategory!['show_pos'].toString()) ?? 1;
      _categoryId = widget.subCategory!['category_id'] is int
          ? widget.subCategory!['category_id'] as int
          : int.tryParse(widget.subCategory!['category_id'].toString());
      final availabilities = widget.subCategory!['availabilities'];
      if (availabilities is List && availabilities.isNotEmpty) {
        final first = availabilities.first as Map<String, dynamic>;
        _availabilityType = first['availability_type'] == 'byOutlet' ? 'byOutlet' : 'byRegion';
      }
    }
    _loadCreateData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getCreateData();
      if (mounted && data != null) {
        final regions = data['regions'] as List?;
        final outlets = data['outlets'] as List?;
        setState(() {
          _regions = regions?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
          _outlets = outlets?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
          if (_isEdit && widget.subCategory != null) {
            final availabilities = widget.subCategory!['availabilities'];
            if (availabilities is List) {
              for (final a in availabilities) {
                if (a is Map) {
                  if (a['availability_type'] == 'byRegion' && a['region'] != null) {
                    _selectedRegions.add(Map<String, dynamic>.from(a['region'] as Map));
                  } else if (a['availability_type'] == 'byOutlet' && a['outlet'] != null) {
                    final o = a['outlet'] as Map;
                    _selectedOutlets.add({
                      'id': o['id_outlet'] ?? o['id'],
                      'nama_outlet': o['nama_outlet'] ?? o['name'],
                      'region_id': o['region_id'],
                    });
                  }
                }
              }
              if (_selectedOutlets.isNotEmpty) _availabilityType = 'byOutlet';
            }
          }
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<int> _getRegionIds() => _selectedRegions
      .map((r) => r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()))
      .whereType<int>()
      .toList();

  List<int> _getOutletIds() => _selectedOutlets
      .map((o) => o['id'] is int ? o['id'] as int : int.tryParse(o['id'].toString()))
      .whereType<int>()
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      String? availabilityType;
      List<int>? regionIds;
      List<int>? outletIds;
      if (_showPos == 1) {
        availabilityType = _availabilityType;
        if (_availabilityType == 'byRegion') {
          regionIds = _getRegionIds();
          if (regionIds.isEmpty) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih minimal satu region'), backgroundColor: Colors.orange),
            );
            return;
          }
        } else {
          outletIds = _getOutletIds();
          if (outletIds.isEmpty) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih minimal satu outlet'), backgroundColor: Colors.orange),
            );
            return;
          }
        }
      }

      if (_isEdit) {
        final id = widget.subCategory!['id'] is int
            ? widget.subCategory!['id'] as int
            : int.tryParse(widget.subCategory!['id'].toString());
        if (id == null) throw Exception('Invalid id');
        final res = await _service.update(id,
            name: name,
            description: description.isEmpty ? null : description,
            categoryId: _categoryId!,
            status: _status,
            showPos: _showPos,
            availabilityType: availabilityType,
            regionIds: regionIds,
            outletIds: outletIds);
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sub kategori berhasil diupdate'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            _showValidationErrors(res);
          }
        }
      } else {
        final res = await _service.create(
            name: name,
            description: description.isEmpty ? null : description,
            categoryId: _categoryId!,
            status: _status,
            showPos: _showPos,
            availabilityType: availabilityType,
            regionIds: regionIds,
            outletIds: outletIds);
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sub kategori berhasil ditambahkan'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            _showValidationErrors(res);
          }
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
        const SnackBar(content: Text('Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  String _outletLabel(Map<String, dynamic> o) =>
      o['nama_outlet']?.toString() ?? o['name']?.toString() ?? '-';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        title: _isEdit ? 'Edit Sub Kategori' : 'Tambah Sub Kategori',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 48, color: Color(0xFF2563EB))),
      );
    }

    return AppScaffold(
      title: _isEdit ? 'Edit Sub Kategori' : 'Tambah Sub Kategori',
      showDrawer: false,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        hintText: 'Nama sub kategori',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi (opsional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Pilih Kategori')),
                        ...widget.categories.map((c) {
                          final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id'].toString());
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(c['name']?.toString() ?? '-'),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'Pilih kategori' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'active', child: Text('Active')),
                              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                            ],
                            onChanged: (v) => setState(() => _status = v ?? 'active'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Show POS', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              SwitchListTile(
                                title: Text(_showPos == 1 ? 'Ya' : 'Tidak'),
                                value: _showPos == 1,
                                onChanged: (v) => setState(() => _showPos = v ? 1 : 0),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_showPos == 1) ...[
                      const SizedBox(height: 16),
                      const Text('Ketersediaan', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'byRegion', label: Text('By Region'), icon: Icon(Icons.public)),
                          ButtonSegment(value: 'byOutlet', label: Text('By Outlet'), icon: Icon(Icons.store)),
                        ],
                        selected: {_availabilityType},
                        onSelectionChanged: (s) => setState(() => _availabilityType = s.first),
                      ),
                      const SizedBox(height: 12),
                      if (_availabilityType == 'byRegion') ...[
                        const Text('Pilih Region', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _regions.map((r) {
                            final id = r['id'];
                            final name = r['name']?.toString() ?? r['code']?.toString() ?? '-';
                            final isSelected = _selectedRegions.any((s) => s['id'] == id);
                            return FilterChip(
                              label: Text(name),
                              selected: isSelected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    if (!_selectedRegions.any((s) => s['id'] == id)) _selectedRegions.add(r);
                                  } else {
                                    _selectedRegions.removeWhere((s) => s['id'] == id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        const Text('Pilih Outlet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _outlets.map((o) {
                            final id = o['id'];
                            final name = _outletLabel(o);
                            final isSelected = _selectedOutlets.any((s) => s['id'] == id);
                            return FilterChip(
                              label: Text(name),
                              selected: isSelected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    if (!_selectedOutlets.any((s) => s['id'] == id)) _selectedOutlets.add(o);
                                  } else {
                                    _selectedOutlets.removeWhere((s) => s['id'] == id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
