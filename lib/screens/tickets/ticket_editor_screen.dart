import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ticket_service.dart';
import '../../utils/ticket_status.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class TicketEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialTicket;

  const TicketEditorScreen({super.key, this.initialTicket});

  @override
  State<TicketEditorScreen> createState() => _TicketEditorScreenState();
}

class _TicketEditorScreenState extends State<TicketEditorScreen> {
  final TicketService _svc = TicketService();
  final ImagePicker _imagePicker = ImagePicker();
  final _title = TextEditingController();
  final _desc = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Map<String, dynamic>? _opts;
  int? _categoryId;
  int? _priorityId;
  int? _statusId;
  int? _divisiId;
  int? _outletId;
  String? _initialStatusSlug;
  final List<File> _newFiles = [];
  final List<File> _closeEvidenceFiles = [];
  final _closeNote = TextEditingController();
  final List<Map<String, dynamic>> _existingTickets = [];
  int _duplicateCount = 0;
  bool _loadingExistingTickets = false;
  Timer? _duplicateDebounce;

  bool get _isEdit => widget.initialTicket != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(_scheduleFetchExistingTickets);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final r = await _svc.getFormOptions();
    if (!mounted) return;
    if (r['success'] != true) {
      setState(() {
        _loading = false;
        _error = r['message']?.toString() ?? 'Gagal memuat opsi';
      });
      return;
    }
    _opts = r;
    final t = widget.initialTicket;
    if (t != null) {
      _title.text = t['title']?.toString() ?? '';
      _desc.text = t['description']?.toString() ?? '';
      _categoryId = (t['category_id'] as num?)?.toInt() ??
          (t['category'] is Map ? (t['category']['id'] as num?)?.toInt() : null);
      _priorityId = (t['priority_id'] as num?)?.toInt() ??
          (t['priority'] is Map ? (t['priority']['id'] as num?)?.toInt() : null);
      _statusId = (t['status_id'] as num?)?.toInt() ??
          (t['status'] is Map ? (t['status']['id'] as num?)?.toInt() : null);
      if (t['status'] is Map) {
        _initialStatusSlug = normalizeTicketStatusSlug(
          (t['status'] as Map)['slug']?.toString(),
        );
      }
      _divisiId = (t['divisi_id'] as num?)?.toInt() ??
          (t['divisi'] is Map ? (t['divisi']['id'] as num?)?.toInt() : null);
      final oid = t['outlet_id'];
      if (oid != null) {
        _outletId = oid is int ? oid : int.tryParse(oid.toString());
      } else if (t['outlet'] is Map) {
        final om = t['outlet'] as Map;
        _outletId = (om['id_outlet'] as num?)?.toInt() ?? (om['id'] as num?)?.toInt();
      }
    }
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    _duplicateDebounce?.cancel();
    _title.removeListener(_scheduleFetchExistingTickets);
    _title.dispose();
    _desc.dispose();
    _closeNote.dispose();
    super.dispose();
  }

  void _scheduleFetchExistingTickets() {
    if (_isEdit) return;
    _duplicateDebounce?.cancel();
    _duplicateDebounce = Timer(const Duration(milliseconds: 350), _fetchExistingTickets);
  }

  Future<void> _fetchExistingTickets() async {
    if (_isEdit || _outletId == null) {
      if (mounted) {
        setState(() {
          _existingTickets.clear();
          _duplicateCount = 0;
          _loadingExistingTickets = false;
        });
      }
      return;
    }

    setState(() => _loadingExistingTickets = true);
    final res = await _svc.getTicketsByOutlet(
      outletId: _outletId!,
      title: _title.text.trim(),
      q: _title.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _loadingExistingTickets = false;
      _existingTickets
        ..clear()
        ..addAll((res['tickets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>());
      _duplicateCount = (res['duplicate_count'] as num?)?.toInt() ?? 0;
    });
  }

  bool get _isClosingTicket {
    if (!_isEdit || _statusId == null || _opts == null) return false;
    if (_initialStatusSlug == 'closed') return false;
    for (final s in selectableTicketStatuses(_opts!['statuses'] as List<dynamic>)) {
      final m = s as Map<String, dynamic>;
      if ((m['id'] as num).toInt() == _statusId) {
        return normalizeTicketStatusSlug(m['slug']?.toString()) == 'closed';
      }
    }
    return false;
  }

  Future<void> _pickCloseEvidence() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    setState(() {
      for (final f in res.files) {
        final p = f.path;
        if (p != null && _closeEvidenceFiles.length < 5) {
          _closeEvidenceFiles.add(File(p));
        }
      }
    });
  }

  Future<void> _captureCloseEvidence() async {
    try {
      final x = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 82);
      if (x == null || !mounted) return;
      setState(() {
        if (_closeEvidenceFiles.length < 5) _closeEvidenceFiles.add(File(x.path));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    setState(() {
      for (final f in res.files) {
        final p = f.path;
        if (p != null) _newFiles.add(File(p));
      }
    });
  }

  Future<void> _captureFromCamera() async {
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (x == null || !mounted) return;
      setState(() => _newFiles.add(File(x.path)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final list = await _imagePicker.pickMultiImage(imageQuality: 82);
      if (list.isEmpty || !mounted) return;
      setState(() {
        for (final x in list) {
          _newFiles.add(File(x.path));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Galeri: ${e.toString()}')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _newFiles.length) return;
    setState(() => _newFiles.removeAt(index));
  }

  static bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.gif');
  }

  static String _fileName(String path) {
    final i = path.replaceAll(r'\', '/').lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  Future<void> _save() async {
    if (_categoryId == null || _priorityId == null || _divisiId == null || _outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi kategori, prioritas, divisi, dan outlet')),
      );
      return;
    }
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan deskripsi wajib')));
      return;
    }
    if (!_isEdit) {
      final duplicates = _existingTickets.where((e) => e['is_same_title'] == true).toList();
      if (duplicates.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Judul terdeteksi duplikat'),
            content: Text(
              'Ditemukan ${duplicates.length} ticket aktif dengan judul sama di outlet ini.\nTetap lanjut simpan?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjut Simpan')),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }
    if (_isEdit && _statusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status wajib')));
      return;
    }

    setState(() => _saving = true);
    Map<String, dynamic> res;
    if (_isEdit) {
      res = await _svc.updateTicket(
        id: (widget.initialTicket!['id'] as num).toInt(),
        title: _title.text.trim(),
        description: _desc.text.trim(),
        categoryId: _categoryId!,
        priorityId: _priorityId!,
        statusId: _statusId!,
        divisiId: _divisiId!,
        outletId: _outletId!,
        closeNote: _isClosingTicket && _closeNote.text.trim().isNotEmpty
            ? _closeNote.text.trim()
            : null,
        closeEvidenceFiles: _isClosingTicket && _closeEvidenceFiles.isNotEmpty
            ? _closeEvidenceFiles
            : null,
      );
    } else {
      res = await _svc.createTicket(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        categoryId: _categoryId!,
        priorityId: _priorityId!,
        divisiId: _divisiId!,
        outletId: _outletId!,
        attachmentFiles: _newFiles.isEmpty ? null : _newFiles,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')),
      );
      Navigator.pop(context, true);
    } else {
      final msg = res['message']?.toString() ?? 'Gagal menyimpan';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit ticket' : 'Ticket baru',
      showDrawer: false,
      actions: [
        if (!_loading)
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                  )
                : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
          ),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF4F46E5), useLogo: false))
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dropdown<int>(
                        label: 'Outlet',
                        value: _outletId,
                        items: (_opts!['outlets'] as List<dynamic>).map((e) {
                          final m = e as Map<String, dynamic>;
                          final id = (m['id_outlet'] ?? m['id']) as num;
                          return MapEntry(id.toInt(), m['nama_outlet']?.toString() ?? '');
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _outletId = v);
                          _scheduleFetchExistingTickets();
                        },
                      ),
                      if (!_isEdit && _outletId != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                            color: const Color(0xFFEFF6FF),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Ticket aktif untuk outlet ini',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                  if (_duplicateCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$_duplicateCount judul sama',
                                        style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Saat isi judul, daftar otomatis tersaring untuk cek duplikat.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                              ),
                              const SizedBox(height: 8),
                              if (_loadingExistingTickets)
                                const Text('Memuat ticket...', style: TextStyle(fontSize: 12))
                              else if (_existingTickets.isEmpty)
                                const Text('Belum ada ticket aktif yang cocok.', style: TextStyle(fontSize: 12))
                              else
                                SizedBox(
                                  height: 180,
                                  child: ListView.separated(
                                    itemCount: _existingTickets.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final t = _existingTickets[i];
                                      final same = t['is_same_title'] == true;
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          t['title']?.toString() ?? '-',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: same ? FontWeight.w700 : FontWeight.w500,
                                            color: same ? const Color(0xFFB91C1C) : null,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${t['ticket_number'] ?? '-'} · ${t['status'] is Map ? t['status']['name'] ?? '-' : '-'}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      TextField(
                        controller: _title,
                        decoration: _dec('Judul'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _desc,
                        decoration: _dec('Deskripsi'),
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      _dropdown<int>(
                        label: 'Kategori',
                        value: _categoryId,
                        items: (_opts!['categories'] as List<dynamic>)
                            .map((e) => MapEntry((e['id'] as num).toInt(), e['name']?.toString() ?? ''))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      _dropdown<int>(
                        label: 'Prioritas',
                        value: _priorityId,
                        items: (_opts!['priorities'] as List<dynamic>)
                            .map((e) => MapEntry((e['id'] as num).toInt(), e['name']?.toString() ?? ''))
                            .toList(),
                        onChanged: (v) => setState(() => _priorityId = v),
                      ),
                      if (_isEdit)
                        _dropdown<int>(
                          label: 'Status',
                          value: _statusId,
                          items: selectableTicketStatuses(_opts!['statuses'] as List<dynamic>)
                              .map((e) => MapEntry((e['id'] as num).toInt(), e['name']?.toString() ?? ''))
                              .toList(),
                          onChanged: (v) => setState(() => _statusId = v),
                        ),
                      if (_isClosingTicket) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Evidence penutupan (opsional)',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _closeNote,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Catatan penutupan',
                                  hintText: 'Contoh: Lampu sudah diganti...',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _closeEvidenceFiles.length >= 5 ? null : _pickCloseEvidence,
                                    icon: const Icon(Icons.upload_file, size: 18),
                                    label: const Text('File'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _closeEvidenceFiles.length >= 5 ? null : _captureCloseEvidence,
                                    icon: const Icon(Icons.photo_camera, size: 18),
                                    label: const Text('Kamera'),
                                  ),
                                ],
                              ),
                              if (_closeEvidenceFiles.isNotEmpty)
                                ..._closeEvidenceFiles.asMap().entries.map((e) {
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      _fileName(e.value.path),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(() => _closeEvidenceFiles.removeAt(e.key)),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                      _dropdown<int>(
                        label: 'Divisi',
                        value: _divisiId,
                        items: (_opts!['divisions'] as List<dynamic>)
                            .map((e) => MapEntry((e['id'] as num).toInt(), e['nama_divisi']?.toString() ?? ''))
                            .toList(),
                        onChanged: (v) => setState(() => _divisiId = v),
                      ),
                      if (!_isEdit) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Lampiran (opsional)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _captureFromCamera,
                              icon: const Icon(Icons.photo_camera_rounded, size: 20),
                              label: const Text('Kamera'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickFromGallery,
                              icon: const Icon(Icons.photo_library_rounded, size: 20),
                              label: const Text('Galeri'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.attach_file_rounded, size: 20),
                              label: const Text('File'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ],
                        ),
                        if (_newFiles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${_newFiles.length} lampiran — ketuk × untuk hapus',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _newFiles.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final file = _newFiles[i];
                                final path = file.path;
                                final img = _isImagePath(path);
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        color: const Color(0xFFF8FAFC),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: img
                                          ? Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _filePlaceholder(path),
                                            )
                                          : _filePlaceholder(path),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: Material(
                                        color: Colors.red.shade600,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          onTap: () => _removeAttachment(i),
                                          customBorder: const CircleBorder(),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _filePlaceholder(String path) {
    final name = _fileName(path);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file_rounded, size: 28, color: Colors.grey.shade500),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<MapEntry<T, String>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        selectedItemBuilder: (context) => items
            .map(
              (e) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        items: items
            .map(
              (e) => DropdownMenuItem<T>(
                value: e.key,
                child: Text(
                  e.value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
