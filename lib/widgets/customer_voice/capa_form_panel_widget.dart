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

/// Mirrors web `CapaFormPanel.vue`: multi-division drafts, sections A–H, evidence upload.
class CapaFormPanelWidget extends StatefulWidget {
  const CapaFormPanelWidget({
    super.key,
    required this.caseId,
    required this.caseRow,
    required this.assignees,
    this.authUser,
  });

  final int caseId;
  final Map<String, dynamic> caseRow;
  final List<CustomerVoiceOption> assignees;
  final Map<String, dynamic>? authUser;

  @override
  State<CapaFormPanelWidget> createState() => _CapaFormPanelWidgetState();
}

class _CapaFormPanelWidgetState extends State<CapaFormPanelWidget> {
  final CustomerVoiceCommandCenterService _service =
      CustomerVoiceCommandCenterService();
  final ImagePicker _picker = ImagePicker();

  late Map<String, Map<String, dynamic>> _divisionDrafts;
  late String _activeDivision;
  bool _saving = false;
  bool _uploadingEvidence = false;

  Map<String, dynamic> get _local => _divisionDrafts[_activeDivision]!;

  @override
  void initState() {
    super.initState();
    _hydrateDrafts();
  }

  @override
  void didUpdateWidget(covariant CapaFormPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseRow != widget.caseRow ||
        oldWidget.caseId != widget.caseId) {
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
    _activeDivision =
        ['service', 'kitchen', 'bar'].contains(active) ? active : 'service';

    final uid = int.tryParse('${widget.authUser?['id'] ?? 0}') ?? 0;
    if (uid > 0) {
      for (final d in _divisionDrafts.keys) {
        final m = _divisionDrafts[d]!;
        final c = asStringKeyedMap(m['c']) ?? {};
        final e = asStringKeyedMap(m['e']) ?? {};
        final f = asStringKeyedMap(m['f']) ?? {};
        c['pic_user_id'] ??= uid;
        e['pic_user_id'] ??= uid;
        f['pic_user_id'] ??= uid;
        m['c'] = c;
        m['e'] = e;
        m['f'] = f;
      }
    }
  }

  void _applySourceDefaultsAllDivisions() {
    final topics = (widget.caseRow['topics'] as List<dynamic>?) ?? [];
    final types = _topicKeysFromSource(topics);
    final desc = widget.caseRow['raw_text']?.toString().trim() ?? '';
    final sev = widget.caseRow['severity']?.toString().toLowerCase() ?? '';
    final impact = (widget.caseRow['impact'] as List<dynamic>?) ?? [];
    final channel = _sourceChannelValue();
    final channelOther =
        sourceLabelFromType(widget.caseRow['source_type']?.toString());

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
        a['channel_other'] = channelOther;
      }
      merged['a'] = a;

      final h = asStringKeyedMap(merged['h']) ?? {};
      if (['minor', 'major', 'critical'].contains(sev)) {
        h['documented_severity'] = sev;
      }
      final impList = <String>[];
      for (final x in impact) {
        final k = x.toString().toLowerCase();
        if (['reputasi', 'finansial', 'operasional'].contains(k)) {
          impList.add(k);
        }
      }
      if (impList.isNotEmpty) {
        h['documented_impact'] = impList;
      }
      merged['h'] = h;
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

