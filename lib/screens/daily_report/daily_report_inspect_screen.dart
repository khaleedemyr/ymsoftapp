import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/daily_report_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/daily_report/daily_report_open_tickets_panel.dart';
import 'daily_report_post_inspection_screen.dart';
import 'daily_report_ui.dart';
import 'daily_report_media.dart';

class DailyReportInspectScreen extends StatefulWidget {
  final int reportId;
  const DailyReportInspectScreen({super.key, required this.reportId});

  @override
  State<DailyReportInspectScreen> createState() => _DailyReportInspectScreenState();
}

class _DailyReportInspectScreenState extends State<DailyReportInspectScreen> {
  final DailyReportService _svc = DailyReportService();
  final TicketService _ticketSvc = TicketService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _finding = TextEditingController();

  Map<String, dynamic>? _report;
  List<dynamic> _areas = [];
  List<dynamic> _divisions = [];
  List<dynamic> _categories = [];
  List<dynamic> _priorities = [];
  List<dynamic> _existingTickets = [];
  int? _currentAreaId;
  String _status = '';
  int? _deptConcernId;
  String _issueType = '';
  int? _categoryId;
  int? _priorityId;
  String _dueDate = '';
  List<String> _documentation = [];
  bool _loading = true;
  bool _loadingTickets = false;
  bool _saving = false;
  Timer? _autoSaveTimer;
  bool _dirty = false;

  int get _currentIndex {
    if (_currentAreaId == null) return -1;
    return _areas.indexWhere((a) => _areaId(a) == _currentAreaId);
  }

  int _areaId(dynamic area) => ((area as Map)['id'] as num).toInt();

  Map<String, dynamic>? get _currentArea {
    if (_currentAreaId == null) return null;
    for (final a in _areas) {
      if (_areaId(a) == _currentAreaId) return a as Map<String, dynamic>;
    }
    return null;
  }

  String get _currentAreaName => _currentArea?['nama_area']?.toString() ?? 'Pilih area';

  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex >= 0 && _currentIndex < _areas.length - 1;

  int? get _outletId => (_report?['outlet_id'] as num?)?.toInt();

  String get _proposedTicketTitle {
    final problem = _finding.text.trim();
    if (problem.isEmpty || _currentArea == null) return '';
    return '${_currentArea!['nama_area']} - $problem';
  }

  bool get _willCreateTicket =>
      _status == 'NG' && _deptConcernId != null && _categoryId != null && _priorityId != null;

  bool get _allAreasCompleted {
    final completed = (_report?['report_areas'] as List?)?.length ?? 0;
    return _areas.isNotEmpty && completed >= _areas.length;
  }

