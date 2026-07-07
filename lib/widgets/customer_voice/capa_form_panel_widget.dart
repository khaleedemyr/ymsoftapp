import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/customer_voice_command_center_service.dart';
import 'capa_display_helpers.dart';
import 'capa_json_helpers.dart';
import 'notify_user_multi_picker.dart';

class _CapaApproverPick {
  const _CapaApproverPick({required this.id, required this.name});

  final int id;
  final String name;
}

/// Mirrors web `CapaFormPanel.vue`: 4 sections, evidence, approval on save.
class CapaFormPanelWidget extends StatefulWidget {
  const CapaFormPanelWidget({
    super.key,
    required this.caseId,
    required this.caseRow,
    required this.assignees,
    this.authUser,
    this.onChanged,
  });

  final int caseId;
  final Map<String, dynamic> caseRow;
  final List<CustomerVoiceOption> assignees;
  final Map<String, dynamic>? authUser;
  final VoidCallback? onChanged;

  @override
  State<CapaFormPanelWidget> createState() => _CapaFormPanelWidgetState();
}

class _CapaFormPanelWidgetState extends State<CapaFormPanelWidget> {
  final CustomerVoiceCommandCenterService _service =
      CustomerVoiceCommandCenterService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _approverSearchCtrl = TextEditingController();
  final TextEditingController _approvalCommentsCtrl = TextEditingController();

  late Map<String, Map<String, dynamic>> _divisionDrafts;
  late String _activeDivision;
  late Map<String, Map<String, dynamic>> _approvalSummaries;
  final Map<String, List<_CapaApproverPick>> _divisionApproverDrafts = {
    'service': [],
    'kitchen': [],
    'bar': [],
  };

  List<_CapaApproverPick> _selectedApprovers = [];
  List<Map<String, dynamic>> _approverResults = [];
  bool _showApproverResults = false;
  bool _saving = false;
  bool _uploadingEvidence = false;
  bool _actingApproval = false;
  int _approverSearchToken = 0;

  Map<String, dynamic> get _local => _divisionDrafts[_activeDivision]!;

  @override
  void initState() {
    super.initState();
    _approverSearchCtrl.addListener(_onApproverSearchChanged);
    _hydrateDrafts();
  }

