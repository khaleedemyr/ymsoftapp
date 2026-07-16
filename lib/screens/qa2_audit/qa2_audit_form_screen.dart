import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/purchase_requisition_service.dart';
import '../../services/qa2_audit_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'qa2_audit_media.dart';
import 'qa2_audit_ui.dart';
import 'qa2_audit_user_picker.dart';

class Qa2AuditFormScreen extends StatefulWidget {
  final int auditId;
  final bool capOnly;

  const Qa2AuditFormScreen({super.key, required this.auditId, this.capOnly = false});

  @override
  State<Qa2AuditFormScreen> createState() => _Qa2AuditFormScreenState();
}

class _Qa2AuditFormScreenState extends State<Qa2AuditFormScreen> {
  final _service = Qa2AuditService();
  final _prService = PurchaseRequisitionService();
  final _picker = ImagePicker();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  Timer? _draftDebounce;
  Timer? _auditeeDebounce;
  Timer? _capDebounce;
  Timer? _searchDebounce;

  String _searchQuery = '';
  final Set<String> _expandedSections = {};

  bool _loading = true;
  bool _savingDraft = false;
  bool _savingAuditees = false;
  bool _savingCap = false;
  bool _capSubmitting = false;
  bool _submitting = false;
  String? _error;
  String _lastSavedAt = '';
  String _auditeeLastSavedAt = '';
  String _capLastSavedAt = '';

  Map<String, dynamic> _audit = {};
  Map<String, dynamic> _permissions = {};
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _items = [];

  int? _outletId;
  final Set<int> _auditorIds = {};
  final Set<int> _auditeeIds = {};

  final Set<int> _uploadingItemMedia = {};
  final Set<int> _uploadingCapMedia = {};
  final Set<int> _uploadingCapItemIds = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<int, TextEditingController> _capActionControllers = {};

  List<Map<String, dynamic>> _capApprovers = [];
  List<Map<String, dynamic>> _availableApprovers = [];

  int? _currentUserId;
  bool _isAuditAuditee = false;
  late bool _viewCap;

