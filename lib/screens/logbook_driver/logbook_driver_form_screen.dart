import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/logbook_driver_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

String _resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${AuthService.storageUrl}$url';
  return '${AuthService.storageUrl}/storage/$url';
}

class _LogLine {
  int? id;
  TimeOfDay logTime;
  final TextEditingController descriptionCtrl;
  String? existingPhotoUrl;
  XFile? newPhoto;
  bool keepPhoto;

  _LogLine({
    this.id,
    required this.logTime,
    required this.descriptionCtrl,
    this.existingPhotoUrl,
    this.keepPhoto = false,
  });

  void dispose() => descriptionCtrl.dispose();
}

class LogbookDriverFormScreen extends StatefulWidget {
  final int? recordId;

  const LogbookDriverFormScreen({super.key, this.recordId});

  @override
  State<LogbookDriverFormScreen> createState() => _LogbookDriverFormScreenState();
}

class _LogbookDriverFormScreenState extends State<LogbookDriverFormScreen> {
  static const Color _primary = Color(0xFF0891B2);
  static const Color _slate500 = Color(0xFF64748B);

  final _service = LogbookDriverService();
  final _picker = ImagePicker();
  final _notesCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _outlets = [];
  String _driverName = '-';
  DateTime _logDate = DateTime.now();
  int? _outletId;
  final List<_LogLine> _lines = [];

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  TimeOfDay _nowTime() {
    final n = TimeOfDay.now();
    return TimeOfDay(hour: n.hour, minute: n.minute);
  }

