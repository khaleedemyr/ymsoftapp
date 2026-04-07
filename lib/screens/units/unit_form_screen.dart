import 'package:flutter/material.dart';
import '../../services/unit_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class UnitFormScreen extends StatefulWidget {
  final Map<String, dynamic>? unit;

  const UnitFormScreen({super.key, this.unit});

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  final UnitService _service = UnitService();
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSaving = false;
  String _status = 'active';

  bool get _isEdit => widget.unit != null;

  @override
  void initState() {
    super.initState();
    if (widget.unit != null) {
      _codeController.text = widget.unit!['code']?.toString() ?? '';
      _nameController.text = widget.unit!['name']?.toString() ?? '';
      _status = widget.unit!['status']?.toString() ?? 'active';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final code = _codeController.text.trim();
      final name = _nameController.text.trim();

      if (_isEdit) {
        final id = widget.unit!['id'] is int
            ? widget.unit!['id'] as int
            : int.tryParse(widget.unit!['id'].toString());
        if (id == null) throw Exception('Invalid id');
        final res = await _service.update(id, code: code, name: name, status: _status);
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unit berhasil diupdate'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            _showValidationErrors(res);
          }
        }
      } else {
        final res = await _service.create(code: code, name: name, status: _status);
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unit berhasil ditambahkan'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Unit' : 'Tambah Unit',
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
                      decoration: InputDecoration(
                        labelText: 'Kode',
                        hintText: 'Kode unit (unik)',
                        border: const OutlineInputBorder(),
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
                        hintText: 'Nama unit',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'active'),
                    ),
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