  @override
  void initState() {
    super.initState();
    _viewCap = widget.capOnly;
    _load();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _auditeeDebounce?.cancel();
    _capDebounce?.cancel();
    _searchDebounce?.cancel();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    _commentControllers.clear();
    for (final c in _capActionControllers.values) {
      c.dispose();
    }
    _capActionControllers.clear();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _dateText(String? raw, {String pattern = 'dd MMM yyyy'}) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat(pattern, 'id_ID').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.fetchDetail(widget.auditId);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat data.';
      });
      return;
    }

    final audit = (res['audit'] is Map) ? Map<String, dynamic>.from(res['audit'] as Map) : <String, dynamic>{};
    final itemsRaw = audit['items'];
    final outletsRaw = res['outlets'];
    final usersRaw = res['users'];
    final permsRaw = res['permissions'];

    _audit = audit;
    _permissions = (permsRaw is Map) ? Map<String, dynamic>.from(permsRaw as Map) : {};
    _outlets = (outletsRaw is List)
        ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    _users =
        (usersRaw is List) ? usersRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    _items = (itemsRaw is List)
        ? itemsRaw.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            m['medias'] = (m['media'] is List)
                ? (m['media'] as List)
                    .whereType<Map>()
                    .map((x) => Map<String, dynamic>.from(x as Map))
                    .toList()
                : (m['medias'] is List)
                    ? (m['medias'] as List)
                        .whereType<Map>()
                        .map((x) => Map<String, dynamic>.from(x as Map))
                        .toList()
                    : <Map<String, dynamic>>[];
            m['new_files'] = <XFile>[];
            final capRaw = m['cap'];
            if (capRaw is Map) {
              m['cap'] = Map<String, dynamic>.from(capRaw);
              final capStatus = m['cap']['status']?.toString() ?? 'open';
              if (capStatus == 'in_progress') {
                m['cap']['status'] = 'progress';
              }
              m['cap']['medias'] = (m['cap']['media'] is List)
                  ? (m['cap']['media'] as List)
                      .whereType<Map>()
                      .map((x) => Map<String, dynamic>.from(x as Map))
                      .toList()
                  : (m['cap']['medias'] is List)
                      ? (m['cap']['medias'] as List)
                          .whereType<Map>()
                          .map((x) => Map<String, dynamic>.from(x as Map))
                          .toList()
                      : <Map<String, dynamic>>[];
            } else if ((m['result']?.toString() ?? '') == 'NC') {
              _ensureCapObject(m);
            }
            return m;
          }).toList()
        : <Map<String, dynamic>>[];

    _outletId = _parseInt(audit['outlet_id']);
    _notesCtrl.text = audit['notes']?.toString() ?? '';
    _auditorIds
      ..clear()
      ..addAll(
        (audit['auditor_ids'] is List)
            ? (audit['auditor_ids'] as List).map(_parseInt).whereType<int>()
            : _extractIds(audit['auditors']),
      );
    _auditeeIds
      ..clear()
      ..addAll(
        (audit['auditee_ids'] is List)
            ? (audit['auditee_ids'] as List).map(_parseInt).whereType<int>()
            : _extractIds(audit['auditees']),
      );

    final userData = await AuthService().getUserData();
    _currentUserId = _parseInt(userData?['id']);
    _isAuditAuditee = _currentUserId != null && _auditeeIds.contains(_currentUserId);

    for (final c in _commentControllers.values) {
      c.dispose();
    }
    _commentControllers.clear();
    for (final c in _capActionControllers.values) {
      c.dispose();
    }
    _capActionControllers.clear();
    for (final it in _items) {
      final id = _parseInt(it['id']);
      if (id == null) continue;
      _commentControllers[id] = TextEditingController(text: it['comment']?.toString() ?? '');
      if ((it['result']?.toString() ?? '') == 'NC') {
        _ensureCapObject(it);
        final cap = (it['cap'] is Map) ? it['cap'] as Map<String, dynamic> : <String, dynamic>{};
        _capActionControllers[id] = TextEditingController(text: cap['action_plan']?.toString() ?? '');
      }
    }

    _initExpandedSections();

    if (_isTruthy(_permissions['can_submit_cap'])) {
      _availableApprovers = await _prService.getApprovers();
    }

    setState(() {
      _loading = false;
    });
  }

  String _sectionKey(String cat, String sub, {bool cap = false}) => '${cap ? 'cap:' : ''}$cat\x1e$sub';

  void _initExpandedSections() {
    _expandedSections.clear();
    for (final cat in groupItems(_detailItemsForDisplay).entries) {
      for (final sub in cat.value.entries) {
        _expandedSections.add(_sectionKey(cat.key, sub.key));
      }
    }
    for (final cat in groupItems(_items, ncOnly: true).entries) {
      for (final sub in cat.value.entries) {
        _expandedSections.add(_sectionKey(cat.key, sub.key, cap: true));
      }
    }
  }

  void _expandVisibleSections({bool ncOnly = false, bool cap = false}) {
    final source = ncOnly ? _items : _detailItemsForDisplay;
    final grouped = groupItems(source, ncOnly: ncOnly, search: _searchQuery);
    for (final cat in grouped.entries) {
      for (final sub in cat.value.entries) {
        _expandedSections.add(_sectionKey(cat.key, sub.key, cap: cap));
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final next = _searchCtrl.text;
      if (next == _searchQuery) return;
      setState(() {
        _searchQuery = next;
        _expandVisibleSections();
        _expandVisibleSections(ncOnly: true, cap: true);
      });
    });
  }

  void _toggleSection(String key) {
    setState(() {
      if (_expandedSections.contains(key)) {
        _expandedSections.remove(key);
      } else {
        _expandedSections.add(key);
      }
    });
  }

  Set<int> _extractIds(dynamic raw) {
    if (raw is! List) return {};
    return raw.map((e) => _parseInt((e as dynamic)['id'])).whereType<int>().toSet();
  }

  bool _isTruthy(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

  bool get _isSubmitted => (_audit['status']?.toString() ?? '') == 'submitted';

  bool get _hasNcItems => _items.any((it) => (it['result']?.toString() ?? '') == 'NC');

  bool get _canFillCap => _isSubmitted && (_isTruthy(_permissions['can_fill_cap']) || _isAuditAuditee);

  bool get _canEditCap => _canFillCap && _permissions['can_edit_cap'] != false;

  bool get _canSubmitCap => _isTruthy(_permissions['can_submit_cap']);

  String? get _capSubmissionStatus => _audit['cap_submission_status']?.toString();

  bool get _canSwitchToCap => _canFillCap && _hasNcItems;

  bool get _showCapMode => _viewCap && _isSubmitted && _hasNcItems;

  bool get _canManageDraft =>
      _isTruthy(_permissions['can_manage']) && (_audit['status']?.toString() ?? 'draft') == 'draft';

  bool get _canEditAuditee => _isTruthy(_permissions['can_edit_auditee']);

  bool _isVisibleReadOnlyItem(Map<String, dynamic> item) {
    final result = (item['result']?.toString() ?? '').trim();
    if (result == 'NC') return true;
    if (result != 'C') return false;
    return (item['comment']?.toString() ?? '').trim().isNotEmpty;
  }

  List<Map<String, dynamic>> get _detailItemsForDisplay {
    if (_canManageDraft) return _items;
    return _items.where(_isVisibleReadOnlyItem).toList();
  }

  void _scheduleDraftSave() {
    if (!_canManageDraft) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 1200), _saveDraft);
  }

  void _scheduleAuditeeSave() {
    if (!_canEditAuditee) return;
    _auditeeDebounce?.cancel();
    _auditeeDebounce = Timer(const Duration(milliseconds: 1200), _saveAuditees);
  }

  void _scheduleCapSave() {
    if (!_canEditCap) return;
    _capDebounce?.cancel();
    _capDebounce = Timer(const Duration(milliseconds: 1200), _saveCap);
  }

  void _ensureCapObject(Map<String, dynamic> item) {
    if ((item['result']?.toString() ?? '') != 'NC') return;
    if (item['cap'] is Map) {
      final cap = item['cap'] as Map<String, dynamic>;
      cap['medias'] ??= (cap['media'] is List)
          ? (cap['media'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x as Map)).toList()
          : <Map<String, dynamic>>[];
      return;
    }
    item['cap'] = <String, dynamic>{
      'action_plan': '',
      'target_date': null,
      'status': 'open',
      'medias': <Map<String, dynamic>>[],
    };
  }

  void _applyCapIds(List<dynamic> capsRaw) {
    for (final c in capsRaw) {
      if (c is! Map) continue;
      final auditItemId = _parseInt(c['audit_item_id']);
      final capId = _parseInt(c['cap_id']);
      if (auditItemId == null || capId == null) continue;
      for (final it in _items) {
        if (_parseInt(it['id']) != auditItemId) continue;
        _ensureCapObject(it);
        final cap = (it['cap'] is Map) ? Map<String, dynamic>.from(it['cap'] as Map) : <String, dynamic>{};
        cap['id'] = capId;
        cap['medias'] ??= (cap['media'] is List)
            ? (cap['media'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x as Map)).toList()
            : <Map<String, dynamic>>[];
        it['cap'] = cap;
      }
    }
  }

  Future<bool> _ensureCapRecord(Map<String, dynamic> item) async {
    if (!_canEditCap) return false;
    _ensureCapObject(item);
    final cap = (item['cap'] is Map) ? item['cap'] as Map<String, dynamic> : <String, dynamic>{};
    if (_parseInt(cap['id']) != null) return true;

    final iid = _parseInt(item['id']);
    if (iid == null) return false;

    final res = await _service.saveCap(widget.auditId, {
      'caps': [
        {
          'audit_item_id': iid,
          'action_plan': cap['action_plan'] ?? '',
          'target_date': cap['target_date'],
          'status': cap['status'] ?? 'open',
        },
      ],
    });
    if (res['success'] != true) return false;
    final capsRaw = res['caps'];
    if (capsRaw is List) {
      _applyCapIds(capsRaw);
    }
    final updated = (item['cap'] is Map) ? item['cap'] as Map<String, dynamic> : <String, dynamic>{};
    return _parseInt(updated['id']) != null;
  }

  String _capStatusLabel(String value) {
    switch (value) {
      case 'open':
        return 'Open';
      case 'progress':
        return 'Progress';
      case 'done':
        return 'Done';
      default:
        return value;
    }
  }

  Future<void> _saveDraft() async {
    if (!_canManageDraft) return;
    setState(() => _savingDraft = true);
    final payload = {
      'outlet_id': _outletId,
      'auditor_ids': _auditorIds.toList(),
      'auditee_ids': _auditeeIds.toList(),
      'notes': _notesCtrl.text.trim(),
      'items': _items
          .map((it) => {
                'id': it['id'],
                'result': it['result'],
                'due_date': it['due_date'],
                'comment': it['comment'],
              })
          .toList(),
    };
    await _service.saveDraft(widget.auditId, payload);
    if (!mounted) return;
    setState(() {
      _savingDraft = false;
      _lastSavedAt = DateFormat('HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _saveAuditees() async {
    if (!_canEditAuditee) return;
    setState(() => _savingAuditees = true);
    final res = await _service.updateAuditees(widget.auditId, {
      'auditee_ids': _auditeeIds.toList(),
    });
    if (!mounted) return;
    setState(() {
      _savingAuditees = false;
      if (res['success'] == true) {
        _auditeeLastSavedAt = DateFormat('HH:mm:ss').format(DateTime.now());
        _isAuditAuditee = _currentUserId != null && _auditeeIds.contains(_currentUserId);
      }
    });
  }

  Future<void> _saveCap() async {
    if (!_canEditCap) return;
    setState(() => _savingCap = true);
    final caps = _items.where((it) => (it['result']?.toString() ?? '') == 'NC').map((it) {
      final cap = (it['cap'] is Map) ? Map<String, dynamic>.from(it['cap'] as Map) : <String, dynamic>{};
      return {
        'audit_item_id': it['id'],
        'action_plan': cap['action_plan'] ?? '',
        'target_date': cap['target_date'],
        'status': cap['status'] ?? 'open',
      };
    }).toList();
    final res = await _service.saveCap(widget.auditId, {'caps': caps});
    if (!mounted) return;
    if (res['success'] == true) {
      _capLastSavedAt = DateFormat('HH:mm:ss').format(DateTime.now());
      final capsRaw = res['caps'];
      if (capsRaw is List) {
        _applyCapIds(capsRaw);
      }
      setState(() => _savingCap = false);
    } else {
      setState(() => _savingCap = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Gagal menyimpan CAP.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitAudit() async {
    final missing = _items.where((x) {
      final r = x['result']?.toString();
      return r != 'C' && r != 'NC' && r != 'NA';
    }).length;
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Masih ada $missing parameter belum diisi C/NC/NA.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit QA Audit?'),
        content: const Text(
          'Status akan berubah menjadi submitted dan Audit Time End akan terisi otomatis.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    await _saveDraft();
    final res = await _service.submitAudit(widget.auditId);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audit berhasil disubmit.'), behavior: SnackBarBehavior.floating),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal submit.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<List<XFile>> _collectMediaFiles(String source) async {
    switch (source) {
      case 'gallery':
        return _picker.pickMultiImage(imageQuality: 85);
      case 'camera':
        final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        return x != null ? [x] : [];
      case 'video':
        final x = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
        return x != null ? [x] : [];
      case 'files':
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi', 'webm'],
          allowMultiple: true,
        );
        if (result == null) return [];
        return result.files
            .where((f) => f.path != null && f.path!.isNotEmpty)
            .map((f) => XFile(f.path!))
            .toList();
      default:
        return [];
    }
  }

  Future<void> _uploadItemFiles(Map<String, dynamic> item, List<XFile> files) async {
    final iid = _parseInt(item['id']);
    if (iid == null || files.isEmpty) return;

    final existing = (item['medias'] is List)
        ? (item['medias'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final tempKeys = <String>[];
    for (final f in files) {
      final key = 'temp-${f.path}';
      tempKeys.add(key);
      existing.add({
        '_temp_key': key,
        'url': f.path,
        'media_type': f.path.toLowerCase().contains('.mp4') || f.path.toLowerCase().contains('.mov') ? 'video' : 'photo',
        'local': true,
      });
    }
    item['medias'] = existing;
    setState(() => _uploadingItemMedia.add(iid));

    final res = await _service.uploadItemMedia(widget.auditId, iid, files);
    if (!mounted) return;
    setState(() => _uploadingItemMedia.remove(iid));
    if (res['success'] == true) {
      final addedRaw = res['items'];
      if (addedRaw is List) {
        final current = (item['medias'] is List)
            ? (item['medias'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        current.removeWhere((m) => tempKeys.contains(m['_temp_key']?.toString()));
        current.addAll(
          addedRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)),
        );
        item['medias'] = current;
        setState(() {});
      } else {
        _load();
      }
    } else {
      final current = (item['medias'] is List)
          ? (item['medias'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      current.removeWhere((m) => tempKeys.contains(m['_temp_key']?.toString()));
      item['medias'] = current;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Upload gagal'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _pickItemMedia(Map<String, dynamic> item, {required String source}) async {
    final files = await _collectMediaFiles(source);
    if (files.isEmpty) return;
    await _uploadItemFiles(item, files);
  }

  Future<void> _deleteItemMedia(Map<String, dynamic> item, Map<String, dynamic> media) async {
    if (media['local'] == true) {
      final key = media['_temp_key']?.toString();
      item['medias'] = (item['medias'] as List).where((m) {
        if (m is! Map) return true;
        if (key != null && m['_temp_key']?.toString() == key) return false;
        return m != media;
      }).toList();
      setState(() {});
      return;
    }

    final iid = _parseInt(item['id']);
    final mid = _parseInt(media['id']);
    if (iid == null || mid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus lampiran?'),
        content: const Text('Foto/video akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _uploadingItemMedia.add(iid));
    final res = await _service.deleteItemMedia(widget.auditId, iid, mid);
    if (!mounted) return;
    setState(() => _uploadingItemMedia.remove(iid));
    if (res['success'] == true) {
      item['medias'] = (item['medias'] as List).where((m) => _parseInt((m as dynamic)['id']) != mid).toList();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menghapus'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _uploadCapFiles(Map<String, dynamic> item, List<XFile> files) async {
    final iid = _parseInt(item['id']);
    if (iid == null || files.isEmpty) return;

    final ok = await _ensureCapRecord(item);
    if (!ok || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyiapkan CAP sebelum upload media.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    Map<String, dynamic> cap = (item['cap'] is Map) ? Map<String, dynamic>.from(item['cap'] as Map) : {};
    final capId = _parseInt(cap['id']);
    if (capId == null) return;

    final existing = (cap['medias'] is List)
        ? (cap['medias'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final tempKeys = <String>[];
    for (final f in files) {
      final key = 'temp-cap-${f.path}';
      tempKeys.add(key);
      existing.add({
        '_temp_key': key,
        'url': f.path,
        'media_type': f.path.toLowerCase().contains('.mp4') || f.path.toLowerCase().contains('.mov') ? 'video' : 'photo',
        'local': true,
      });
    }
    cap['medias'] = existing;
    item['cap'] = cap;
    setState(() {
      _uploadingCapMedia.add(capId);
      _uploadingCapItemIds.add(iid);
    });

    final res = await _service.uploadCapMedia(widget.auditId, capId, files);
    if (!mounted) return;
    setState(() {
      _uploadingCapMedia.remove(capId);
      _uploadingCapItemIds.remove(iid);
    });

    cap = (item['cap'] is Map) ? Map<String, dynamic>.from(item['cap'] as Map) : {};
    if (res['success'] == true) {
      final addedRaw = res['items'];
      if (addedRaw is List) {
        final current = (cap['medias'] is List)
            ? (cap['medias'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        current.removeWhere((m) => tempKeys.contains(m['_temp_key']?.toString()));
        current.addAll(
          addedRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)),
        );
        cap['medias'] = current;
        item['cap'] = cap;
        setState(() {});
      } else {
        _load();
      }
    } else {
      final current = (cap['medias'] is List)
          ? (cap['medias'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      current.removeWhere((m) => tempKeys.contains(m['_temp_key']?.toString()));
      cap['medias'] = current;
      item['cap'] = cap;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Upload CAP gagal'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _pickCapMedia(Map<String, dynamic> item, {required String source}) async {
    if (!_canEditCap) return;
    final files = await _collectMediaFiles(source);
    if (files.isEmpty) return;
    await _uploadCapFiles(item, files);
  }

  Future<void> _pickDueDate(Map<String, dynamic> item) async {
    final now = DateTime.now();
    final existing = item['due_date']?.toString();
    DateTime initial = now;
    if (existing != null && existing.isNotEmpty) {
      try {
        initial = DateTime.parse(existing);
      } catch (_) {}
    }
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      setState(() => item['due_date'] = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      _scheduleDraftSave();
    }
  }

  Future<void> _pickCapTarget(Map<String, dynamic> item) async {
    final now = DateTime.now();
    final cap = (item['cap'] is Map) ? item['cap'] as Map<String, dynamic> : <String, dynamic>{};
    final existing = cap['target_date']?.toString();
    DateTime initial = now;
    if (existing != null && existing.isNotEmpty) {
      try {
        initial = DateTime.parse(existing);
      } catch (_) {}
    }
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      cap['target_date'] = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      item['cap'] = cap;
      setState(() {});
      _scheduleCapSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final showItems = !_showCapMode;
    final showCap = _showCapMode;
    final capBlocked = showCap && !_canFillCap;
    final searchTitle = showCap ? 'Pengisian CAP (NC)' : 'Parameter Audit';
    final searchHint = showCap ? 'Cari parameter NC...' : 'Cari parameter, kategori, subcategory...';

    return AppScaffold(
      title: showCap ? 'Isi CAP' : 'QA Audit',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 38, color: Qa2AuditUi.primary))
          : RefreshIndicator(
              color: Qa2AuditUi.primary,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        children: [
                          _headerSection(),
                          if (_isSubmitted && (_canSwitchToCap || _viewCap)) ...[
                            const SizedBox(height: 10),
                            _viewModeSwitcher(),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (showItems || showCap)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickySearchHeaderDelegate(
                        title: searchTitle,
                        hint: searchHint,
                        controller: _searchCtrl,
                        backgroundColor: scaffoldBg,
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  if (showCap) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (capBlocked)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: const Text(
                                  'Anda bukan auditee audit ini. Hanya auditee yang dapat mengisi CAP.',
                                  style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                            const Text(
                              'Hanya parameter Non-Compliant. Perubahan disimpan otomatis.',
                              style: TextStyle(color: Qa2AuditUi.slate500, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                    _capItemsSliver(editable: _canEditCap),
                    if (_canEditCap)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        sliver: SliverToBoxAdapter(child: _saveCapButton()),
                      ),
                    if (_canSubmitCap || _capSubmissionStatus == 'pending_approval')
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        sliver: SliverToBoxAdapter(child: _capApprovalFlowSection()),
                      ),
                  ],
                  if (showItems) ...[
                    if (_canManageDraft)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: SliverToBoxAdapter(child: _parameterLegend()),
                      ),
                    _parameterItemsSliver(),
                  ],
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_showCapMode) _summarySection(),
                          if (_canManageDraft) ...[
                            const SizedBox(height: 12),
                            _submitButton(),
                          ],
                          if (_savingDraft || _savingAuditees || _savingCap || _submitting)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: AppLoadingIndicator(size: 24, color: Qa2AuditUi.primary),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade900))),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _headerSection() {
    final status = _audit['status']?.toString() ?? '-';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_audit['audit_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 8),
              Qa2AuditUi.statusChip(status),
              const Spacer(),
              if (_savingDraft) const Text('Menyimpan...', style: TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
              if (_savingAuditees) const Text('Menyimpan auditee...', style: TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
              if (_savingCap) const Text('Menyimpan CAP...', style: TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_dateText(_audit['created_at']?.toString() ?? _audit['audit_datetime']?.toString()),
              style: const TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Time Start: ${_audit['audit_time_start']?.toString() ?? '-'}',
              style: const TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
          Text('Time End: ${_audit['audit_time_end']?.toString() ?? '-'}',
              style: const TextStyle(color: Qa2AuditUi.slate500, fontSize: 12)),
          if (_canManageDraft && _lastSavedAt.isNotEmpty)
            Text('Tersimpan $_lastSavedAt',
                style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w600)),
          if (_canEditAuditee && _auditeeLastSavedAt.isNotEmpty)
            Text('Auditee tersimpan $_auditeeLastSavedAt',
                style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w600)),
          if (_canFillCap && _capLastSavedAt.isNotEmpty && _showCapMode)
            Text('CAP tersimpan $_capLastSavedAt',
                style: const TextStyle(color: Color(0xFFBE123C), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_canManageDraft) ...[
            _fieldLabel('Outlet'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _outletId,
                  hint: const Text('Pilih outlet'),
                  items: [
                    ..._outlets.expand((o) sync* {
                      final id = Qa2AuditUi.outletId(o);
                      if (id == null) return;
                      yield DropdownMenuItem<int?>(value: id, child: Text(Qa2AuditUi.outletName(o)));
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _outletId = v);
                    _scheduleDraftSave();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _fieldLabel('Auditor'),
            Qa2AuditUserPicker(
              users: _users,
              selectedIds: _auditorIds,
              title: 'Pilih Auditor',
              buttonLabel: 'Pilih auditor',
              searchHint: 'Cari nama atau jabatan auditor...',
              onChanged: (ids) {
                setState(() {
                  _auditorIds
                    ..clear()
                    ..addAll(ids);
                });
                _scheduleDraftSave();
              },
            ),
            const SizedBox(height: 12),
            _fieldLabel('Auditee'),
            Qa2AuditUserPicker(
              users: _users,
              selectedIds: _auditeeIds,
              title: 'Pilih Auditee',
              buttonLabel: 'Pilih auditee',
              searchHint: 'Cari nama atau jabatan auditee...',
              onChanged: (ids) {
                setState(() {
                  _auditeeIds
                    ..clear()
                    ..addAll(ids);
                });
                _scheduleDraftSave();
              },
            ),
            const SizedBox(height: 12),
            _fieldLabel('Catatan'),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: _inputDecoration('Catatan audit'),
              onChanged: (_) => _scheduleDraftSave(),
            ),
          ] else ...[
            _fieldLabel('Outlet'),
            Text(_audit['outlet_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _fieldLabel('Auditor'),
            Text(
              _displayPeople(_audit['auditors'], _auditorIds),
              style: const TextStyle(color: Qa2AuditUi.slate600),
            ),
            const SizedBox(height: 10),
            _fieldLabel('Auditee'),
            if (_canEditAuditee) ...[
              const Text(
                'Auditee masih dapat diubah setelah submit.',
                style: TextStyle(color: Qa2AuditUi.primary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Qa2AuditUserPicker(
                users: _users,
                selectedIds: _auditeeIds,
                title: 'Pilih Auditee',
                buttonLabel: 'Pilih auditee',
                searchHint: 'Cari nama atau jabatan auditee...',
                onChanged: (ids) {
                  setState(() {
                    _auditeeIds
                      ..clear()
                      ..addAll(ids);
                  });
                  _scheduleAuditeeSave();
                },
              ),
            ] else ...[
              Text(
                _displayPeople(_audit['auditees'], _auditeeIds),
                style: const TextStyle(color: Qa2AuditUi.slate600),
              ),
            ],
            if ((_audit['notes']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _fieldLabel('Catatan'),
              Text(_audit['notes'].toString()),
            ],
          ],
        ],
      ),
    );
  }

  Widget _readOnlyMediaGrid(List medias) {
    if (medias.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: medias.whereType<Map>().map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return GestureDetector(
          onTap: () => qa2OpenMediaPreview(context, m),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: qa2MediaThumbnail(m),
          ),
        );
      }).toList(),
    );
  }

  Widget _auditorFindingBlock(Map<String, dynamic> item) {
    final comment = item['comment']?.toString() ?? '';
    final dueDate = item['due_date']?.toString() ?? '';
    final medias = (item['medias'] is List) ? item['medias'] as List : <dynamic>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Temuan Auditor',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Qa2AuditUi.slate500, letterSpacing: 0.4)),
          const SizedBox(height: 10),
          const Text('Komentar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Qa2AuditUi.slate500)),
          const SizedBox(height: 4),
          Text(comment.isEmpty ? '-' : comment, style: const TextStyle(color: Qa2AuditUi.slate600)),
          const SizedBox(height: 10),
          const Text('Due Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Qa2AuditUi.slate500)),
          const SizedBox(height: 4),
          Text(dueDate.isEmpty ? '-' : _dateText(dueDate), style: const TextStyle(color: Qa2AuditUi.slate600)),
          const SizedBox(height: 10),
          const Text('Bukti Media', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Qa2AuditUi.slate500)),
          const SizedBox(height: 6),
          if (medias.isNotEmpty)
            _readOnlyMediaGrid(medias)
          else
            const Text('Tidak ada lampiran', style: TextStyle(fontSize: 12, color: Qa2AuditUi.slate500)),
        ],
      ),
    );
  }

  Widget _readOnlyCapBlock(Map<String, dynamic> item) {
    if (_canFillCap) return const SizedBox.shrink();
    if ((item['result']?.toString() ?? '') != 'NC') return const SizedBox.shrink();
    final cap = (item['cap'] is Map) ? item['cap'] as Map<String, dynamic> : <String, dynamic>{};
    final actionPlan = cap['action_plan']?.toString() ?? '';
    final capMedias = (cap['medias'] is List) ? cap['medias'] as List : <dynamic>[];
    final hasCapResponse = actionPlan.isNotEmpty || capMedias.isNotEmpty;
    if (!hasCapResponse) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Corrective Action Plan', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBE123C))),
          if (actionPlan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(actionPlan, style: const TextStyle(color: Qa2AuditUi.slate600)),
          ],
          if (cap['target_date'] != null && cap['target_date'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Target: ${_dateText(cap['target_date']?.toString())}', style: const TextStyle(color: Qa2AuditUi.slate600)),
          ],
          if (cap['status'] != null && cap['status'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Status: ${cap['status']}', style: const TextStyle(color: Qa2AuditUi.slate600)),
          ],
          if (capMedias.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Media CAP', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFBE123C))),
            const SizedBox(height: 6),
            _readOnlyMediaGrid(capMedias),
          ],
        ],
      ),
    );
  }

  Widget _parameterItemsSliver() {
    final grouped = groupItems(_detailItemsForDisplay, search: _searchQuery);
    if (grouped.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _card(
            child: Text(
              _searchQuery.trim().isNotEmpty
                  ? 'Tidak ada parameter yang cocok dengan pencarian.'
                  : 'Belum ada parameter audit dari template.',
              style: const TextStyle(color: Qa2AuditUi.slate600),
            ),
          ),
        ),
      );
    }

    final categories = grouped.entries.toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cat = categories[index];
            return _parameterCategoryCard(cat.key, cat.value, editable: _canManageDraft);
          },
          childCount: categories.length,
        ),
      ),
    );
  }

  Widget _parameterCategoryCard(
    String categoryName,
    Map<String, List<Map<String, dynamic>>> subs, {
    required bool editable,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            for (final sub in subs.entries) _parameterSubSection(categoryName, sub.key, sub.value, editable),
          ],
        ),
      ),
    );
  }

  Widget _parameterSubSection(
    String category,
    String subcategory,
    List<Map<String, dynamic>> items,
    bool editable,
  ) {
    final key = _sectionKey(category, subcategory);
    final expanded = _expandedSections.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _collapsibleSubHeader(
          title: subcategory,
          expanded: expanded,
          onTap: () => _toggleSection(key),
          cap: false,
        ),
        if (expanded)
          for (final it in items)
            RepaintBoundary(
              key: ValueKey('param-${it['id']}'),
              child: _itemTile(it, editable),
            ),
      ],
    );
  }

  Widget _capItemsSliver({required bool editable}) {
    if (_items.where((it) => (it['result']?.toString() ?? '') == 'NC').isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverToBoxAdapter(child: _capEmptyCard('Tidak ada temuan NC untuk CAP.')),
      );
    }

    final grouped = groupItems(_items, ncOnly: true, search: _searchQuery);
    if (grouped.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _capEmptyCard(
            _searchQuery.trim().isNotEmpty
                ? 'Tidak ada parameter NC yang cocok dengan pencarian.'
                : 'Tidak ada parameter NC untuk diisi CAP.',
          ),
        ),
      );
    }

    final categories = grouped.entries.toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cat = categories[index];
            return _capCategoryCard(cat.key, cat.value, editable: editable);
          },
          childCount: categories.length,
        ),
      ),
    );
  }

  Widget _capCategoryCard(
    String categoryName,
    Map<String, List<Map<String, dynamic>>> subs, {
    required bool editable,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: const Color(0xFFFFF1F2),
            child: Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9F1239))),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final sub in subs.entries) _capSubSection(categoryName, sub.key, sub.value, editable),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capSubSection(
    String category,
    String subcategory,
    List<Map<String, dynamic>> items,
    bool editable,
  ) {
    final key = _sectionKey(category, subcategory, cap: true);
    final expanded = _expandedSections.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _collapsibleSubHeader(
          title: subcategory,
          expanded: expanded,
          onTap: () => _toggleSection(key),
          cap: true,
        ),
        if (expanded)
          for (final it in items)
            RepaintBoundary(
              key: ValueKey('cap-${it['id']}'),
              child: _capItemTile(it, editable: editable),
            ),
      ],
    );
  }

  Widget _collapsibleSubHeader({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required bool cap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cap ? Qa2AuditUi.slate900 : Qa2AuditUi.slate900,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: cap ? const Color(0xFFBE123C) : Qa2AuditUi.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _parameterLegend() {
    if (!_canManageDraft) return const SizedBox.shrink();
    Widget pill(String label, Color bg, Color fg, {bool dashed = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: dashed ? Border.all(color: const Color(0xFFFCD34D)) : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          pill('Belum diisi', const Color(0xFFFFFBEB), const Color(0xFFB45309), dashed: true),
          pill('C', const Color(0xFFD1FAE5), const Color(0xFF047857)),
          pill('NC', const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
          pill('NA', const Color(0xFFE2E8F0), const Color(0xFF475569)),
        ],
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item, bool editable) {
    final result = item['result']?.toString();
    final iid = _parseInt(item['id']);
    final fillStyle = Qa2AuditUi.parameterFillStyle(result);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fillStyle.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fillStyle.border,
            width: Qa2AuditUi.isParameterFilled(result) ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item['parameter_code']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['parameter_text']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Qa2AuditUi.slate900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: fillStyle.badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    fillStyle.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fillStyle.badgeFg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          if (editable)
            Wrap(
              spacing: 8,
              children: ['C', 'NC', 'NA'].map((v) {
                final selected = result == v;
                return ChoiceChip(
                  label: Text(v),
                  selected: selected,
                  onSelected: editable
                      ? (_) {
                          setState(() => item['result'] = v);
                          _scheduleDraftSave();
                        }
                      : null,
                  selectedColor: Qa2AuditUi.primary.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    color: selected ? Qa2AuditUi.primary : Qa2AuditUi.slate600,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: result == 'C'
                    ? const Color(0xFFD1FAE5)
                    : result == 'NC'
                        ? const Color(0xFFFFE4E6)
                        : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(result ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 8),
          if (editable) ...[
            Row(
              children: [
                const Icon(Icons.event_rounded, size: 18, color: Qa2AuditUi.slate500),
                const SizedBox(width: 8),
                Text('Due date: ${_dateText(item['due_date']?.toString())}', style: const TextStyle(color: Qa2AuditUi.slate600)),
                const Spacer(),
                TextButton(onPressed: () => _pickDueDate(item), child: const Text('Pilih tanggal')),
              ],
            ),
            const SizedBox(height: 6),
            if (iid != null && _commentControllers.containsKey(iid))
              TextField(
                key: ValueKey('comment-$iid'),
                decoration: _inputDecoration('Catatan / komentar'),
                controller: _commentControllers[iid],
                onChanged: (v) {
                  item['comment'] = v;
                  _scheduleDraftSave();
                },
                maxLines: 3,
              ),
          ] else if (result == 'NC') ...[
            _auditorFindingBlock(item),
            const SizedBox(height: 8),
          ] else ...[
            if ((item['due_date']?.toString() ?? '').isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.event_rounded, size: 18, color: Qa2AuditUi.slate500),
                  const SizedBox(width: 8),
                  Text('Due date: ${_dateText(item['due_date']?.toString())}',
                      style: const TextStyle(color: Qa2AuditUi.slate600)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if ((item['comment']?.toString() ?? '').isNotEmpty) ...[
              const Text('Komentar', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(item['comment'].toString(), style: const TextStyle(color: Qa2AuditUi.slate600)),
              const SizedBox(height: 6),
            ],
            _mediaRow(item, editable: false),
          ],
          if (editable) _mediaRow(item, editable: true),
          _readOnlyCapBlock(item),
          if (_canFillCap && result == 'NC' && !_showCapMode)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.report_problem_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'NC — gunakan tab Isi CAP untuk mengisi perbaikan',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (iid != null && _uploadingItemMedia.contains(iid))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: AppLoadingIndicator(size: 18, color: Qa2AuditUi.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaRow(Map<String, dynamic> item, {required bool editable}) {
    final medias = (item['medias'] is List) ? item['medias'] as List : <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lampiran', style: TextStyle(fontWeight: FontWeight.w700, color: Qa2AuditUi.slate900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...medias.whereType<Map>().map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  GestureDetector(
                    onTap: () => qa2OpenMediaPreview(context, m),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: qa2MediaThumbnail(m),
                    ),
                  ),
                  if (editable)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(26, 26),
                        ),
                        onPressed: () => _deleteItemMedia(item, m),
                      ),
                    ),
                ],
              );
            }),
            if (editable) ...[
              OutlinedButton.icon(
                onPressed: () => _pickItemMedia(item, source: 'gallery'),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Galeri'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickItemMedia(item, source: 'camera'),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Kamera'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickItemMedia(item, source: 'video'),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Rekam Video'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickItemMedia(item, source: 'files'),
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Pilih File'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _capEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3), style: BorderStyle.solid),
      ),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Qa2AuditUi.slate600)),
    );
  }

  Widget _capItemTile(Map<String, dynamic> item, {required bool editable}) {
    _ensureCapObject(item);
    final cap = (item['cap'] is Map) ? item['cap'] as Map<String, dynamic> : <String, dynamic>{};
    final iid = _parseInt(item['id']);
    const capStatuses = ['open', 'progress', 'done'];
    final capStatus = () {
      final raw = cap['status']?.toString() ?? '';
      if (raw == 'in_progress') return 'progress';
      if (capStatuses.contains(raw)) return raw;
      return capStatuses.first;
    }();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['parameter_code']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Qa2AuditUi.slate500, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(item['parameter_text']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, color: Qa2AuditUi.slate900)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(999)),
                child: const Text('NC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _auditorFindingBlock(item),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Corrective Action Plan', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBE123C))),
                const SizedBox(height: 10),
                _fieldLabel('Action Plan'),
                if (editable && iid != null && _capActionControllers.containsKey(iid))
                  TextField(
                    key: ValueKey('cap-action-$iid'),
                    controller: _capActionControllers[iid],
                    maxLines: 3,
                    decoration: _inputDecoration('Tindakan perbaikan...'),
                    onChanged: (v) {
                      cap['action_plan'] = v;
                      item['cap'] = cap;
                      _scheduleCapSave();
                    },
                  )
                else
                  Text(
                    (cap['action_plan']?.toString() ?? '').isEmpty ? '-' : cap['action_plan'].toString(),
                    style: const TextStyle(color: Qa2AuditUi.slate600),
                  ),
                const SizedBox(height: 10),
                _fieldLabel('Target Date'),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dateText(cap['target_date']?.toString()),
                        style: const TextStyle(color: Qa2AuditUi.slate600),
                      ),
                    ),
                    if (editable)
                      TextButton(onPressed: () => _pickCapTarget(item), child: const Text('Pilih tanggal')),
                  ],
                ),
                const SizedBox(height: 8),
                _fieldLabel('Status CAP'),
                if (editable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: capStatus,
                        items: capStatuses
                            .map((s) => DropdownMenuItem<String>(value: s, child: Text(_capStatusLabel(s))))
                            .toList(),
                        onChanged: (v) {
                          cap['status'] = v;
                          item['cap'] = cap;
                          setState(() {});
                          _scheduleCapSave();
                        },
                      ),
                    ),
                  )
                else
                  Text(_capStatusLabel(capStatus), style: const TextStyle(color: Qa2AuditUi.slate600)),
                if (editable) ...[
                  const SizedBox(height: 12),
                  const Text('Media CAP (per parameter)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFBE123C), fontSize: 12)),
                  const SizedBox(height: 8),
                  _capMediaRow(item),
                  if (iid != null && _uploadingCapItemIds.contains(iid))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Mengunggah media CAP...', style: TextStyle(fontSize: 11, color: Color(0xFFBE123C), fontWeight: FontWeight.w600)),
                    ),
                ] else if ((cap['medias'] is List ? (cap['medias'] as List) : []).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Media CAP', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFBE123C), fontSize: 12)),
                  const SizedBox(height: 8),
                  _readOnlyMediaGrid((cap['medias'] as List)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capMediaRow(Map<String, dynamic> item) {
    final cap = (item['cap'] is Map) ? item['cap'] as Map<String, dynamic> : <String, dynamic>{};
    final medias = (cap['medias'] is List) ? cap['medias'] as List : <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medias.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: medias.whereType<Map>().map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return GestureDetector(
                onTap: () => qa2OpenMediaPreview(context, m),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: qa2MediaThumbnail(m),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickCapMedia(item, source: 'camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBE123C),
                side: const BorderSide(color: Color(0xFFFECDD3)),
              ),
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: const Text('Ambil Foto'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickCapMedia(item, source: 'video'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBE123C),
                side: const BorderSide(color: Color(0xFFFECDD3)),
              ),
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: const Text('Rekam Video'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickCapMedia(item, source: 'files'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9F1239),
                backgroundColor: const Color(0xFFFFE4E6),
                side: const BorderSide(color: Color(0xFFFECDD3)),
              ),
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Pilih File'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickCapMedia(item, source: 'gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBE123C),
                side: const BorderSide(color: Color(0xFFFECDD3)),
              ),
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Galeri'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summarySection() {
    final summaryRowsRaw = _audit['summary_rows'];
    final summaryRows = (summaryRowsRaw is List)
        ? summaryRowsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final hasServerSummary = summaryRows.isNotEmpty;

    final perCat = <String, Map<String, int>>{};
    if (hasServerSummary) {
      for (final row in summaryRows) {
        final cat = row['name']?.toString() ?? 'Lainnya';
        final c = _parseInt(row['compliant']) ?? 0;
        final nc = _parseInt(row['non_compliant']) ?? 0;
        final na = _parseInt(row['non_applicable']) ?? 0;
        perCat[cat] = {'C': c, 'NC': nc, 'NA': na};
      }
    } else {
      for (final it in _items) {
        final cat = it['category_name']?.toString() ?? 'Lainnya';
        final res = it['result']?.toString() ?? '';
        perCat.putIfAbsent(cat, () => {'C': 0, 'NC': 0, 'NA': 0});
        if (perCat[cat]!.containsKey(res)) perCat[cat]![res] = perCat[cat]![res]! + 1;
      }
    }

    final overallScore = hasServerSummary
        ? _parseDouble((_audit['summary_total'] as Map?)?['score'])
        : Qa2AuditUi.itemScore(_items);
    final badge = Qa2AuditUi.resultBadge(overallScore);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          ...perCat.entries.map((e) {
            final c = e.value['C'] ?? 0;
            final nc = e.value['NC'] ?? 0;
            final na = e.value['NA'] ?? 0;
            final score = hasServerSummary
                ? _parseDouble(summaryRows.firstWhere(
                    (row) => (row['name']?.toString() ?? 'Lainnya') == e.key,
                    orElse: () => <String, dynamic>{},
                  )['score'])
                : Qa2AuditUi.itemScore(
                    _items.where((it) => (it['category_name']?.toString() ?? '') == e.key).toList(),
                  );
            final b = Qa2AuditUi.resultBadge(score);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('C $c • NC $nc • NA $na', style: const TextStyle(color: Qa2AuditUi.slate600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: b.bg, borderRadius: BorderRadius.circular(999)),
                    child: Text('${Qa2AuditUi.formatScore(score)} ${b.label}',
                        style: TextStyle(color: b.fg, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Hasil Akhir', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: badge.bg, borderRadius: BorderRadius.circular(999)),
                child: Text('${badge.label} • ${Qa2AuditUi.formatScore(overallScore)}',
                    style: TextStyle(color: badge.fg, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _viewModeChip(
              label: 'Lihat Detail',
              icon: Icons.fact_check_outlined,
              selected: !_viewCap,
              onTap: () {
                if (_viewCap) setState(() => _viewCap = false);
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _viewModeChip(
              label: 'Isi CAP',
              icon: Icons.assignment_turned_in_outlined,
              selected: _viewCap,
              enabled: _canSwitchToCap,
              onTap: () {
                if (_canSwitchToCap && !_viewCap) setState(() => _viewCap = true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final fg = selected ? Colors.white : (enabled ? Qa2AuditUi.slate600 : Qa2AuditUi.slate500);
    final bg = selected
        ? (_viewCap && label.contains('CAP') ? const Color(0xFFBE123C) : Qa2AuditUi.primary)
        : Colors.transparent;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveCapButton() {
    return FilledButton.icon(
      onPressed: _savingCap
          ? null
          : () async {
              _capDebounce?.cancel();
              await _saveCap();
              if (!mounted) return;
              if (!_savingCap) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CAP berhasil disimpan.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFBE123C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _savingCap
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save_rounded),
      label: Text(_savingCap ? 'Menyimpan CAP...' : 'Simpan CAP'),
    );
  }

  String _capSubmissionStatusLabel(String? status) {
    switch (status) {
      case 'pending_approval':
        return 'Menunggu Approval';
      case 'approved':
        return 'CAP Disetujui';
      case 'rejected':
        return 'CAP Ditolak';
      default:
        return 'Draft';
    }
  }

  Future<void> _showCapApproverPicker() async {
    if (!mounted || _availableApprovers.isEmpty) {
      final list = await _prService.getApprovers();
      if (!mounted) return;
      setState(() => _availableApprovers = list);
    }
    final available = _availableApprovers.where((a) {
      final id = a['id'];
      return !_capApprovers.any((x) => x['id'] == id);
    }).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua approver sudah ditambahkan')),
      );
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih Approver'),
        children: available
            .map((a) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, a),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['nama_lengkap']?.toString() ?? a['name']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (a['jabatan'] != null)
                        Text(a['jabatan'].toString(), style: const TextStyle(fontSize: 12, color: Qa2AuditUi.slate500)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _capApprovers.add(selected));
    }
  }

  Future<void> _submitCapForApproval() async {
    if (_capApprovers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 approver sebelum submit CAP.')),
      );
      return;
    }
    final incomplete = _items.where((it) {
      if ((it['result']?.toString() ?? '') != 'NC') return false;
      final cap = (it['cap'] is Map) ? it['cap'] as Map : <String, dynamic>{};
      return (cap['action_plan']?.toString().trim() ?? '').isEmpty;
    }).length;
    if (incomplete > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Masih ada $incomplete parameter NC tanpa action plan.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit CAP untuk Approval?'),
        content: const Text('CAP akan dikunci sampai proses approval selesai.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _capSubmitting = true);
    _capDebounce?.cancel();
    await _saveCap();

    final caps = _items.where((it) => (it['result']?.toString() ?? '') == 'NC').map((it) {
      final cap = (it['cap'] is Map) ? Map<String, dynamic>.from(it['cap'] as Map) : <String, dynamic>{};
      return {
        'audit_item_id': it['id'],
        'action_plan': cap['action_plan'] ?? '',
        'target_date': cap['target_date'],
        'status': cap['status'] ?? 'open',
      };
    }).toList();

    final res = await _service.submitCapForApproval(
      widget.auditId,
      approverIds: _capApprovers.map((a) => _parseInt(a['id'])).whereType<int>().toList(),
      caps: caps,
    );
    if (!mounted) return;
    setState(() => _capSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'CAP disubmit.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Submit CAP gagal.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Widget _capApprovalFlowSection() {
    final flows = _audit['cap_approval_flows'];
    final flowList = flows is List ? flows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval Flow CAP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF312E81))),
          if (_capSubmissionStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              'Status: ${_capSubmissionStatusLabel(_capSubmissionStatus)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _capSubmissionStatus == 'pending_approval'
                    ? const Color(0xFFD97706)
                    : (_capSubmissionStatus == 'approved' ? const Color(0xFF059669) : const Color(0xFFBE123C)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Tambahkan approver dari level terendah ke tertinggi. Wajib diisi sebelum submit CAP.',
            style: TextStyle(fontSize: 12, color: Qa2AuditUi.slate600),
          ),
          if (_canSubmitCap) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showCapApproverPicker,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Tambah Approver'),
            ),
          ],
          if (_capApprovers.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._capApprovers.asMap().entries.map((entry) {
              final a = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    Text('L${entry.key + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a['nama_lengkap']?.toString() ?? a['name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_canSubmitCap)
                      IconButton(
                        onPressed: () => setState(() => _capApprovers.removeAt(entry.key)),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                  ],
                ),
              );
            }),
          ],
          if (flowList.isNotEmpty && !_canSubmitCap) ...[
            const SizedBox(height: 8),
            ...flowList.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Level ${f['approval_level']}: ${f['approver_name'] ?? '-'} — ${f['status'] ?? 'PENDING'}',
                    style: const TextStyle(fontSize: 12, color: Qa2AuditUi.slate600),
                  ),
                )),
          ],
          if (_canSubmitCap) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_capSubmitting || _capApprovers.isEmpty) ? null : _submitCapForApproval,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                minimumSize: const Size(double.infinity, 46),
              ),
              icon: _capSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_capSubmitting ? 'Submitting...' : 'Submit CAP untuk Approval'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _submitButton() {
    return FilledButton.icon(
      onPressed: _submitting ? null : _submitAudit,
      style: FilledButton.styleFrom(
        backgroundColor: Qa2AuditUi.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _submitting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check_circle_rounded),
      label: const Text('Submit Audit'),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fieldLabel(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Qa2AuditUi.slate900));

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(12),
    );
  }

  String _listPeople(dynamic raw) {
    if (raw is! List) return '-';
    final labels = <String>[];
    for (final p in raw) {
      if (p is Map) labels.add(Qa2AuditUi.personLabel(Map<String, dynamic>.from(p)));
    }
    return labels.isEmpty ? '-' : labels.join(', ');
  }

  String _displayPeople(dynamic peopleRaw, Set<int> ids) {
    if (peopleRaw is List && peopleRaw.isNotEmpty) {
      return _listPeople(peopleRaw);
    }
    return _labelsFromUserIds(ids);
  }

  String _labelsFromUserIds(Set<int> ids) {
    if (ids.isEmpty) return '-';
    final labels = <String>[];
    for (final id in ids) {
      for (final u in _users) {
        if (_parseInt(u['id']) == id) {
          labels.add(Qa2AuditUi.userLabel(u));
          break;
        }
      }
    }
    return labels.isEmpty ? '-' : labels.join('\n');
  }
}

class _StickySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickySearchHeaderDelegate({
    required this.title,
    required this.hint,
    required this.controller,
    required this.backgroundColor,
    required this.onChanged,
  });

  static const double _height = 108;

  final String title;
  final String hint;
  final TextEditingController controller;
  final Color backgroundColor;
  final VoidCallback onChanged;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Container(
        height: _height,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: overlapsContent ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Qa2AuditUi.slate900),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search_rounded, color: Qa2AuditUi.slate500, size: 22),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        hint != oldDelegate.hint ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

Map<String, Map<String, List<Map<String, dynamic>>>> groupItems(
  List items, {
  bool ncOnly = false,
  String search = '',
}) {
  final keyword = search.toLowerCase().trim();
  final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
  for (final raw in items) {
    if (raw is! Map) continue;
    final it = raw as Map<String, dynamic>;
    if (ncOnly && (it['result']?.toString() ?? '') != 'NC') continue;
    if (keyword.isNotEmpty) {
      final haystack = [
        it['parameter_code'],
        it['parameter_text'],
        it['category_name'],
        it['subcategory_name'],
      ].join(' ').toLowerCase();
      if (!haystack.contains(keyword)) continue;
    }
    final cat = it['category_name']?.toString() ?? 'Lainnya';
    final sub = it['subcategory_name']?.toString() ?? '-';
    grouped.putIfAbsent(cat, () => <String, List<Map<String, dynamic>>>{});
    grouped[cat]!.putIfAbsent(sub, () => <Map<String, dynamic>>[]);
    grouped[cat]![sub]!.add(it);
  }
  return grouped;
}
