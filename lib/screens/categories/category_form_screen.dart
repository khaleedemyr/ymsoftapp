import 'package:flutter/material.dart';
import '../../services/category_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class CategoryFormScreen extends StatefulWidget {
  final Map<String, dynamic>? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final CategoryService _service = CategoryService();
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String _status = 'active';
  int _showPos = 1;
  String _availabilityType = 'byRegion'; // byRegion | byOutlet
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _selectedRegions = [];
  List<Map<String, dynamic>> _selectedOutlets = [];

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _codeController.text = widget.category!['code']?.toString() ?? '';
      _nameController.text = widget.category!['name']?.toString() ?? '';
      _descriptionController.text = widget.category!['description']?.toString() ?? '';
      _status = widget.category!['status']?.toString() ?? 'active';
      _showPos = widget.category!['show_pos'] is int
          ? widget.category!['show_pos'] as int
          : int.tryParse(widget.category!['show_pos'].toString()) ?? 1;
      final outletIds = widget.category!['outlet_ids'];
      if (outletIds is List && outletIds.isNotEmpty) {
        _availabilityType = 'byOutlet';
      }
    }
    _loadCreateData();
  }

  @override
  void dispose() {
    _codeController.dispose();
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
          if (_isEdit && widget.category != null) {
            final outletIds = widget.category!['outlet_ids'];
            if (outletIds is List) {
              final ids = outletIds.map((e) => e is int ? e : int.tryParse(e.toString())).whereType<int>().toSet();
              _selectedOutlets = _outlets.where((o) {
                final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id'].toString());
                return id != null && ids.contains(id);
              }).toList();
              final regionIds = _selectedOutlets.map((o) => o['region_id']).toSet();
              _selectedRegions = _regions.where((r) {
                final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString());
                return id != null && regionIds.contains(id);
              }).toList();
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

  List<int> _getOutletIds() {
    if (_showPos != 1) return [];
    if (_availabilityType == 'byRegion') {
      final regionIds = _selectedRegions.map((r) {
        final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString());
        return id;
      }).whereType<int>().toSet();
      return _outlets
          .where((o) => regionIds.contains(o['region_id']))
          .map((o) => o['id'] is int ? o['id'] as int : int.tryParse(o['id'].toString()))
          .whereType<int>()
          .toList();
    }
    return _selectedOutlets
        .map((o) => o['id'] is int ? o['id'] as int : int.tryParse(o['id'].toString()))
        .whereType<int>()
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final code = _codeController.text.trim();
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final outletIds = _getOutletIds();

      if (_isEdit) {
        final id = widget.category!['id'] is int
            ? widget.category!['id'] as int
            : int.tryParse(widget.category!['id'].toString());
        if (id == null) throw Exception('Invalid id');
        final res = await _service.update(id,
            code: code,
            name: name,
            description: description.isEmpty ? null : description,
            status: _status,
            showPos: _showPos,
            outletIds: outletIds.isEmpty ? null : outletIds);
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kategori berhasil diupdate'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            _showValidationErrors(res);
          }
        }
      } else {
        final res = await _service.create(
            code: code,
            name: name,
            description: description.isEmpty ? null : description,
            status: _status,
            showPos: _showPos,
            outletIds: outletIds.isEmpty ? null : outletIds);
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kategori berhasil ditambahkan'), backgroundColor: Colors.green),
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

  String _outletLabel(Map<String, dynamic> o) {
    return o['nama_outlet']?.toString() ?? o['name']?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        title: _isEdit ? 'Edit Kategori' : 'Tambah Kategori',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 48, color: Color(0xFF2563EB))),
      );
    }

    return AppScaffold(
      title: _isEdit ? 'Edit Kategori' : 'Tambah Kategori',
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
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Kode',
                        hintText: 'Kode kategori (unik)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 50,
                      enabled: !_isEdit,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Kode wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        hintText: 'Nama kategori',
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
                              const SizedBox(height: 4),
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
                      const Text('Ketersediaan kategori', style: TextStyle(fontWeight: FontWeight.w600)),
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
                                    if (!_selectedRegions.any((s) => s['id'] == id)) {
                                      _selectedRegions.add(r);
                                    }
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
                                    if (!_selectedOutlets.any((s) => s['id'] == id)) {
                                      _selectedOutlets.add(o);
                                    }
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
