import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/marketing_visit_checklist_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class _MvcRowEdit {
  final int? dbId;
  final int no;
  final String category;
  final String checklistPoint;
  bool checked;
  final TextEditingController actualCtrl;
  final TextEditingController actionCtrl;
  final TextEditingController remarksCtrl;
  final List<String> existingPhotoUrls;
  final List<XFile> newPhotos;

  _MvcRowEdit({
    this.dbId,
    required this.no,
    required this.category,
    required this.checklistPoint,
    required this.checked,
    required this.actualCtrl,
    required this.actionCtrl,
    required this.remarksCtrl,
    List<String>? existingPhotoUrls,
    List<XFile>? newPhotos,
  })  : existingPhotoUrls = existingPhotoUrls ?? [],
        newPhotos = newPhotos ?? [];

  static _MvcRowEdit fromTemplateRow(List<dynamic> row) {
    final no = row.isNotEmpty ? int.tryParse('${row[0]}') ?? 0 : 0;
    final cat = row.length > 1 ? '${row[1]}' : '';
    final pt = row.length > 2 ? '${row[2]}' : '';
    return _MvcRowEdit(
      no: no,
      category: cat,
      checklistPoint: pt,
      checked: false,
      actualCtrl: TextEditingController(),
      actionCtrl: TextEditingController(),
      remarksCtrl: TextEditingController(),
    );
  }

  static _MvcRowEdit fromApiItem(Map<String, dynamic> it) {
    final urls = <String>[];
    final ph = it['photos'];
    if (ph is List) {
      for (final p in ph) {
        if (p is Map && p['url'] != null) urls.add(p['url'].toString());
      }
    }
    final ck = it['checked'];
    final checked = ck == true || ck == 1 || ck == '1';
    return _MvcRowEdit(
      dbId: int.tryParse('${it['id']}'),
      no: int.tryParse('${it['no']}') ?? 0,
      category: '${it['category'] ?? ''}',
      checklistPoint: '${it['checklist_point'] ?? ''}',
      checked: checked,
      actualCtrl: TextEditingController(text: '${it['actual_condition'] ?? ''}'),
      actionCtrl: TextEditingController(text: '${it['action'] ?? ''}'),
      remarksCtrl: TextEditingController(text: '${it['remarks'] ?? ''}'),
      existingPhotoUrls: urls,
    );
  }

  void dispose() {
    actualCtrl.dispose();
    actionCtrl.dispose();
    remarksCtrl.dispose();
  }
}

class MarketingVisitChecklistFormScreen extends StatefulWidget {
  final int? checklistId;

  const MarketingVisitChecklistFormScreen({super.key, this.checklistId});

  @override
  State<MarketingVisitChecklistFormScreen> createState() => _MarketingVisitChecklistFormScreenState();
}