  @override
  void dispose() {
    _approverSearchCtrl.removeListener(_onApproverSearchChanged);
    _approverSearchCtrl.dispose();
    _approvalCommentsCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CapaFormPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseRow != widget.caseRow || oldWidget.caseId != widget.caseId) {
      _hydrateDrafts();
    }
  }

  void _hydrateDrafts() {
    final row = widget.caseRow;
    final active = row['capa_active_division']
                ?.toString()
                .toLowerCase()
                .trim()
                .isNotEmpty ==
            true
        ? row['capa_active_division'].toString().toLowerCase()
        : 'service';

    final single = asStringKeyedMap(row['capa']);
    final byDiv = asStringKeyedMap(row['capa_divisions']);

    _divisionDrafts = {
      'service': ensureCapaShape(),
      'kitchen': ensureCapaShape(),
      'bar': ensureCapaShape(),
    };

    if (byDiv != null) {
      for (final d in ['service', 'kitchen', 'bar']) {
        final x = byDiv[d];
        if (x is Map) {
          _divisionDrafts[d] = ensureCapaShape(asStringKeyedMap(x));
        }
      }
    } else if (single != null) {
      _divisionDrafts[active] = ensureCapaShape(single);
    }

    _applySourceDefaultsAllDivisions();
    _applyReportedByAllDivisions();

    _activeDivision =
        ['service', 'kitchen', 'bar'].contains(active) ? active : 'service';

    final uid = int.tryParse('${widget.authUser?['id'] ?? 0}') ?? 0;
    if (uid > 0) {
      for (final d in _divisionDrafts.keys) {
        final m = _divisionDrafts[d]!;
        final e = asStringKeyedMap(m['e']) ?? {};
        final f = asStringKeyedMap(m['f']) ?? {};
        e['pic_user_id'] ??= uid;
        f['pic_user_id'] ??= uid;
        m['e'] = e;
        m['f'] = f;
      }
    }

    _approvalSummaries = _loadApprovalSummariesFromRow(row);
    _divisionApproverDrafts.updateAll((_, __) => []);
    _selectedApprovers = [];
  }

  Map<String, Map<String, dynamic>> _loadApprovalSummariesFromRow(
    Map<String, dynamic> row,
  ) {
    final raw = asStringKeyedMap(row['capa_division_approval']);
    final out = <String, Map<String, dynamic>>{};
    for (final div in ['service', 'kitchen', 'bar']) {
      final item = raw != null ? asStringKeyedMap(raw[div]) : null;
      out[div] = {
        ...emptyCapaApprovalSummary(),
        if (item != null) ...item,
      };
    }
    return out;
  }

  Map<String, dynamic> _activeApprovalSummary() {
    return _approvalSummaries[_activeDivision] ?? emptyCapaApprovalSummary();
  }

  bool get _canManageApprovers {
    final s = _activeApprovalSummary()['state']?.toString() ?? 'none';
    final canResubmit = _activeApprovalSummary()['can_resubmit'] == true;
    return s == 'none' || s == 'rejected' || canResubmit;
  }

  bool get _pendingApproverSelf {
    final uid = int.tryParse('${widget.authUser?['id'] ?? 0}') ?? 0;
    if (uid <= 0) return false;
    final summary = _activeApprovalSummary();
    return summary['state']?.toString() == 'pending' &&
        int.tryParse('${summary['next_approver_id'] ?? 0}') == uid;
  }

  ({String namaLengkap, String namaJabatan})? _capaReporterUser() {
    final csId =
        int.tryParse('${widget.caseRow['assigned_to'] ?? 0}') ?? 0;
    if (csId > 0) {
      final merged = _assigneesMergedWithAuth();
      for (final a in merged) {
        if (a.id == csId) {
          return (
            namaLengkap: a.label,
            namaJabatan: a.subtitle?.trim() ?? '',
          );
        }
      }
    }
    final name = widget.caseRow['assigned_to_name']?.toString().trim() ?? '';
    final jabatan =
        widget.caseRow['assigned_to_jabatan']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      return (namaLengkap: name, namaJabatan: jabatan);
    }
    return null;
  }

  void _applyReportedBy(Map<String, dynamic> merged) {
    final reporter = _capaReporterUser();
    if (reporter == null) return;
    final a = asStringKeyedMap(merged['a']) ?? {};
    a['reported_by'] = reporter.namaLengkap;
    a['reported_by_position'] =
        reporter.namaJabatan.isNotEmpty ? reporter.namaJabatan : null;
    merged['a'] = a;
  }

  void _applyReportedByAllDivisions() {
    for (final d in _divisionDrafts.keys) {
      _applyReportedBy(_divisionDrafts[d]!);
    }
  }

  void _applySourceDefaultsAllDivisions() {
    final topics = (widget.caseRow['topics'] as List<dynamic>?) ?? [];
    final types = _topicKeysFromSource(topics);
    final desc = widget.caseRow['raw_text']?.toString().trim() ?? '';
    final channel = _sourceChannelValue();

    for (final d in _divisionDrafts.keys) {
      final merged = _divisionDrafts[d]!;
      final b = asStringKeyedMap(merged['b']) ?? {};
      b['types'] = types;
      b['types_other'] = null;
      b['description'] = desc.isEmpty ? null : desc;
      merged['b'] = b;

      final a = asStringKeyedMap(merged['a']) ?? {};
      a['channel'] = channel;
      if (channel != null) {
        a['channel_other'] =
            sourceLabelFromType(widget.caseRow['source_type']?.toString());
      }
      merged['a'] = a;
    }
  }

  String? _sourceChannelValue() {
    final s = widget.caseRow['source_type']?.toString().toLowerCase() ?? '';
    if (s == 'google_review') return 'google_review';
    if (s == 'instagram_comment') return 'instagram_comment';
    if (s == 'guest_comment') return 'guest_comment';
    return null;
  }

  List<String> _topicKeysFromSource(List<dynamic> topics) {
    const keyMap = {
      'food_quality': 'food_quality',
      'service': 'service',
      'hygiene': 'cleanliness',
      'cleanliness': 'cleanliness',
      'wait_time': 'waiting_time',
      'waiting_time': 'waiting_time',
      'speed_wait_time': 'waiting_time',
      'billing': 'billing',
      'price': 'billing',
      'price_value': 'billing',
      'other': 'other',
    };
    final out = <String>[];
    final seen = <String>{};
    for (final t in topics) {
      final k = t.toString().toLowerCase().trim();
      if (k.isEmpty) continue;
      final mapped = keyMap[k] ?? 'other';
      if (seen.contains(mapped)) continue;
      seen.add(mapped);
      out.add(mapped);
    }
    return out.isEmpty ? ['other'] : out;
  }

  bool _divisionFilled(String div) {
    final draft = _divisionDrafts[div];
    if (draft == null) return false;
    final empty = jsonEncode(ensureCapaShape());
    return jsonEncode(ensureCapaShape(draft)) != empty;
  }

  void _onApproverSearchChanged() {
    final token = ++_approverSearchToken;
    final q = _approverSearchCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _approverResults = [];
        _showApproverResults = false;
      });
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted || token != _approverSearchToken) return;
      try {
        final users = await _service.searchCapaApprovers(q);
        if (!mounted || token != _approverSearchToken) return;
        setState(() {
          _approverResults = users;
          _showApproverResults = users.isNotEmpty;
        });
      } catch (_) {
        if (!mounted || token != _approverSearchToken) return;
        setState(() {
          _approverResults = [];
          _showApproverResults = false;
        });
      }
    });
  }

  void _addApprover(Map<String, dynamic> user) {
    final id = int.tryParse('${user['id'] ?? 0}') ?? 0;
    if (id <= 0) return;
    if (_selectedApprovers.any((a) => a.id == id)) return;
    final name = user['name']?.toString().trim().isNotEmpty == true
        ? user['name'].toString()
        : 'User #$id';
    setState(() {
      _selectedApprovers = [
        ..._selectedApprovers,
        _CapaApproverPick(id: id, name: name),
      ];
      _approverSearchCtrl.clear();
      _approverResults = [];
      _showApproverResults = false;
    });
  }

  void _removeApprover(int index) {
    setState(() {
      _selectedApprovers = List<_CapaApproverPick>.from(_selectedApprovers)
        ..removeAt(index);
    });
  }

  void _reorderApprover(int from, int to) {
    if (to < 0 || to >= _selectedApprovers.length) return;
    setState(() {
      final list = List<_CapaApproverPick>.from(_selectedApprovers);
      final item = list.removeAt(from);
      list.insert(to, item);
      _selectedApprovers = list;
    });
  }

  Future<void> _save() async {
    _applyReportedBy(_local);
    final capa = ensureCapaShape(Map<String, dynamic>.from(_local));
    _divisionDrafts[_activeDivision] = capa;
    _divisionApproverDrafts[_activeDivision] =
        List<_CapaApproverPick>.from(_selectedApprovers);

    final approverIds = _canManageApprovers && _selectedApprovers.isNotEmpty
        ? _selectedApprovers.map((a) => a.id).toList()
        : null;

    setState(() => _saving = true);
    try {
      final message = await _service.saveCapa(
        caseId: widget.caseId,
        capa: capa,
        capaDivision: _activeDivision,
        approvers: approverIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _actApproval(bool approved) async {
    setState(() => _actingApproval = true);
    try {
      final summary = await _service.approveCapaDivision(
        caseId: widget.caseId,
        division: _activeDivision,
        approved: approved,
        comments: _approvalCommentsCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _approvalSummaries[_activeDivision] = summary;
        _approvalCommentsCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'CAPA disetujui' : 'CAPA ditolak'),
        ),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _actingApproval = false);
    }
  }

  Future<void> _pickEvidence(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (file == null) return;
    setState(() => _uploadingEvidence = true);
    try {
      final item = await _service.uploadCapaEvidence(
        caseId: widget.caseId,
        filePath: file.path,
      );
      final loc = ensureCapaShape(Map<String, dynamic>.from(_local));
      final ev = (loc['evidence'] as List<dynamic>?) ?? [];
      ev.add(item);
      loc['evidence'] = ev;
      setState(() {
        _divisionDrafts[_activeDivision] = loc;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lampiran berhasil diunggah'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<void> _deleteEvidence(String evidenceId) async {
    try {
      await _service.deleteCapaEvidence(
        caseId: widget.caseId,
        evidenceId: evidenceId,
      );
      final loc = ensureCapaShape(Map<String, dynamic>.from(_local));
      final ev = (loc['evidence'] as List<dynamic>?) ?? [];
      loc['evidence'] = ev.where((x) {
        if (x is Map && '${x['id']}' != evidenceId) return true;
        return false;
      }).toList();
      setState(() => _divisionDrafts[_activeDivision] = loc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _switchDivision(String div) {
    if (!['service', 'kitchen', 'bar'].contains(div)) return;
    setState(() {
      _divisionDrafts[_activeDivision] =
          ensureCapaShape(Map<String, dynamic>.from(_local));
      _divisionApproverDrafts[_activeDivision] =
          List<_CapaApproverPick>.from(_selectedApprovers);
      _activeDivision = div;
      _selectedApprovers =
          List<_CapaApproverPick>.from(_divisionApproverDrafts[div] ?? []);
      _approverSearchCtrl.clear();
      _approverResults = [];
      _showApproverResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey<String>('capa-form-${widget.caseId}-$_activeDivision'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerIntro(),
        const SizedBox(height: 12),
        _activeDivisionBadge(),
        const SizedBox(height: 12),
        _divisionListCap(),
        if (_pendingApproverSelf) ...[
          const SizedBox(height: 12),
          _pendingApprovalBanner(),
        ],
        const SizedBox(height: 16),
        _sectionGeneralInfo(),
        _sectionIssueDetails(),
        _sectionEvidence(),
        _sectionActionTaken(),
        _sectionPreventive(),
        _sectionApproval(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Simpan form CAPA'),
          ),
        ),
      ],
    );
  }

  Widget _headerIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORM CAPA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Customer Complaint — Corrective & Preventive Action',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Isi per divisi (Service / Kitchen / Bar). Approval diajukan otomatis saat simpan jika approver dipilih.',
            style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _activeDivisionBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIVISI CAPA AKTIF',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            divisionLabel(_activeDivision),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF312E81),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingApprovalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFEEF2FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Text(
        'CAPA divisi ${divisionLabel(_activeDivision)} menunggu approval Anda.',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4C1D95),
        ),
      ),
    );
  }

  Widget _divisionListCap() {
    return _card(
      'List CAPA',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tidak wajib semua divisi terisi.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ...['service', 'kitchen', 'bar'].map((id) {
            final filled = _divisionFilled(id);
            final active = _activeDivision == id;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFEEF2FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? const Color(0xFF818CF8)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          divisionLabel(id),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          filled ? 'Sudah ada data CAPA' : 'Belum ada data CAPA',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _switchDivision(id),
                    child: Text(active ? 'Editing' : 'Show/Edit'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionGeneralInfo() {
    final a = asStringKeyedMap(_local['a']) ?? {};
    final outlet = widget.caseRow['nama_outlet']?.toString().trim() ?? '';
    final channel = sourceLabelFromType(
      widget.caseRow['source_type']?.toString(),
    );

    return _card(
      '1. General Information',
      Column(
        children: [
          _dateField('Date', a['complaint_date']?.toString(), (v) {
            final m = asStringKeyedMap(_local['a']) ?? {};
            m['complaint_date'] = v;
            setState(() => _divisionDrafts[_activeDivision]!['a'] = m);
          }),
          _timeField('Time', a['complaint_time']?.toString(), (v) {
            final m = asStringKeyedMap(_local['a']) ?? {};
            m['complaint_time'] = v;
            setState(() => _divisionDrafts[_activeDivision]!['a'] = m);
          }),
          _readonlyTile('Outlet Name', outlet.isEmpty ? '—' : outlet),
          _readonlyTile('Location / Channel', channel),
          _readonlyField('Reported By', a['reported_by']?.toString() ?? '—'),
          _readonlyField(
            'Position',
            a['reported_by_position']?.toString() ?? '—',
          ),
        ],
      ),
    );
  }

  Widget _sectionIssueDetails() {
    final b = asStringKeyedMap(_local['b']) ?? {};
    final types = ((b['types'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    final involvedIds = capaUserIdList(b['involved_party_user_ids']);
    final witnessIds = capaUserIdList(b['witness_user_ids']);
    final merged = _assigneesMergedWithAuth();

    return _card(
      '2. Issue Details',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type of Issue',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: complaintTypeMap.keys.map((k) {
              final sel = types.contains(k);
              return FilterChip(
                label: Text(
                  complaintTypeLabel(k),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: sel,
                onSelected: (v) {
                  final next = List<String>.from(types);
                  if (v) {
                    if (!next.contains(k)) next.add(k);
                  } else {
                    next.remove(k);
                  }
                  final m = asStringKeyedMap(_local['b']) ?? {};
                  m['types'] = next;
                  setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _multiline('Description', b['description']?.toString(), (v) {
            final m = asStringKeyedMap(_local['b']) ?? {};
            m['description'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
          }),
          _textField('Area / Section', b['area_section']?.toString(), (v) {
            final m = asStringKeyedMap(_local['b']) ?? {};
            m['area_section'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
          }),
          CustomerVoiceUserPickerTrigger(
            sectionLabel: 'Involved Parties',
            valueText: customerVoiceRegionalSummary(involvedIds, merged),
            leadingIcon: Icons.groups_outlined,
            onTap: () async {
              final ids = await showCustomerVoiceMultiUserPicker(
                context: context,
                assignees: merged,
                title: 'Pilih pihak terlibat',
                initialSelectedIds: involvedIds,
              );
              if (!mounted || ids == null) return;
              final m = asStringKeyedMap(_local['b']) ?? {};
              m['involved_party_user_ids'] = ids;
              setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
            },
          ),
          const SizedBox(height: 10),
          CustomerVoiceUserPickerTrigger(
            sectionLabel: 'Witness(es)',
            valueText: customerVoiceRegionalSummary(witnessIds, merged),
            leadingIcon: Icons.visibility_outlined,
            onTap: () async {
              final ids = await showCustomerVoiceMultiUserPicker(
                context: context,
                assignees: merged,
                title: 'Pilih saksi',
                initialSelectedIds: witnessIds,
              );
              if (!mounted || ids == null) return;
              final m = asStringKeyedMap(_local['b']) ?? {};
              m['witness_user_ids'] = ids;
              setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionEvidence() {
    final loc = _local;
    final ev = (loc['evidence'] as List<dynamic>?) ?? [];
    return _card(
      'Lampiran bukti & dokumen',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maks. 20 file, per file ±15 MB.',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _uploadingEvidence || ev.length >= 20
                    ? null
                    : () => _pickEvidence(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Ambil foto'),
              ),
              OutlinedButton.icon(
                onPressed: _uploadingEvidence || ev.length >= 20
                    ? null
                    : () => _pickEvidence(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Pilih file / galeri'),
              ),
            ],
          ),
          if (_uploadingEvidence)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (ev.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Belum ada lampiran.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          ...ev.map((raw) {
            if (raw is! Map) return const SizedBox.shrink();
            final e = raw.map((k, v) => MapEntry(k.toString(), v));
            final id = e['id']?.toString() ?? '';
            final url = e['url']?.toString();
            final name = e['original_name']?.toString() ?? 'file';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: url != null && isImageEvidence(e)
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const Icon(Icons.attach_file),
              title: GestureDetector(
                onTap: url != null ? () => _openUrl(url) : null,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 13,
                  ),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                onPressed: id.isEmpty ? null : () => _deleteEvidence(id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionActionTaken() {
    final c = asStringKeyedMap(_local['c']) ?? {};
    final e = asStringKeyedMap(_local['e']) ?? {};
    final actions = ((c['actions'] as List<dynamic>?) ?? [])
        .map((x) => x.toString())
        .toList();
    const opts = [
      'apology',
      'replace_product',
      'refund_discount',
      'escalate',
      'other',
    ];
    final status = e['status']?.toString() ?? 'open';

    return _card(
      '3. Action Taken',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Immediate Action',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: opts.map((k) {
              final sel = actions.contains(k);
              return FilterChip(
                label: Text(
                  immediateActionLabel(k),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: sel,
                onSelected: (v) {
                  final next = List<String>.from(actions);
                  if (v) {
                    if (!next.contains(k)) next.add(k);
                  } else {
                    next.remove(k);
                  }
                  final m = asStringKeyedMap(_local['c']) ?? {};
                  m['actions'] = next;
                  setState(() => _divisionDrafts[_activeDivision]!['c'] = m);
                },
              );
            }).toList(),
          ),
          if (actions.contains('other')) ...[
            const SizedBox(height: 8),
            _textField('Lainnya', c['actions_other']?.toString(), (v) {
              final m = asStringKeyedMap(_local['c']) ?? {};
              m['actions_other'] = v.isEmpty ? null : v;
              setState(() => _divisionDrafts[_activeDivision]!['c'] = m);
            }),
          ],
          const SizedBox(height: 12),
          _multiline('Follow-Up Action', e['action']?.toString(), (v) {
            final m = asStringKeyedMap(_local['e']) ?? {};
            m['action'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
          }),
          DropdownButtonFormField<String>(
            value: ['open', 'on_progress', 'closed'].contains(status)
                ? status
                : 'open',
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(
                value: 'on_progress',
                child: Text('On Progress'),
              ),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
            ],
            onChanged: (v) {
              final m = asStringKeyedMap(_local['e']) ?? {};
              m['status'] = v ?? 'open';
              setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
            },
          ),
          const SizedBox(height: 8),
          _picDropdown(
            e['pic_user_id'],
            'Follow Up By',
            (uid) {
              final m = asStringKeyedMap(_local['e']) ?? {};
              m['pic_user_id'] = uid;
              setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionPreventive() {
    final f = asStringKeyedMap(_local['f']) ?? {};
    return _card(
      '4. Preventive Measures',
      Column(
        children: [
          _multiline('Corrective Action Plan', f['action']?.toString(), (v) {
            final m = asStringKeyedMap(_local['f']) ?? {};
            m['action'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
          }),
          _picDropdown(
            f['pic_user_id'],
            'Responsible Person',
            (uid) {
              final m = asStringKeyedMap(_local['f']) ?? {};
              m['pic_user_id'] = uid;
              setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
            },
          ),
          _dateField(
            'Target Completion Date',
            f['timeline']?.toString(),
            (v) {
              final m = asStringKeyedMap(_local['f']) ?? {};
              m['timeline'] = v;
              setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionApproval() {
    final summary = _activeApprovalSummary();
    final flows = (summary['flows'] as List<dynamic>?) ?? [];

    return _card(
      'Approval',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih approver berurutan (level 1 → terakhir). Approval diajukan otomatis saat klik Simpan form CAPA.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          if (flows.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...flows.map((raw) {
              if (raw is! Map) return const SizedBox.shrink();
              final flow = raw.map((k, v) => MapEntry(k.toString(), v));
              final level = flow['approval_level']?.toString() ?? '?';
              final status = flow['status']?.toString() ?? '';
              final approver = asStringKeyedMap(flow['approver']);
              final approverName = approver?['nama_lengkap']?.toString() ??
                  'User #${flow['approver_id']}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _approvalFlowBg(status),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _approvalFlowBorder(status)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Level $level — $approverName',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (_canManageApprovers) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _approverSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari approver (nama / email / jabatan)…',
                border: const OutlineInputBorder(),
                suffixIcon: _approverSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _approverSearchCtrl.clear(),
                      )
                    : null,
              ),
            ),
            if (_showApproverResults)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _approverResults.map((user) {
                    final name = user['name']?.toString() ?? '';
                    final jabatan = user['jabatan']?.toString();
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: jabatan != null && jabatan.isNotEmpty
                          ? Text(
                              jabatan,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : null,
                      onTap: () => _addApprover(user),
                    );
                  }).toList(),
                ),
              ),
            if (_selectedApprovers.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_selectedApprovers.length, (idx) {
                final ap = _selectedApprovers[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'L${idx + 1} — ${ap.name}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (idx > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed: () => _reorderApprover(idx, idx - 1),
                        ),
                      if (idx < _selectedApprovers.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          onPressed: () => _reorderApprover(idx, idx + 1),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFFB91C1C)),
                        onPressed: () => _removeApprover(idx),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
          if (_pendingApproverSelf) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _approvalCommentsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Komentar (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _actingApproval ? null : () => _actApproval(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                    ),
                    child: _actingApproval
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _actingApproval ? null : () => _actApproval(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _approvalFlowBg(String status) {
    final s = status.toUpperCase();
    if (s == 'APPROVED') return const Color(0xFFECFDF5);
    if (s == 'REJECTED') return const Color(0xFFFFF1F2);
    return const Color(0xFFFFFBEB);
  }

  Color _approvalFlowBorder(String status) {
    final s = status.toUpperCase();
    if (s == 'APPROVED') return const Color(0xFFBBF7D0);
    if (s == 'REJECTED') return const Color(0xFFFECDD3);
    return const Color(0xFFFDE68A);
  }

  List<CustomerVoiceOption> _assigneesMergedWithAuth() {
    return mergeCustomerVoiceAssigneesWithAuth(
      assignees: widget.assignees,
      authUser: widget.authUser,
    );
  }

  String _labelForUserId(int id, List<CustomerVoiceOption> merged) {
    for (final a in merged) {
      if (a.id == id) {
        if (a.subtitle != null && a.subtitle!.trim().isNotEmpty) {
          return '${a.label} · ${a.subtitle}';
        }
        return a.label;
      }
    }
    return 'User #$id';
  }

  Widget _picDropdown(
    dynamic current,
    String label,
    void Function(int?) onPick,
  ) {
    final cur = int.tryParse('$current');
    final merged = _assigneesMergedWithAuth();

    return CustomerVoiceUserPickerTrigger(
      sectionLabel: label,
      valueText: cur == null || cur <= 0
          ? 'Belum dipilih — ketuk untuk mencari'
          : _labelForUserId(cur, merged),
      leadingIcon: Icons.person_search_outlined,
      onTap: () async {
        final id = await showCustomerVoiceSingleUserPicker(
          context: context,
          assignees: merged,
          title: 'Pilih $label',
          selectedId: cur,
        );
        if (!mounted) return;
        onPick(id);
      },
    );
  }

  Widget _readonlyTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    String? initial,
    void Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initial ?? '',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _multiline(
    String label,
    String? initial,
    void Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initial ?? '',
        maxLines: 4,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField(
    String label,
    String? initial,
    void Function(String?) onPick,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(initial ?? '—'),
      trailing: IconButton(
        icon: const Icon(Icons.edit_calendar_outlined),
        onPressed: () async {
          final base = initial != null ? DateTime.tryParse(initial) : null;
          final d = await showDatePicker(
            context: context,
            initialDate: base ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) {
            onPick(
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
            );
          }
        },
      ),
    );
  }

  Widget _timeField(
    String label,
    String? initial,
    void Function(String?) onPick,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(initial ?? '—'),
      trailing: IconButton(
        icon: const Icon(Icons.schedule),
        onPressed: () async {
          final parts = (initial ?? '12:00').split(':');
          final h = int.tryParse(parts.elementAt(0)) ?? 12;
          final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          final tod = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: h, minute: m),
          );
          if (tod != null) {
            onPick(
              '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}',
            );
          }
        },
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }
}

String sourceLabelFromType(String? sourceType) {
  switch (sourceType?.toLowerCase() ?? '') {
    case 'google_review':
      return 'Google Review';
    case 'instagram_comment':
      return 'Instagram';
    case 'guest_comment':
      return 'Guest Comment';
    default:
      return '—';
  }
}