  Future<void> _save() async {
    final capa = ensureCapaShape(Map<String, dynamic>.from(_local));
    setState(() => _saving = true);
    try {
      await _service.saveCapa(
        caseId: widget.caseId,
        capa: capa,
        capaDivision: _activeDivision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form CAPA tersimpan')),
      );
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
          caseId: widget.caseId, filePath: file.path);
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
            content: Text(
                'Lampiran berhasil diunggah — simpan form CAPA untuk memastikan konsistensi server.')),
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
          caseId: widget.caseId, evidenceId: evidenceId);
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
      _activeDivision = div;
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
        _divisionListCap(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['service', 'kitchen', 'bar'].map((div) {
            final sel = _activeDivision == div;
            return ChoiceChip(
              label: Text(
                  sel ? 'Editing: ${divisionLabel(div)}' : divisionLabel(div)),
              selected: sel,
              onSelected: (_) => _switchDivision(div),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _sectionEvidence(),
        const SizedBox(height: 12),
        _sectionA(),
        _sectionB(),
        _sectionC(),
        _sectionD(),
        _sectionE(),
        _sectionF(),
        _sectionG(),
        _sectionH(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORM STANDAR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Customer Complaint Handling — Corrective & Preventive Action Plan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.2,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Isi sesuai penanganan komplain di lapangan. Data tersimpan pada kasus (meta).',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divisionListCap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('List CAPA', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Tidak wajib semua divisi terisi.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        ...['service', 'kitchen', 'bar'].map((id) {
          final filled = _divisionFilled(id);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(divisionLabel(id)),
            subtitle:
                Text(filled ? 'Sudah ada data CAPA' : 'Belum ada data CAPA'),
            trailing: TextButton(
              onPressed: () => _switchDivision(id),
              child: Text(_activeDivision == id ? 'Editing' : 'Show/Edit'),
            ),
          );
        }),
      ],
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
            'Foto struk, SS chat, PDF SOP, dll. Maks. 20 file.',
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
                label: const Text('Galeri'),
              ),
            ],
          ),
          if (_uploadingEvidence)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator()),
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
                            imageUrl: url, fit: BoxFit.cover),
                      ),
                    )
                  : const Icon(Icons.attach_file),
              title: GestureDetector(
                onTap: url != null ? () => _openUrl(url) : null,
                child: Text(name,
                    style: const TextStyle(
                        color: Color(0xFF4F46E5), fontSize: 13)),
              ),
              trailing: IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                onPressed: id.isEmpty ? null : () => _deleteEvidence(id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionA() {
    final a = asStringKeyedMap(_local['a']) ?? {};
    return _card(
      'Informasi Komplain',
      Column(
        children: [
          _dateField('Tanggal complaint', a['complaint_date']?.toString(), (v) {
            final m = asStringKeyedMap(_local['a']) ?? {};
            m['complaint_date'] = v;
            setState(() => _divisionDrafts[_activeDivision]!['a'] = m);
          }),
          _timeField('Waktu complaint', a['complaint_time']?.toString(), (v) {
            final m = asStringKeyedMap(_local['a']) ?? {};
            m['complaint_time'] = v;
            setState(() => _divisionDrafts[_activeDivision]!['a'] = m);
          }),
          _readonlyTile('Outlet / lokasi',
              widget.caseRow['nama_outlet']?.toString() ?? '—'),
          _readonlyTile(
              'Channel complaint',
              channelLabel(
                  a['channel']?.toString(), a['channel_other']?.toString())),
          _textField(
            'Nama tamu (optional)',
            a['guest_name']?.toString(),
            (v) {
              final m = asStringKeyedMap(_local['a']) ?? {};
              m['guest_name'] = v.isEmpty ? null : v;
              setState(() => _divisionDrafts[_activeDivision]!['a'] = m);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionB() {
    final b = asStringKeyedMap(_local['b']) ?? {};
    final types = ((b['types'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    return _card(
      'Detail Complaint',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jenis complaint',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            children: complaintTypeMap.keys.map((k) {
              final sel = types.contains(k);
              return FilterChip(
                label: Text(complaintTypeLabel(k),
                    style: const TextStyle(fontSize: 11)),
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
          _textField('Types other', b['types_other']?.toString(), (v) {
            final m = asStringKeyedMap(_local['b']) ?? {};
            m['types_other'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
          }),
          _multiline('Deskripsi complaint', b['description']?.toString(), (v) {
            final m = asStringKeyedMap(_local['b']) ?? {};
            m['description'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['b'] = m);
          }),
        ],
      ),
    );
  }

  Widget _sectionC() {
    final c = asStringKeyedMap(_local['c']) ?? {};
    final actions = ((c['actions'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    const opts = [
      'apology',
      'replace_product',
      'refund_discount',
      'escalate',
      'other'
    ];
    return _card(
      'Immediate Action',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: opts.map((k) {
              final sel = actions.contains(k);
              return FilterChip(
                label: Text(immediateActionLabel(k),
                    style: const TextStyle(fontSize: 11)),
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
          _textField('Lainnya (actions)', c['actions_other']?.toString(), (v) {
            final m = asStringKeyedMap(_local['c']) ?? {};
            m['actions_other'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['c'] = m);
          }),
          _multiline('Waktu respon', c['response_time_note']?.toString(), (v) {
            final m = asStringKeyedMap(_local['c']) ?? {};
            m['response_time_note'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['c'] = m);
          }),
          _picDropdown(c['pic_user_id'], (uid) {
            final m = asStringKeyedMap(_local['c']) ?? {};
            m['pic_user_id'] = uid;
            setState(() => _divisionDrafts[_activeDivision]!['c'] = m);
          }),
        ],
      ),
    );
  }

  Widget _sectionD() {
    final d = asStringKeyedMap(_local['d']) ?? {};
    const fish = [
      ('man', 'Man (SDM)'),
      ('method', 'Method (SOP)'),
      ('machine', 'Machine (equipment)'),
      ('material', 'Material (bahan)'),
      ('measurement', 'Measurement'),
      ('environment', 'Environment'),
    ];
    return _card(
      'Root Cause Analysis',
      Column(
        children: [
          _multiline('Masalah', d['problem_statement']?.toString(), (v) {
            final m = asStringKeyedMap(_local['d']) ?? {};
            m['problem_statement'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['d'] = m);
          }),
          ...fish.map((fr) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _multiline(fr.$2, d[fr.$1]?.toString(), (v) {
                final m = asStringKeyedMap(_local['d']) ?? {};
                m[fr.$1] = v.isEmpty ? null : v;
                setState(() => _divisionDrafts[_activeDivision]!['d'] = m);
              }),
            );
          }),
          _multiline('Akar masalah utama', d['root_cause_summary']?.toString(),
              (v) {
            final m = asStringKeyedMap(_local['d']) ?? {};
            m['root_cause_summary'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['d'] = m);
          }),
        ],
      ),
    );
  }

  Widget _sectionE() {
    final e = asStringKeyedMap(_local['e']) ?? {};
    return _card(
      'Corrective Action',
      Column(
        children: [
          _multiline('Action', e['action']?.toString(), (v) {
            final m = asStringKeyedMap(_local['e']) ?? {};
            m['action'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
          }),
          _picDropdown(e['pic_user_id'], (uid) {
            final m = asStringKeyedMap(_local['e']) ?? {};
            m['pic_user_id'] = uid;
            setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
          }),
          _textField('Deadline', e['deadline']?.toString(), (v) {
            final m = asStringKeyedMap(_local['e']) ?? {};
            m['deadline'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
          }),
          _textField('Status', e['status']?.toString() ?? 'open', (v) {
            final m = asStringKeyedMap(_local['e']) ?? {};
            m['status'] = v.isEmpty ? 'open' : v;
            setState(() => _divisionDrafts[_activeDivision]!['e'] = m);
          }),
        ],
      ),
    );
  }

  Widget _sectionF() {
    final f = asStringKeyedMap(_local['f']) ?? {};
    final areas = ((f['improvement_areas'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    const opts = ['sop', 'training', 'equipment', 'manpower', 'system'];
    return _card(
      'Preventive Action',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: opts.map((k) {
              final sel = areas.contains(k);
              return FilterChip(
                label: Text(improvementAreaLabel(k),
                    style: const TextStyle(fontSize: 11)),
                selected: sel,
                onSelected: (v) {
                  final next = List<String>.from(areas);
                  if (v) {
                    if (!next.contains(k)) next.add(k);
                  } else {
                    next.remove(k);
                  }
                  final m = asStringKeyedMap(_local['f']) ?? {};
                  m['improvement_areas'] = next;
                  setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
                },
              );
            }).toList(),
          ),
          _multiline('Action', f['action']?.toString(), (v) {
            final m = asStringKeyedMap(_local['f']) ?? {};
            m['action'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
          }),
          _picDropdown(f['pic_user_id'], (uid) {
            final m = asStringKeyedMap(_local['f']) ?? {};
            m['pic_user_id'] = uid;
            setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
          }),
          _textField('Timeline', f['timeline']?.toString(), (v) {
            final m = asStringKeyedMap(_local['f']) ?? {};
            m['timeline'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
          }),
          _multiline('KPI terkait', f['kpi']?.toString(), (v) {
            final m = asStringKeyedMap(_local['f']) ?? {};
            m['kpi'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['f'] = m);
          }),
        ],
      ),
    );
  }

  Widget _sectionG() {
    final g = asStringKeyedMap(_local['g']) ?? {};
    final authId = int.tryParse('${widget.authUser?['id'] ?? 0}') ?? 0;
    final verifierId = int.tryParse('${g['verified_by_user_id'] ?? ''}');
    final merged = _assigneesMergedWithAuth();

    return _card(
      'Follow Up & Verification',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerVoiceUserPickerTrigger(
            sectionLabel: 'Verifikator',
            valueText: verifierId == null || verifierId <= 0
                ? 'Belum dipilih — ketuk untuk memilih user'
                : _labelForUserId(verifierId, merged),
            leadingIcon: Icons.verified_user_outlined,
            onTap: () async {
              final id = await showCustomerVoiceSingleUserPicker(
                context: context,
                assignees: merged,
                title: 'Pilih verifikator',
                selectedId: verifierId,
              );
              if (!mounted) {
                return;
              }
              final m = asStringKeyedMap(_local['g']) ?? {};
              m['verified_by_user_id'] = id;
              setState(() => _divisionDrafts[_activeDivision]!['g'] = m);
            },
          ),
          if (authId > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final m = asStringKeyedMap(_local['g']) ?? {};
                  m['verified_by_user_id'] = authId;
                  setState(() => _divisionDrafts[_activeDivision]!['g'] = m);
                },
                child: const Text('Gunakan saya'),
              ),
            ),
          DropdownButtonFormField<String>(
            value: _normalizeResult(g['result']?.toString()),
            decoration: const InputDecoration(
                labelText: 'Hasil verifikasi', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '', child: Text('—')),
              DropdownMenuItem(value: 'effective', child: Text('Effective')),
              DropdownMenuItem(
                  value: 'not_effective', child: Text('Not effective')),
            ],
            onChanged: (v) {
              final m = asStringKeyedMap(_local['g']) ?? {};
              m['result'] = v == null || v.isEmpty ? null : v;
              setState(() => _divisionDrafts[_activeDivision]!['g'] = m);
            },
          ),
          const SizedBox(height: 8),
          _dateField('Tanggal follow up', g['follow_up_date']?.toString(), (v) {
            final m = asStringKeyedMap(_local['g']) ?? {};
            m['follow_up_date'] = v;
            setState(() => _divisionDrafts[_activeDivision]!['g'] = m);
          }),
          _multiline('Catatan', g['notes']?.toString(), (v) {
            final m = asStringKeyedMap(_local['g']) ?? {};
            m['notes'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['g'] = m);
          }),
        ],
      ),
    );
  }

  String? _normalizeResult(String? r) {
    final s = r?.trim().toLowerCase() ?? '';
    if (s.isEmpty) return '';
    if (s == 'effective' || s == 'not_effective') return s;
    return '';
  }

  Widget _sectionH() {
    final h = asStringKeyedMap(_local['h']) ?? {};
    final methods = ((h['contact_methods'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    const mOpts = ['call', 'whatsapp', 'email'];
    final impactSel = ((h['documented_impact'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    const impactOpts = ['reputasi', 'finansial', 'operasional'];

    return _card(
      'Customer Recovery',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(
              'Severity (dokumentasi)', h['documented_severity']?.toString(),
              (v) {
            final m = asStringKeyedMap(_local['h']) ?? {};
            m['documented_severity'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['h'] = m);
          }),
          const Text('Impact (dokumentasi)', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 6,
            children: impactOpts.map((k) {
              final sel = impactSel.contains(k);
              return FilterChip(
                label: Text(k),
                selected: sel,
                onSelected: (v) {
                  final next = List<String>.from(impactSel);
                  if (v) {
                    if (!next.contains(k)) next.add(k);
                  } else {
                    next.remove(k);
                  }
                  final m = asStringKeyedMap(_local['h']) ?? {};
                  m['documented_impact'] = next;
                  setState(() => _divisionDrafts[_activeDivision]!['h'] = m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _contactedVal(h['contacted']?.toString()),
            decoration: const InputDecoration(
                labelText: 'Tamu dihubungi kembali',
                border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '', child: Text('—')),
              DropdownMenuItem(value: 'yes', child: Text('Ya')),
              DropdownMenuItem(value: 'no', child: Text('Tidak')),
            ],
            onChanged: (v) {
              final m = asStringKeyedMap(_local['h']) ?? {};
              m['contacted'] = v == null || v.isEmpty ? null : v;
              setState(() => _divisionDrafts[_activeDivision]!['h'] = m);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: mOpts.map((k) {
              final sel = methods.contains(k);
              return FilterChip(
                label: Text(contactMethodMap[k] ?? k),
                selected: sel,
                onSelected: (v) {
                  final next = List<String>.from(methods);
                  if (v) {
                    if (!next.contains(k)) next.add(k);
                  } else {
                    next.remove(k);
                  }
                  final mm = asStringKeyedMap(_local['h']) ?? {};
                  mm['contact_methods'] = next;
                  setState(() => _divisionDrafts[_activeDivision]!['h'] = mm);
                },
              );
            }).toList(),
          ),
          _multiline('Feedback tamu setelah recovery',
              h['recovery_feedback']?.toString(), (v) {
            final m = asStringKeyedMap(_local['h']) ?? {};
            m['recovery_feedback'] = v.isEmpty ? null : v;
            setState(() => _divisionDrafts[_activeDivision]!['h'] = m);
          }),
          DropdownButtonFormField<String>(
            value: () {
              final s = h['satisfaction']?.toString().trim() ?? '';
              return s.isEmpty ? '' : s;
            }(),
            decoration: const InputDecoration(
                labelText: 'Status kepuasan', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '', child: Text('—')),
              DropdownMenuItem(value: 'satisfied', child: Text('Satisfied')),
              DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
              DropdownMenuItem(
                  value: 'unsatisfied', child: Text('Unsatisfied')),
            ],
            onChanged: (v) {
              final m = asStringKeyedMap(_local['h']) ?? {};
              m['satisfaction'] = v == null || v.isEmpty ? null : v;
              setState(() => _divisionDrafts[_activeDivision]!['h'] = m);
            },
          ),
        ],
      ),
    );
  }

  String? _contactedVal(String? s) {
    final v = s?.trim().toLowerCase() ?? '';
    if (v.isEmpty) return '';
    return v;
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

  Widget _picDropdown(dynamic current, void Function(int?) onPick) {
    final cur = int.tryParse('$current');
    final merged = _assigneesMergedWithAuth();

    return CustomerVoiceUserPickerTrigger(
      sectionLabel: 'PIC (user)',
      valueText: cur == null || cur <= 0
          ? 'Belum dipilih — ketuk untuk mencari'
          : _labelForUserId(cur, merged),
      leadingIcon: Icons.person_search_outlined,
      onTap: () async {
        final id = await showCustomerVoiceSingleUserPicker(
          context: context,
          assignees: merged,
          title: 'Pilih PIC',
          selectedId: cur,
        );
        if (!mounted) {
          return;
        }
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
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _textField(
      String label, String? initial, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initial ?? '',
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _multiline(
      String label, String? initial, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initial ?? '',
        maxLines: 4,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField(
      String label, String? initial, void Function(String?) onPick) {
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
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
          }
        },
      ),
    );
  }

  Widget _timeField(
      String label, String? initial, void Function(String?) onPick) {
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
                '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}');
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.15,
                height: 1.25,
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
      return sourceType ?? '—';
  }
}
