import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/announcement_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class AnnouncementFormScreen extends StatefulWidget {
  final int? announcementId;

  const AnnouncementFormScreen({super.key, this.announcementId});

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  final AnnouncementService _service = AnnouncementService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  PlatformFile? _imageFile;
  List<PlatformFile> _files = [];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _jabatans = [];
  List<Map<String, dynamic>> _divisis = [];
  List<Map<String, dynamic>> _levels = [];
  List<Map<String, dynamic>> _outlets = [];

  final Map<String, Set<int>> _selectedByType = {
    'user': <int>{},
    'jabatan': <int>{},
    'divisi': <int>{},
    'level': <int>{},
    'outlet': <int>{},
  };

  bool get _isEdit => widget.announcementId != null;

  static const List<String> _targetTypes = ['user', 'jabatan', 'divisi', 'level', 'outlet'];
  static const Map<String, String> _targetLabels = {
    'user': 'User',
    'jabatan': 'Jabatan',
    'divisi': 'Divisi',
    'level': 'Level',
    'outlet': 'Outlet',
  };
  static const Map<String, IconData> _targetIcons = {
    'user': Icons.person_outline_rounded,
    'jabatan': Icons.badge_outlined,
    'divisi': Icons.apartment_rounded,
    'level': Icons.layers_outlined,
    'outlet': Icons.storefront_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final createData = await _service.getCreateData();
    if (!mounted) return;
    if (createData['success'] != true) {
      setState(() {
        _isLoading = false;
        _error = createData['message']?.toString() ?? 'Gagal memuat master data';
      });
      return;
    }

    _users = ((createData['users'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _jabatans = ((createData['jabatans'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _divisis = ((createData['divisis'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _levels = ((createData['levels'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _outlets = ((createData['outlets'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (_isEdit) {
      final detail = await _service.getAnnouncement(widget.announcementId!);
      if (!mounted) return;
      if (detail['success'] != true) {
        setState(() {
          _isLoading = false;
          _error = detail['message']?.toString() ?? 'Gagal memuat detail announcement';
        });
        return;
      }

      final ann = detail['announcement'] is Map
          ? Map<String, dynamic>.from(detail['announcement'] as Map)
          : <String, dynamic>{};
      _titleController.text = ann['title']?.toString() ?? '';
      _contentController.text = ann['content']?.toString() ?? '';
      final targets = ((ann['targets'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final target in targets) {
        final type = target['target_type']?.toString() ?? '';
        final id = _toInt(target['target_id']);
        if (_selectedByType.containsKey(type) && id > 0) {
          _selectedByType[type]!.add(id);
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    setState(() => _imageFile = result.files.first);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _files = result.files);
  }

  List<Map<String, dynamic>> _flattenTargets() {
    final list = <Map<String, dynamic>>[];
    _selectedByType.forEach((type, ids) {
      for (final id in ids) {
        list.add({'type': type, 'id': id});
      }
    });
    return list;
  }

  String _displayName(String type, int id) {
    if (type == 'user') {
      return _users.firstWhere((e) => _toInt(e['id']) == id, orElse: () => {'nama_lengkap': '$id'})['nama_lengkap']
          .toString();
    }
    if (type == 'jabatan') {
      return _jabatans.firstWhere((e) => _toInt(e['id_jabatan']) == id, orElse: () => {'nama_jabatan': '$id'})['nama_jabatan']
          .toString();
    }
    if (type == 'divisi') {
      return _divisis.firstWhere((e) => _toInt(e['id']) == id, orElse: () => {'nama_divisi': '$id'})['nama_divisi'].toString();
    }
    if (type == 'level') {
      return _levels.firstWhere((e) => _toInt(e['id']) == id, orElse: () => {'nama_level': '$id'})['nama_level'].toString();
    }
    if (type == 'outlet') {
      return _outlets
          .firstWhere((e) => _toInt(e['id_outlet']) == id, orElse: () => {'nama_outlet': '$id'})['nama_outlet']
          .toString();
    }
    return '$id';
  }

  List<Map<String, dynamic>> _dataByType(String type) {
    if (type == 'user') return _users;
    if (type == 'jabatan') return _jabatans;
    if (type == 'divisi') return _divisis;
    if (type == 'level') return _levels;
    if (type == 'outlet') return _outlets;
    return const [];
  }

  int _idByType(String type, Map<String, dynamic> row) {
    if (type == 'user') return _toInt(row['id']);
    if (type == 'jabatan') return _toInt(row['id_jabatan']);
    if (type == 'divisi') return _toInt(row['id']);
    if (type == 'level') return _toInt(row['id']);
    if (type == 'outlet') return _toInt(row['id_outlet']);
    return 0;
  }

  String _nameByType(String type, Map<String, dynamic> row) {
    if (type == 'user') return row['nama_lengkap']?.toString() ?? '-';
    if (type == 'jabatan') return row['nama_jabatan']?.toString() ?? '-';
    if (type == 'divisi') return row['nama_divisi']?.toString() ?? '-';
    if (type == 'level') return row['nama_level']?.toString() ?? '-';
    if (type == 'outlet') return row['nama_outlet']?.toString() ?? '-';
    return '-';
  }

  Future<void> _selectTargetType(String type) async {
    final tempSelected = Set<int>.from(_selectedByType[type] ?? <int>{});
    final rows = _dataByType(type);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setLocal) {
            final filteredRows = rows.where((row) {
              if (query.isEmpty) return true;
              final name = _nameByType(type, row).toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();
            return AlertDialog(
              title: Text('Pilih ${type[0].toUpperCase()}${type.substring(1)}'),
              content: SizedBox(
                width: 380,
                height: 420,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setLocal(() {
                                for (final row in filteredRows) {
                                  final id = _idByType(type, row);
                                  if (id > 0) tempSelected.add(id);
                                }
                              });
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Pilih semua'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setLocal(() {
                                if (query.isEmpty) {
                                  tempSelected.clear();
                                } else {
                                  for (final row in filteredRows) {
                                    final id = _idByType(type, row);
                                    tempSelected.remove(id);
                                  }
                                }
                              });
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Clear semua'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari ${_targetLabels[type] ?? type}...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (value) => setLocal(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredRows.isEmpty
                          ? const Center(
                              child: Text(
                                'Data tidak ditemukan',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredRows.length,
                              itemBuilder: (context, index) {
                                final row = filteredRows[index];
                                final id = _idByType(type, row);
                                final name = _nameByType(type, row);
                                final selected = tempSelected.contains(id);
                                return CheckboxListTile(
                                  dense: true,
                                  value: selected,
                                  title: Text(name),
                                  onChanged: (v) {
                                    setLocal(() {
                                      if (v == true) {
                                        tempSelected.add(id);
                                      } else {
                                        tempSelected.remove(id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                FilledButton(onPressed: () => Navigator.pop(ctx, tempSelected), child: const Text('Simpan')),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    setState(() => _selectedByType[type] = result);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final targets = _flattenTargets();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul harus diisi')));
      return;
    }
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal pilih 1 target')));
      return;
    }

    setState(() => _isSaving = true);
    Map<String, dynamic> result;
    if (_isEdit) {
      result = await _service.updateAnnouncement(
        id: widget.announcementId!,
        title: title,
        content: content,
        targets: targets,
        image: _imageFile,
        files: _files,
      );
    } else {
      result = await _service.createAnnouncement(
        title: title,
        content: content,
        targets: targets,
        image: _imageFile,
        files: _files,
      );
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil disimpan')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal menyimpan'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTargets = _selectedByType.values.fold<int>(0, (p, e) => p + e.length);
    return AppScaffold(
      title: _isEdit ? 'Edit Announcement' : 'Buat Announcement',
      showDrawer: false,
      actions: [
        TextButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade300),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isEdit ? 'Edit Announcement' : 'Buat Announcement Baru',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contentController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Isi konten',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Header Image', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _imageFile?.name ?? 'Belum ada file',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.image_outlined),
                                  label: const Text('Pilih'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lampiran Files', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.attach_file_rounded),
                              label: const Text('Pilih file'),
                            ),
                            const SizedBox(height: 8),
                            ..._files.map((f) => Text(
                                  '- ${f.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            if (totalTargets > 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Total target dipilih: $totalTargets',
                                  style: const TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final type in _targetTypes)
                                  FilledButton.tonalIcon(
                                    onPressed: () => _selectTargetType(type),
                                    icon: Icon(_targetIcons[type], size: 18),
                                    label: Text('${_targetLabels[type]} (${_selectedByType[type]!.length})'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedByType.entries
                                  .expand((entry) => entry.value.map((id) => {'type': entry.key, 'id': id}))
                                  .map((item) {
                                final type = item['type']!.toString();
                                final id = item['id'] as int;
                                final label = '${_targetLabels[type]}: ${_displayName(type, id)}';
                                return Chip(
                                  label: Text(label, overflow: TextOverflow.ellipsis),
                                  deleteIcon: const Icon(Icons.close_rounded),
                                  onDeleted: () {
                                    setState(() => _selectedByType[type]!.remove(id));
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Announcement'),
                    ),
                  ],
                ),
    );
  }
}