class _MarketingVisitChecklistFormScreenState extends State<MarketingVisitChecklistFormScreen> {
  static const Color _primary = Color(0xFF6366F1);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);

  final _service = MarketingVisitChecklistService();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _outlets = [];
  String _userDisplayName = '-';
  int? _outletId;
  DateTime _visitDate = DateTime.now();

  List<_MvcRowEdit> _rows = [];

  bool get _isEdit => widget.checklistId != null;

  List<List<dynamic>> _parseTemplate(dynamic raw) {
    if (raw is! List) return [];
    final out = <List<dynamic>>[];
    for (final e in raw) {
      if (e is List && e.length >= 3) out.add(e);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isEdit) {
      final detail = await _service.fetchDetail(widget.checklistId!);
      if (!mounted) return;
      if (detail['success'] != true) {
        setState(() {
          _loading = false;
          _error = detail['message']?.toString() ?? 'Gagal memuat.';
        });
        return;
      }
      final outletsRaw = detail['outlets'];
      _outlets =
          (outletsRaw is List) ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];

      final cl = detail['checklist'];
      if (cl is Map<String, dynamic>) {
        final m = Map<String, dynamic>.from(cl);
        _userDisplayName = m['user_name']?.toString() ?? '-';
        _outletId = int.tryParse('${m['outlet_id']}');
        final vd = m['visit_date']?.toString();
        if (vd != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(vd)) {
          final p = vd.split('-');
          _visitDate = DateTime(int.tryParse(p[0]) ?? DateTime.now().year, int.tryParse(p[1]) ?? 1,
              int.tryParse(p[2]) ?? 1);
        }
        final itemsRaw = m['items'];
        final items = (itemsRaw is List)
            ? itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        for (final old in _rows) {
          old.dispose();
        }
        _rows = items.map((e) => _MvcRowEdit.fromApiItem(e)).toList();
      }
      setState(() => _loading = false);
      return;
    }

    final cd = await _service.fetchCreateData();
    if (!mounted) return;
    if (cd['success'] != true) {
      setState(() {
        _loading = false;
        _error = cd['message']?.toString() ?? 'Gagal memuat template.';
      });
      return;
    }
    final outletsRaw = cd['outlets'];
    _outlets = (outletsRaw is List) ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
    _userDisplayName = cd['user_name']?.toString() ?? '-';

    final templateRows = _parseTemplate(cd['template']);
    for (final old in _rows) {
      old.dispose();
    }
    _rows = templateRows.map(_MvcRowEdit.fromTemplateRow).toList();

    setState(() => _loading = false);
  }

  Future<void> _pickVisitDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) setState(() => _visitDate = d);
  }

  Future<void> _pickGallery(int rowIdx) async {
    final list = await _picker.pickMultiImage(imageQuality: 85);
    if (list.isEmpty) return;
    setState(() => _rows[rowIdx].newPhotos.addAll(list));
  }

  Future<void> _pickCamera(int rowIdx) async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;
    setState(() => _rows[rowIdx].newPhotos.add(x));
  }

  void _removeNewPhoto(int rowIdx, int photoIdx) {
    setState(() => _rows[rowIdx].newPhotos.removeAt(photoIdx));
  }

  Future<void> _submit() async {
    if (_outletId == null || _outletId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isEdit ? 'Update checklist?' : 'Simpan checklist?'),
        content: const Text('Pastikan data sudah benar sebelum menyimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);

    final visitStr =
        '${_visitDate.year}-${_visitDate.month.toString().padLeft(2, '0')}-${_visitDate.day.toString().padLeft(2, '0')}';

    final itemsPayload = _rows
        .map((r) => <String, dynamic>{
              if (r.dbId != null) 'id': r.dbId,
              'no': r.no,
              'category': r.category,
              'checklist_point': r.checklistPoint,
              'checked': r.checked,
              'actual_condition': r.actualCtrl.text.trim(),
              'action': r.actionCtrl.text.trim(),
              'remarks': r.remarksCtrl.text.trim(),
            })
        .toList();

    final photosPerIndex = _rows.map((r) => List<XFile>.from(r.newPhotos)).toList();

    final res = await _service.submitMultipart(
      isEdit: _isEdit,
      checklistId: widget.checklistId,
      outletId: _outletId!,
      visitDateYmd: visitStr,
      itemsPayload: itemsPayload,
      photosPerIndex: photosPerIndex,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Tersimpan.')));
      Navigator.pop(context);
    } else {
      final msg = res['message']?.toString() ?? 'Gagal menyimpan.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  bool _firstCat(int i) {
    if (i == 0) return true;
    return _rows[i].category != _rows[i - 1].category;
  }

  InputDecoration _softFieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _slate500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Checklist' : 'Tambah Checklist',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 36, color: _primary))
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Material(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFFEF2F2),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      _buildMetaCard(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(width: 4, height: 18, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 10),
                          const Text(
                            'Checklist kunjungan',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_rows.length} poin · isi sesuai kondisi outlet',
                        style: TextStyle(fontSize: 12, color: _slate500.withValues(alpha: 0.95)),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(_rows.length, _buildPointCard),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
                _buildBottomActions(),
              ],
            ),
    );
  }

  Widget _buildMetaCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description_rounded, color: _primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Informasi kunjungan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _slate900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Outlet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slate600.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                hint: const Text('Pilih outlet', style: TextStyle(color: Color(0xFF94A3B8))),
                value: _outletId,
                icon: const Icon(Icons.expand_more_rounded, color: _primary),
                borderRadius: BorderRadius.circular(12),
                items: _outlets.expand((o) {
                  final oid = int.tryParse('${o['id']}');
                  if (oid == null) return const Iterable<DropdownMenuItem<int?>>.empty();
                  return [
                    DropdownMenuItem<int?>(
                      value: oid,
                      child: Text(o['name']?.toString() ?? '-'),
                    ),
                  ];
                }).toList(),
                onChanged: (v) => setState(() => _outletId = v),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Tanggal kunjungan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slate600.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _pickVisitDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: _primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_visitDate),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: _slate900),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('User input', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slate600.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(child: Text(_userDisplayName, style: const TextStyle(fontWeight: FontWeight.w600, color: _slate900))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointCard(int i) {
    final r = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_firstCat(i))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primary.withValues(alpha: 0.14), _primary.withValues(alpha: 0.06)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r.category,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _primary.withValues(alpha: 0.14),
                    child: Text(
                      '${r.no}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.checklistPoint,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.35, color: _slate900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  checkboxTheme: CheckboxThemeData(
                    checkColor: WidgetStateProperty.all(Colors.white),
                    fillColor: WidgetStateProperty.resolveWith((s) {
                      if (s.contains(WidgetState.selected)) return _primary;
                      return const Color(0xFFE2E8F0);
                    }),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sesuai', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  value: r.checked,
                  onChanged: (v) => setState(() => r.checked = v ?? false),
                ),
              ),
              TextField(controller: r.actualCtrl, maxLines: 2, decoration: _softFieldDecoration('Actual condition')),
              const SizedBox(height: 10),
              TextField(controller: r.actionCtrl, maxLines: 2, decoration: _softFieldDecoration('Action')),
              const SizedBox(height: 10),
              TextField(controller: r.remarksCtrl, maxLines: 2, decoration: _softFieldDecoration('Remarks')),
              const SizedBox(height: 14),
              Text(
                'Foto pendukung',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _slate600.withValues(alpha: 0.95)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _pickGallery(i),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary.withValues(alpha: 0.12),
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text('Upload'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _pickCamera(i),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFECFEFF),
                      foregroundColor: const Color(0xFF0E7490),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_camera_rounded, size: 20),
                    label: const Text('Kamera'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...r.existingPhotoUrls.map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(width: 56, height: 56, color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined, size: 22),
                          ),
                        ),
                      )),
                  ...r.newPhotos.asMap().entries.map((e) {
                    final idx = e.key;
                    final file = e.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(file.path), width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Material(
                            color: const Color(0xFFDC2626),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _removeNewPhoto(i, idx),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _slate600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