  TimeOfDay _parseTime(dynamic v) {
    final s = (v ?? '').toString();
    if (s.length >= 5) {
      final h = int.tryParse(s.substring(0, 2));
      final m = int.tryParse(s.substring(3, 5));
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return _nowTime();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _addLine() {
    setState(() {
      _lines.add(_LogLine(
        logTime: _nowTime(),
        descriptionCtrl: TextEditingController(),
      ));
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isEdit) {
      final detail = await _service.fetchDetail(widget.recordId!);
      if (!mounted) return;
      if (detail['success'] != true) {
        setState(() {
          _loading = false;
          _error = detail['message']?.toString() ?? 'Gagal memuat.';
        });
        return;
      }
      final outletsRaw = detail['outlets'];
      _outlets = (outletsRaw is List)
          ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      final data = detail['data'];
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        _driverName = m['driver_name']?.toString() ?? '-';
        _outletId = int.tryParse('${m['outlet_id']}');
        _notesCtrl.text = m['notes']?.toString() ?? '';
        final ld = m['log_date']?.toString();
        if (ld != null && ld.length >= 10) {
          try {
            _logDate = DateTime.parse(ld.substring(0, 10));
          } catch (_) {}
        }
        for (final old in _lines) {
          old.dispose();
        }
        _lines.clear();
        final items = m['items'];
        if (items is List && items.isNotEmpty) {
          for (final raw in items) {
            final it = Map<String, dynamic>.from(raw as Map);
            _lines.add(_LogLine(
              id: int.tryParse('${it['id']}'),
              logTime: _parseTime(it['log_time']),
              descriptionCtrl: TextEditingController(text: it['description']?.toString() ?? ''),
              existingPhotoUrl: _resolveMediaUrl(it['photo_url']?.toString()),
              keepPhoto: (it['photo_url'] ?? it['photo_path']) != null,
            ));
          }
        }
      }
    } else {
      final create = await _service.fetchCreateData();
      if (!mounted) return;
      if (create['success'] != true) {
        setState(() {
          _loading = false;
          _error = create['message']?.toString() ?? 'Gagal memuat form.';
        });
        return;
      }
      final data = create['data'];
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final outletsRaw = m['outlets'];
        _outlets = (outletsRaw is List)
            ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        final driver = m['driver'];
        if (driver is Map) {
          _driverName = driver['name']?.toString() ?? '-';
        }
        final ld = m['log_date']?.toString();
        if (ld != null && ld.length >= 10) {
          try {
            _logDate = DateTime.parse(ld.substring(0, 10));
          } catch (_) {}
        }
      }
    }

    if (_lines.isEmpty) _addLine();

    setState(() {
      _loading = false;
    });
  }

  Future<void> _pickPhoto(int index) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lines[index].newPhoto = picked;
      _lines[index].keepPhoto = true;
    });
  }

  Future<void> _pickGallery(int index) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lines[index].newPhoto = picked;
      _lines[index].keepPhoto = true;
    });
  }

  void _clearPhoto(int index) {
    setState(() {
      _lines[index].newPhoto = null;
      _lines[index].existingPhotoUrl = null;
      _lines[index].keepPhoto = false;
    });
  }

  Future<void> _pickLineTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _lines[index].logTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _lines[index].logTime = picked);
  }

  Future<void> _submit() async {
    if (_outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet terlebih dahulu.')),
      );
      return;
    }
    final hasDesc = _lines.any((l) => l.descriptionCtrl.text.trim().isNotEmpty);
    if (!hasDesc) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal satu baris log dengan keterangan.')),
      );
      return;
    }

    setState(() => _saving = true);
    final items = <Map<String, dynamic>>[];
    final photos = <XFile?>[];
    for (final l in _lines) {
      if (l.descriptionCtrl.text.trim().isEmpty && l.newPhoto == null && !l.keepPhoto) {
        continue;
      }
      items.add({
        'id': l.id,
        'log_time': _hhmm(l.logTime),
        'description': l.descriptionCtrl.text.trim(),
        'keep_photo': l.keepPhoto && l.newPhoto == null,
      });
      photos.add(l.newPhoto);
    }

    if (items.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal satu baris log wajib diisi.')),
      );
      return;
    }

    final res = await _service.submitMultipart(
      isEdit: _isEdit,
      recordId: widget.recordId,
      outletId: _outletId!,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      items: items,
      photos: photos,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Tersimpan')),
      );
      Navigator.pop(context, true);
    } else {
      final errors = res['errors'];
      String msg = res['message']?.toString() ?? 'Gagal menyimpan';
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) msg = first.first.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Widget _photoPreview(_LogLine line, int index) {
    Widget? child;
    if (line.newPhoto != null) {
      child = Image.file(File(line.newPhoto!.path), fit: BoxFit.cover);
    } else if (line.existingPhotoUrl != null && line.existingPhotoUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: line.existingPhotoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    if (child == null) return const SizedBox.shrink();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 96, height: 96, child: child),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () => _clearPhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Logbook' : 'Buat Logbook',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _bootstrap, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Driver', style: TextStyle(fontSize: 12, color: _slate500)),
                            Text(_driverName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 12),
                            const Text('Tanggal', style: TextStyle(fontSize: 12, color: _slate500)),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_logDate),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const Text('Otomatis — tidak bisa diubah',
                                style: TextStyle(fontSize: 11, color: _slate500)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _outletId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Outlet *',
                                border: OutlineInputBorder(),
                              ),
                              items: _outlets.map((o) {
                                final id = int.tryParse('${o['id_outlet']}');
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(o['nama_outlet']?.toString() ?? '-', overflow: TextOverflow.ellipsis),
                                );
                              }).where((e) => e.value != null).toList(),
                              onChanged: (v) => setState(() => _outletId = v),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Catatan (opsional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Baris Log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),
                    ...List.generate(_lines.length, (index) {
                      final line = _lines[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _primary.withOpacity(0.15),
                                    child: Text('${index + 1}',
                                        style: const TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  const Spacer(),
                                  if (_lines.length > 1)
                                    IconButton(
                                      onPressed: () => _removeLine(index),
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _pickLineTime(index),
                                icon: const Icon(Icons.access_time),
                                label: Text('Jam: ${_hhmm(line.logTime)}'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: line.descriptionCtrl,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Keterangan *',
                                  border: OutlineInputBorder(),
                                  hintText: 'Berangkat / sampai outlet / muat barang...',
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _photoPreview(line, index),
                                  if (line.newPhoto != null || (line.existingPhotoUrl?.isNotEmpty ?? false))
                                    const SizedBox(width: 10),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.tonalIcon(
                                          onPressed: () => _pickPhoto(index),
                                          icon: const Icon(Icons.photo_camera),
                                          label: const Text('Kamera'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _pickGallery(index),
                                          icon: const Icon(Icons.image),
                                          label: const Text('Galeri'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _primary,
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
    );
  }
}
