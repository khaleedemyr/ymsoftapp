import 'package:flutter/material.dart';
import '../../services/jabatan_service.dart';
import '../../widgets/app_scaffold.dart';

class JabatanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? jabatan;

  const JabatanFormScreen({super.key, this.jabatan});

  @override
  State<JabatanFormScreen> createState() => _JabatanFormScreenState();
}

class _JabatanFormScreenState extends State<JabatanFormScreen> {
  final JabatanService _service = JabatanService();
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingDropdown = true;
  List<Map<String, dynamic>> _jabatans = [];
  List<Map<String, dynamic>> _divisis = [];
  List<Map<String, dynamic>> _subDivisis = [];
  List<Map<String, dynamic>> _levels = [];

  int? _idAtasan;
  int? _idDivisi;
  int? _idSubDivisi;
  int? _idLevel;
  static const _blue = Color(0xFF2563EB);

  bool get _isEdit => widget.jabatan != null;

  @override
  void initState() {
    super.initState();
    if (widget.jabatan != null) {
      _namaController.text = widget.jabatan!['nama_jabatan']?.toString() ?? '';
      _idAtasan = _parseId(widget.jabatan!['id_atasan']);
      _idDivisi = _parseId(widget.jabatan!['id_divisi']);
      _idSubDivisi = _parseId(widget.jabatan!['id_sub_divisi']);
      _idLevel = _parseId(widget.jabatan!['id_level']);
    }
    _loadCreateData();
  }

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final n = int.tryParse(v.toString());
    return n;
  }

  @override
  void dispose() {
    _namaController.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    setState(() => _isLoadingDropdown = true);
    final result = await _service.getCreateData();
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      setState(() {
        _jabatans = _toList(result['jabatans']);
        _divisis = _toList(result['divisis']);
        _subDivisis = _toList(result['subDivisis'] ?? result['sub_divisis']);
        _levels = _toList(result['levels']);
        _isLoadingDropdown = false;
      });
    } else {
      setState(() => _isLoadingDropdown = false);
      final msg = result?['message']?.toString() ?? 'Gagal memuat data dropdown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Muat ulang',
            textColor: Colors.white,
            onPressed: _loadCreateData,
          ),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => Map<String, dynamic>.from(e is Map ? e : <String, dynamic>{})).toList();
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idDivisi == null || _idSubDivisi == null || _idLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Divisi, Sub Divisi, dan Level wajib dipilih'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final namaJabatan = _namaController.text.trim();
      if (_isEdit) {
        final id = _parseId(widget.jabatan!['id_jabatan']);
        if (id == null) throw Exception('Invalid id');
        final res = await _service.update(
          id,
          namaJabatan: namaJabatan,
          idAtasan: _idAtasan,
          idDivisi: _idDivisi!,
          idSubDivisi: _idSubDivisi!,
          idLevel: _idLevel!,
        );
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Jabatan berhasil diupdate'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            _showValidationErrors(res);
          }
        }
      } else {
        final res = await _service.create(
          namaJabatan: namaJabatan,
          idAtasan: _idAtasan,
          idDivisi: _idDivisi!,
          idSubDivisi: _idSubDivisi!,
          idLevel: _idLevel!,
        );
        if (mounted) {
          setState(() => _isSaving = false);
          if (res != null && res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Jabatan berhasil ditambahkan'), backgroundColor: Colors.green),
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
      title: _isEdit ? 'Edit Jabatan' : 'Tambah Jabatan',
      showDrawer: false,
      body: _isLoadingDropdown
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_divisis.isEmpty && _levels.isEmpty && !_isLoadingDropdown) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data dropdown kosong. Pastikan sudah ada data Divisi, Sub Divisi, dan Data Level (menu Master Data di web/app).',
                            style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _loadCreateData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Muat ulang data'),
                            style: FilledButton.styleFrom(backgroundColor: _blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _namaController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Jabatan',
                              hintText: 'Nama jabatan',
                              border: OutlineInputBorder(),
                            ),
                            maxLength: 100,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Nama jabatan wajib diisi';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            value: _idAtasan,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Atasan (Opsional)',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('-- Tidak ada atasan --', overflow: TextOverflow.ellipsis)),
                              ..._jabatans
                                  .where((j) => _isEdit && _parseId(j['id_jabatan']) == _parseId(widget.jabatan!['id_jabatan']) ? false : true)
                                  .map((j) {
                                final id = _parseId(j['id_jabatan']);
                                final name = (j['nama_jabatan'] ?? '').toString();
                                return DropdownMenuItem<int?>(value: id, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1));
                              }),
                            ],
                            onChanged: (v) => setState(() => _idAtasan = v),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            value: _idDivisi,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Divisi',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Pilih Divisi', overflow: TextOverflow.ellipsis)),
                              ..._divisis.map((d) {
                                final id = _parseId(d['id']);
                                final name = (d['nama_divisi'] ?? '').toString();
                                return DropdownMenuItem<int?>(value: id, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1));
                              }),
                            ],
                            validator: (v) => v == null ? 'Divisi wajib dipilih' : null,
                            onChanged: (v) => setState(() {
                              _idDivisi = v;
                              _idSubDivisi = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            value: _idSubDivisi,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sub Divisi',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Pilih Sub Divisi', overflow: TextOverflow.ellipsis)),
                              ..._subDivisis
                                  .where((s) {
                                    final sid = _parseId(s['id_divisi']);
                                    if (sid == null) return true;
                                    return _idDivisi == null || sid == _idDivisi;
                                  })
                                  .map((s) {
                                final id = _parseId(s['id']);
                                final name = (s['nama_sub_divisi'] ?? '').toString();
                                return DropdownMenuItem<int?>(value: id, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1));
                              }),
                            ],
                            validator: (v) => v == null ? 'Sub Divisi wajib dipilih' : null,
                            onChanged: (v) => setState(() => _idSubDivisi = v),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            value: _idLevel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Level',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Pilih Level', overflow: TextOverflow.ellipsis)),
                              ..._levels.map((l) {
                                final id = _parseId(l['id']);
                                final name = (l['nama_level'] ?? '').toString();
                                return DropdownMenuItem<int?>(value: id, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1));
                              }),
                            ],
                            validator: (v) => v == null ? 'Level wajib dipilih' : null,
                            onChanged: (v) => setState(() => _idLevel = v),
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
