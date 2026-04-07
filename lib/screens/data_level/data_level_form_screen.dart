import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_level_service.dart';
import '../../widgets/app_scaffold.dart';

class DataLevelFormScreen extends StatefulWidget {
  final Map<String, dynamic>? dataLevel;

  const DataLevelFormScreen({super.key, this.dataLevel});

  @override
  State<DataLevelFormScreen> createState() => _DataLevelFormScreenState();
}

class _DataLevelFormScreenState extends State<DataLevelFormScreen> {
  final DataLevelService _service = DataLevelService();
  final _formKey = GlobalKey<FormState>();
  final _namaLevelController = TextEditingController();
  final _nilaiLevelController = TextEditingController();
  final _nilaiPublicHolidayController = TextEditingController(text: '0');
  final _nilaiDasarPotonganBpjsController = TextEditingController(text: '0');
  final _nilaiPointController = TextEditingController(text: '0');

  bool _isSaving = false;
  static const _blue = Color(0xFF2563EB);

  bool get _isEdit => widget.dataLevel != null;

  @override
  void initState() {
    super.initState();
    if (widget.dataLevel != null) {
      _namaLevelController.text = widget.dataLevel!['nama_level']?.toString() ?? '';
      _nilaiLevelController.text = widget.dataLevel!['nilai_level']?.toString() ?? '';
      _nilaiPublicHolidayController.text = (widget.dataLevel!['nilai_public_holiday'] ?? 0).toString();
      _nilaiDasarPotonganBpjsController.text = (widget.dataLevel!['nilai_dasar_potongan_bpjs'] ?? 0).toString();
      _nilaiPointController.text = (widget.dataLevel!['nilai_point'] ?? 0).toString();
    }
  }

  @override
  void dispose() {
    _namaLevelController.dispose();
    _nilaiLevelController.dispose();
    _nilaiPublicHolidayController.dispose();
    _nilaiDasarPotonganBpjsController.dispose();
    _nilaiPointController.dispose();
    super.dispose();
  }

  int _parseInt(String v) {
    final n = int.tryParse(v.trim());
    return n ?? 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final namaLevel = _namaLevelController.text.trim();
      final nilaiLevel = _nilaiLevelController.text.trim();
      final nilaiPublicHoliday = _parseInt(_nilaiPublicHolidayController.text);
      final nilaiDasarPotonganBpjs = _parseInt(_nilaiDasarPotonganBpjsController.text);
      final nilaiPoint = _parseInt(_nilaiPointController.text);

      if (_isEdit) {
        final id = widget.dataLevel!['id'] is int
            ? widget.dataLevel!['id'] as int
            : int.tryParse(widget.dataLevel!['id'].toString());
        if (id == null) throw Exception('Invalid id');
        final res = await _service.update(
          id,
          namaLevel: namaLevel,
          nilaiLevel: nilaiLevel,
          nilaiPublicHoliday: nilaiPublicHoliday,
          nilaiDasarPotonganBpjs: nilaiDasarPotonganBpjs,
          nilaiPoint: nilaiPoint,
        );
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data Level berhasil diupdate'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            _showValidationErrors(res);
          }
        }
      } else {
        final res = await _service.create(
          namaLevel: namaLevel,
          nilaiLevel: nilaiLevel,
          nilaiPublicHoliday: nilaiPublicHoliday,
          nilaiDasarPotonganBpjs: nilaiDasarPotonganBpjs,
          nilaiPoint: nilaiPoint,
        );
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data Level berhasil ditambahkan'), backgroundColor: Colors.green),
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
      title: _isEdit ? 'Edit Data Level' : 'Tambah Data Level',
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
                      controller: _namaLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Level',
                        hintText: 'Nama level',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nama level wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nilaiLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Nilai Level',
                        hintText: 'Nilai level',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nilai level wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nilaiPublicHolidayController,
                      decoration: const InputDecoration(
                        labelText: 'Nilai Public Holiday',
                        hintText: '0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                        if (_parseInt(v) < 0) return 'Minimal 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nilaiDasarPotonganBpjsController,
                      decoration: const InputDecoration(
                        labelText: 'Nilai Dasar Potongan BPJS',
                        hintText: '0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                        if (_parseInt(v) < 0) return 'Minimal 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nilaiPointController,
                      decoration: const InputDecoration(
                        labelText: 'Nilai Point',
                        hintText: '0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                        if (_parseInt(v) < 0) return 'Minimal 0';
                        return null;
                      },
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
                backgroundColor: _blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