  List<Map<String, dynamic>> get _duplicateTickets => _existingTickets
      .cast<Map<String, dynamic>>()
      .where((t) => t['is_same_title'] == true)
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_dirty && _currentAreaId != null) _autoSave(silent: true);
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _finding.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _svc.getInspectData(widget.reportId);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), behavior: SnackBarBehavior.floating));
      return;
    }
    final report = res['daily_report'] as Map<String, dynamic>;
    final areas = res['areas'] as List<dynamic>? ?? [];
    final keepId = _currentAreaId;
    setState(() {
      _report = report;
      _areas = areas;
      _divisions = res['divisions'] as List<dynamic>? ?? [];
      _categories = res['categories'] as List<dynamic>? ?? [];
      _priorities = res['priorities'] as List<dynamic>? ?? [];
      _loading = false;
    });
    if (areas.isEmpty) return;
    if (keepId != null && areas.any((a) => _areaId(a) == keepId)) {
      _selectArea(keepId, reloadOnly: true);
    } else {
      _selectArea(_areaId(areas.first));
    }
  }

  void _selectArea(int id, {bool reloadOnly = false}) {
    if (!reloadOnly && _dirty && _currentAreaId != null) {
      _autoSave(silent: true);
    }
    final saved = (_report?['report_areas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => (a['area_id'] as num?)?.toInt() == id)
        .toList();
    if (saved.isNotEmpty) {
      final s = saved.first;
      _status = s['status']?.toString() ?? '';
      _finding.text = s['finding_problem']?.toString() ?? '';
      _deptConcernId = (s['dept_concern_id'] as num?)?.toInt();
      _documentation = (s['documentation'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    } else {
      final progress = (_report?['progress'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final p = progress.where((x) => (x['area_id'] as num?)?.toInt() == id).toList();
      if (p.isNotEmpty && p.first['form_data'] is Map) {
        final fd = p.first['form_data'] as Map<String, dynamic>;
        _status = fd['status']?.toString() ?? '';
        _finding.text = fd['finding_problem']?.toString() ?? '';
        _deptConcernId = (fd['dept_concern_id'] as num?)?.toInt();
        _documentation = (fd['documentation'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      } else {
        _status = '';
        _finding.clear();
        _deptConcernId = null;
        _documentation = [];
      }
    }
    setState(() {
      _currentAreaId = id;
      _dirty = false;
      _issueType = '';
      _categoryId = null;
      _priorityId = null;
      _dueDate = '';
      _existingTickets = [];
    });
    if (_status == 'NG') {
      _loadExistingTickets();
    }
  }

  Future<void> _loadExistingTickets() async {
    if (_currentAreaId == null || _status != 'NG' || _outletId == null) {
      if (mounted) setState(() => _existingTickets = []);
      return;
    }

    setState(() => _loadingTickets = true);
    final title = _proposedTicketTitle;
    final res = await _ticketSvc.getTicketsByArea(
      _currentAreaId!,
      outletId: _outletId!,
      title: title.isEmpty ? null : title,
    );
    if (!mounted) return;
    setState(() {
      _loadingTickets = false;
      _existingTickets = res['tickets'] as List<dynamic>? ?? [];
    });
  }

  Map<String, dynamic>? _findCategoryByIssueType(String type) {
    final normalized = type.toLowerCase().replaceAll('_', ' ').trim();
    for (final c in _categories) {
      final m = c as Map<String, dynamic>;
      final name = (m['name']?.toString() ?? '').toLowerCase();
      if (normalized == 'defect' && name.contains('defect')) return m;
      if (normalized == 'ops issue' && (name.contains('ops issue') || name.contains('ops') || name.contains('operation'))) {
        return m;
      }
    }
    return null;
  }

  void _onIssueTypeChanged(String? type) {
    setState(() {
      _issueType = type ?? '';
      final matched = _findCategoryByIssueType(_issueType);
      _categoryId = matched != null ? (matched['id'] as num).toInt() : null;
      _dirty = true;
    });
  }

  void _onPriorityChanged(int? id) {
    setState(() {
      _priorityId = id;
      _dueDate = '';
      if (id != null) {
        for (final p in _priorities) {
          final m = p as Map<String, dynamic>;
          if ((m['id'] as num).toInt() == id) {
            final maxDays = (m['max_days'] as num?)?.toInt();
            if (maxDays != null) {
              final d = DateTime.now().add(Duration(days: maxDays));
              _dueDate =
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            }
            break;
          }
        }
      }
      _dirty = true;
    });
  }

  Map<String, dynamic>? _selectedPriority() {
    if (_priorityId == null) return null;
    for (final p in _priorities) {
      final m = p as Map<String, dynamic>;
      if ((m['id'] as num).toInt() == _priorityId) return m;
    }
    return null;
  }

  void _goPrevious() {
    if (!_hasPrevious) return;
    _selectArea(_areaId(_areas[_currentIndex - 1]));
  }

  void _goNext() {
    if (!_hasNext) return;
    _selectArea(_areaId(_areas[_currentIndex + 1]));
  }

  Map<String, dynamic> _payload() => {
        'area_id': _currentAreaId,
        'status': _status.isEmpty ? null : _status,
        'finding_problem': _finding.text.trim(),
        'dept_concern_id': _deptConcernId,
        'documentation': _documentation,
      };

  Future<void> _autoSave({bool silent = false}) async {
    if (_currentAreaId == null) return;
    final res = await _svc.autoSave(widget.reportId, _payload());
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _dirty = false);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Auto-save gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _saveArea({bool goNext = false}) async {
    if (_currentAreaId == null || _status.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih status G / NG / NA'), behavior: SnackBarBehavior.floating));
      return;
    }

    if (_willCreateTicket) {
      await _loadExistingTickets();
      if (!mounted) return;
      if (_duplicateTickets.isNotEmpty) {
        final duplicateList = _duplicateTickets
            .map((t) => '• ${t['ticket_number']} — ${t['title']}')
            .join('\n');
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Ticket dengan judul sama sudah ada'),
            content: Text(
              'Area dan outlet ini sudah memiliki ticket open dengan judul serupa:\n\n$duplicateList\n\nLanjutkan membuat ticket baru?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tetap buat')),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    setState(() => _saving = true);
    final payload = Map<String, dynamic>.from(_payload());
    if (_willCreateTicket) {
      payload['create_ticket'] = true;
      payload['ticket_data'] = {
        'title': _proposedTicketTitle,
        'description': _finding.text.trim(),
        'category_id': _categoryId,
        'priority_id': _priorityId,
        'divisi_id': _deptConcernId,
        'due_date': _dueDate.isEmpty ? null : _dueDate,
        'issue_type': _issueType.isEmpty ? null : _issueType,
      };
    }

    final res = await _svc.saveArea(widget.reportId, payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      var msg = 'Area disimpan';
      if (res['ticket_created'] == true) {
        msg += '\nTicket berhasil dibuat.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
      if (res['ticket_created'] == true) {
        _issueType = '';
        _categoryId = null;
        _priorityId = null;
        _dueDate = '';
      }
      await _load();
      if (goNext && _hasNext) {
        _goNext();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _skipArea() async {
    if (_currentAreaId == null) return;
    setState(() => _saving = true);
    final res = await _svc.skipArea(widget.reportId, _currentAreaId!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      await _load();
      if (_hasNext) {
        _goNext();
      } else if (_hasPrevious) {
        _goPrevious();
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_documentation.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimal 5 foto'), behavior: SnackBarBehavior.floating));
      return;
    }
    final x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    setState(() => _saving = true);
    final res = await _svc.uploadDocumentation(File(x.path));
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      final url = (res['data'] as Map?)?['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        setState(() {
          _documentation.add(url);
          _dirty = true;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Upload gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Selesai Inspeksi?'),
        content: const Text('Lanjut ke form post-inspection.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjut')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _svc.completeInspection(widget.reportId);
    if (!mounted) return;
    if (res['success'] == true) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DailyReportPostInspectionScreen(reportId: widget.reportId)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  bool _areaDone(int areaId) {
    return _areaInspectionStatus(areaId) != null;
  }

  /// Returns G, NG, NA for saved areas; 'skipped' if skipped; null if not yet inspected.
  String? _areaInspectionStatus(int areaId) {
    if (_areaSkipped(areaId)) return 'skipped';

    final reportAreas = (_report?['report_areas'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final ra in reportAreas) {
      if ((ra['area_id'] as num?)?.toInt() == areaId) {
        return ra['status']?.toString();
      }
    }
    return null;
  }

  ({Color color, Color bg, String label}) _statusStyle(String status) {
    switch (status) {
      case 'G':
        return (color: DrColors.success, bg: const Color(0xFFDCFCE7), label: 'G');
      case 'NG':
        return (color: DrColors.danger, bg: const Color(0xFFFEE2E2), label: 'NG');
      case 'NA':
        return (color: DrColors.warning, bg: const Color(0xFFFFEDD5), label: 'NA');
      case 'skipped':
        return (color: DrColors.textSecondary, bg: const Color(0xFFF1F5F9), label: 'Skip');
      default:
        return (color: DrColors.textSecondary, bg: const Color(0xFFF1F5F9), label: status);
    }
  }

  Widget _inspectionStatusBadge(String status) {
    final s = _statusStyle(status);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: s.bg, shape: BoxShape.circle, border: Border.all(color: s.color.withValues(alpha: 0.35))),
      child: Text(s.label, style: TextStyle(fontSize: status.length <= 2 ? 13 : 10, fontWeight: FontWeight.w800, color: s.color)),
    );
  }

  bool _areaSkipped(int areaId) {
    final progress = (_report?['progress'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return progress.any((p) =>
        (p['area_id'] as num?)?.toInt() == areaId &&
        (p['progress_status']?.toString() == 'skipped' || p['status']?.toString() == 'skipped'));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Inspeksi', body: Center(child: AppLoadingIndicator()));
    }
    final outlet = _report?['outlet'] is Map ? (_report!['outlet'] as Map)['nama_outlet']?.toString() : '';
    final completed = (_report?['report_areas'] as List?)?.length ?? 0;
    final total = _areas.length;
    final progressPct = total > 0 ? completed / total : 0.0;
    final areaNum = _currentIndex >= 0 ? _currentIndex + 1 : 0;

    return AppScaffold(
      title: 'Inspeksi',
      body: Container(
        color: DrColors.surface,
        child: Column(
          children: [
            _buildHeader(outlet ?? '', areaNum, total, progressPct, completed),
            Expanded(child: _currentAreaId == null ? const Center(child: Text('Tidak ada area')) : _form()),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String outlet, int areaNum, int total, double progressPct, int completed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: DrColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(outlet, style: const TextStyle(fontSize: 12, color: DrColors.textSecondary, fontWeight: FontWeight.w500)),
                ),
                InkWell(
                  onTap: _showAreaSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$completed/$total selesai', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DrColors.primary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.unfold_more_rounded, size: 18, color: DrColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _hasPrevious && !_saving ? _goPrevious : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Area sebelumnya',
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _currentAreaName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: DrColors.textPrimary, height: 1.2),
                      ),
                      if (areaNum > 0) ...[
                        const SizedBox(height: 4),
                        Text('Area $areaNum dari $total', style: const TextStyle(fontSize: 12, color: DrColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _hasNext && !_saving ? _goNext : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Area berikutnya',
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPct,
                minHeight: 5,
                backgroundColor: DrColors.primaryLight,
                color: DrColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAreaSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DrColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, scroll) => Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: DrColors.border, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Daftar Area', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DrColors.textPrimary)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: _areas.length,
                  itemBuilder: (_, i) {
                    final a = _areas[i] as Map<String, dynamic>;
                    final id = _areaId(a);
                    final inspectionStatus = _areaInspectionStatus(id);
                    final active = _currentAreaId == id;
                    final hasResult = inspectionStatus != null && inspectionStatus != 'skipped';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: active ? DrColors.primaryLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            _selectArea(id);
                            Navigator.pop(sheetCtx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: active ? DrColors.primary.withValues(alpha: 0.4) : DrColors.border),
                            ),
                            child: Row(
                              children: [
                                if (inspectionStatus != null)
                                  _inspectionStatusBadge(inspectionStatus)
                                else
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: DrColors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: DrColors.border),
                                    ),
                                    child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DrColors.textSecondary)),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['nama_area']?.toString() ?? '',
                                        style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: DrColors.textPrimary),
                                      ),
                                      if (hasResult) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          inspectionStatus == 'G'
                                              ? 'Good'
                                              : inspectionStatus == 'NG'
                                                  ? 'Not Good'
                                                  : 'Not Available',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusStyle(inspectionStatus).color),
                                        ),
                                      ] else if (inspectionStatus == 'skipped') ...[
                                        const SizedBox(height: 3),
                                        Text('Di-skip', style: TextStyle(fontSize: 11, color: _statusStyle('skipped').color)),
                                      ],
                                    ],
                                  ),
                                ),
                                if (active) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DrColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _form() {
    final showTicketForm = _deptConcernId != null && _finding.text.trim().isNotEmpty;
    final priority = _selectedPriority();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Status *', style: TextStyle(fontWeight: FontWeight.w700, color: DrColors.textPrimary)),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: 'G', label: Text('G'), icon: Icon(Icons.check, color: Colors.green)),
                    ButtonSegment(value: 'NG', label: Text('NG'), icon: Icon(Icons.close, color: Colors.red)),
                    ButtonSegment(value: 'NA', label: Text('NA'), icon: Icon(Icons.remove, color: Colors.orange)),
                  ],
                  selected: _status.isEmpty ? <String>{} : {_status},
                  onSelectionChanged: (s) {
                    final next = s.isEmpty ? '' : s.first;
                    setState(() {
                      _status = next;
                      _dirty = true;
                      _existingTickets = [];
                    });
                    if (next == 'NG') {
                      _loadExistingTickets();
                    }
                  },
                ),
              ],
            ),
          ),
          if (_status == 'NG') ...[
            const SizedBox(height: 12),
            DailyReportOpenTicketsPanel(
              tickets: _existingTickets,
              loading: _loadingTickets,
              findingProblem: _finding.text,
              areaName: _currentAreaName,
            ),
          ],
          const SizedBox(height: 12),
          DrSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _finding,
                  decoration: drInputDecoration('Finding / Problem'),
                  maxLines: 3,
                  onChanged: (_) {
                    setState(() => _dirty = true);
                    if (_status == 'NG') _loadExistingTickets();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  value: _deptConcernId,
                  decoration: drInputDecoration('Dept Concern'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-')),
                    ..._divisions.map((d) {
                      final m = d as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: (m['id'] as num).toInt(),
                        child: Text(m['nama_divisi']?.toString() ?? '', overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _deptConcernId = v;
                      _dirty = true;
                    });
                    if (_status == 'NG') _loadExistingTickets();
                  },
                ),
              ],
            ),
          ),
          if (showTicketForm) ...[
            const SizedBox(height: 12),
            DrSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.confirmation_number_outlined, color: DrColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Buat Ticket dari Issue Ini', style: TextStyle(fontWeight: FontWeight.w800, color: DrColors.primary)),
                    ],
                  ),
                  if (_proposedTicketTitle.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DrColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: DrColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('JUDUL TICKET YANG AKAN DIBUAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DrColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(_proposedTicketTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _issueType.isEmpty ? null : _issueType,
                    decoration: drInputDecoration('Jenis Issue'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('-')),
                      DropdownMenuItem(value: 'defect', child: Text('Defect')),
                      DropdownMenuItem(value: 'ops_issue', child: Text('Ops Issue')),
                    ],
                    onChanged: _onIssueTypeChanged,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _categoryId,
                    decoration: drInputDecoration('Category'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-')),
                      ..._categories.map((c) {
                        final m = c as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: (m['id'] as num).toInt(),
                          child: Text(m['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() {
                      _categoryId = v;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _priorityId,
                    decoration: drInputDecoration('Priority'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-')),
                      ..._priorities.map((p) {
                        final m = p as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: (m['id'] as num).toInt(),
                          child: Text(m['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: _onPriorityChanged,
                  ),
                  if (priority != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DrColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Max Days: ${priority['max_days'] ?? '-'} hari',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DrColors.primary),
                      ),
                    ),
                  ],
                  if (_dueDate.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _dueDate,
                      readOnly: true,
                      decoration: drInputDecoration('Due Date', icon: Icons.event),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          DrSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Dokumentasi (max 5)', style: TextStyle(fontWeight: FontWeight.w700, color: DrColors.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._documentation.map((url) => Stack(
                          children: [
                            drDocumentationThumbnail(
                              context,
                              rawUrl: url,
                              allUrls: _documentation,
                              size: 76,
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _documentation.remove(url);
                                  _dirty = true;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        )),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(backgroundColor: DrColors.primaryLight, foregroundColor: DrColors.primary),
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                    ),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(backgroundColor: DrColors.primaryLight, foregroundColor: DrColors.primary),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final btnHeight = 48.0;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DrColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: btnHeight,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DrColors.primary,
                        foregroundColor: Colors.white,
                        shape: btnShape,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onPressed: _saving ? null : () => _saveArea(goNext: false),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: btnHeight,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: DrColors.primaryLight,
                        foregroundColor: DrColors.primary,
                        shape: btnShape,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onPressed: _saving ? null : () => _saveArea(goNext: true),
                      child: const Text('Simpan & Next'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: btnHeight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: btnShape,
                  side: const BorderSide(color: DrColors.border),
                  foregroundColor: DrColors.textSecondary,
                ),
                onPressed: _saving ? null : _skipArea,
                icon: const Icon(Icons.skip_next_rounded, size: 20),
                label: const Text('Skip Area', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _allAreasCompleted ? _complete : null,
              child: Text(
                _allAreasCompleted
                    ? 'Selesai Inspeksi → Post Inspection'
                    : 'Selesai inspeksi (simpan semua area dulu)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _allAreasCompleted ? DrColors.primary : DrColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
