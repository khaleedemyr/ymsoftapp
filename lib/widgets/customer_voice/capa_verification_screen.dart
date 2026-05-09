import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/auth_service.dart';
import '../../services/customer_voice_command_center_service.dart';
import 'capa_display_helpers.dart';
import 'capa_json_helpers.dart';

/// Full-screen flow mirroring web `CapaVerificationCard` modal (read-only CAPA + verify form).
class CapaVerificationScreen extends StatefulWidget {
  const CapaVerificationScreen({
    super.key,
    required this.caseId,
    this.pendingItem,
  });

  final int caseId;
  final PendingCapaVerificationItem? pendingItem;

  @override
  State<CapaVerificationScreen> createState() => _CapaVerificationScreenState();
}

class _CapaVerificationScreenState extends State<CapaVerificationScreen> {
  final CustomerVoiceCommandCenterService _service = CustomerVoiceCommandCenterService();

  Map<String, dynamic>? _caseRow;
  bool _loading = true;
  String? _error;

  String _activeDivision = 'service';
  final TextEditingController _notesController = TextEditingController();
  String _resultValue = '';
  DateTime? _followUpDate;
  bool _saving = false;

  int? _authUserId;

  static const _fishboneRows = [
    ('man', 'Man (SDM)'),
    ('method', 'Method (SOP)'),
    ('machine', 'Machine (equipment)'),
    ('material', 'Material (bahan)'),
    ('measurement', 'Measurement'),
    ('environment', 'Environment'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthService().getUserData();
      _authUserId = int.tryParse('${user?['id'] ?? 0}');

      final row = await _service.getCaseBrief(widget.caseId);
      final pending = verifierPendingDivisionsForUser(row, _authUserId ?? 0);
      final firstDiv = pending.isNotEmpty
          ? pending.first
          : (widget.pendingItem?.pendingDivisions.isNotEmpty == true
              ? widget.pendingItem!.pendingDivisions.first
              : 'service');

      if (!mounted) return;
      setState(() {
        _caseRow = row;
        _activeDivision = firstDiv;
        _loading = false;
      });
      _syncFormFromCapa();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _capaForDivision(String div) {
    final row = _caseRow;
    if (row == null) return null;
    final divs = asStringKeyedMap(row['capa_divisions']);
    if (divs != null && divs[div] is Map) {
      return asStringKeyedMap(divs[div]);
    }
    final active = row['capa_active_division']?.toString().toLowerCase() ?? 'service';
    if (active == div && row['capa'] is Map) {
      return asStringKeyedMap(row['capa']);
    }
    return null;
  }

  List<String> _pendingDivisionsForMe() {
    final row = _caseRow;
    if (row == null) return [];
    return verifierPendingDivisionsForUser(row, _authUserId ?? 0);
  }

  void _syncFormFromCapa() {
    final capa = _capaForDivision(_activeDivision);
    final g = capa != null && capa['g'] is Map ? asStringKeyedMap(capa['g'])! : <String, dynamic>{};
    _resultValue = g['result']?.toString() ?? '';
    _notesController.text = g['notes']?.toString() ?? '';
    final fud = g['follow_up_date']?.toString();
    _followUpDate = fud != null && fud.isNotEmpty ? DateTime.tryParse(fud) : null;
  }

  String _formatDt(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) {
      final s = v.toString().trim();
      return s.isEmpty ? '—' : s;
    }
    return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(d);
  }

  String _headerSubtitle() {
    final row = _caseRow;
    if (row == null) return '';
    final outlet = row['nama_outlet']?.toString().trim();
    final oc = (outlet != null && outlet.isNotEmpty) ? outlet : '—';
    final ev = row['event_at'] ?? widget.pendingItem?.eventAt;
    return 'Divisi: ${divisionLabel(_activeDivision)} · $oc · ${_formatDt(ev)}';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_caseRow == null) return;
    if (_resultValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi Effective / Not Effective dulu.')),
      );
      return;
    }

    final division = _activeDivision;
    Map<String, dynamic> base;
    final divs = asStringKeyedMap(_caseRow!['capa_divisions']);
    if (divs != null &&
        divs[division] is Map &&
        asStringKeyedMap(divs[division]) != null) {
      base = Map<String, dynamic>.from(
        jsonDeepCopy(asStringKeyedMap(divs[division])!),
      );
    } else {
      base = Map<String, dynamic>.from(
        jsonDeepCopy(asStringKeyedMap(_caseRow!['capa']) ?? {}),
      );
    }

    base['g'] ??= <String, dynamic>{};
    final g = asStringKeyedMap(base['g']) ?? {};
    g['verified_by_user_id'] = _authUserId ?? g['verified_by_user_id'];
    g['result'] = _resultValue;
    g['notes'] = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    g['follow_up_date'] = _followUpDate == null
        ? null
        : '${_followUpDate!.year.toString().padLeft(4, '0')}-${_followUpDate!.month.toString().padLeft(2, '0')}-${_followUpDate!.day.toString().padLeft(2, '0')}';
    base['g'] = g;

    setState(() => _saving = true);
    try {
      await _service.saveCapa(
        caseId: widget.caseId,
        capa: base,
        capaDivision: division,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifikasi tersimpan')),
      );
      Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _loading || _caseRow == null ? kToolbarHeight : 72,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Verifikasi CAPA — Case #${widget.caseId}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (!_loading && _caseRow != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _headerSubtitle(),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.92),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final row = _caseRow!;
    final pending = _pendingDivisionsForMe();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(
            'Ringkasan kasus',
            disp(row['summary_id']),
            wide: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoCard('Source', sourceTypeLabel(row['source_type']?.toString()))),
              const SizedBox(width: 10),
              Expanded(child: _infoCard('Severity', disp(row['severity']))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoCard('Status', disp(row['status']))),
              const SizedBox(width: 10),
              Expanded(child: _infoCard('FU target', followUpLabel(row['follow_up_target']?.toString()))),
            ],
          ),
          const SizedBox(height: 12),
          _sectionTitle('Jenis komplain'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (row['complaint_type_labels'] as List<dynamic>? ?? [])
                .map(
                  (e) => Chip(
                    label: Text(e.toString(), style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          if ((row['complaint_type_labels'] as List?)?.isEmpty != false)
            Text('—', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          _sectionTitle('Dampak (source)'),
          const SizedBox(height: 6),
          Text(impactLine(row['impact']), style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          _sectionTitle('PIC penerima complaint (kasus)'),
          const SizedBox(height: 6),
          Text(
            '${disp(row['assigned_to_name'])}${row['assigned_to_jabatan'] != null ? ' · ${row['assigned_to_jabatan']}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Deskripsi source (komentar)'),
          const SizedBox(height: 6),
          Text(disp(row['raw_text']), style: const TextStyle(height: 1.35)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pending.map((div) {
              final sel = _activeDivision == div;
              return ChoiceChip(
                label: Text(divisionLabel(div)),
                selected: sel,
                onSelected: (_) {
                  setState(() {
                    _activeDivision = div;
                    _syncFormFromCapa();
                  });
                },
              );
            }).toList(),
          ),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Tidak ada divisi pending verifikasi untuk Anda pada case ini.',
                style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
              ),
            ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 20),
            _capaReadonlySections(
              _capaForDivision(_activeDivision) ?? <String, dynamic>{},
              row,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verifikasi ${divisionLabel(_activeDivision)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Isi hasil verifikasi di bawah, lalu simpan.',
                    style: TextStyle(fontSize: 11, height: 1.35, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _resultValue.isEmpty ? '' : _resultValue,
                    decoration: const InputDecoration(
                      labelText: 'Hasil',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('— pilih —')),
                      DropdownMenuItem(value: 'effective', child: Text('Effective — efektif')),
                      DropdownMenuItem(value: 'not_effective', child: Text('Not effective — tidak efektif')),
                    ],
                    onChanged: (v) => setState(() => _resultValue = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal follow up'),
                    subtitle: Text(
                      _followUpDate == null
                          ? '—'
                          : '${_followUpDate!.year}-${_followUpDate!.month.toString().padLeft(2, '0')}-${_followUpDate!.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _followUpDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _followUpDate = d);
                      },
                    ),
                  ),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan tambahan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: _saving
                          ? const Text('Menyimpan…')
                          : const Text('Simpan Verifikasi'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      );

  Widget _infoCard(String k, String v, {bool wide = false}) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _capaReadonlySections(Map<String, dynamic> capa, Map<String, dynamic> caseRow) {
    final a = asStringKeyedMap(capa['a']) ?? {};
    final b = asStringKeyedMap(capa['b']) ?? {};
    final c = asStringKeyedMap(capa['c']) ?? {};
    final d = asStringKeyedMap(capa['d']) ?? {};
    final e = asStringKeyedMap(capa['e']) ?? {};
    final f = asStringKeyedMap(capa['f']) ?? {};
    final g = asStringKeyedMap(capa['g']) ?? {};
    final h = asStringKeyedMap(capa['h']) ?? {};
    final evidence = capa['evidence'];
    final evList = evidence is List ? evidence.whereType<Map>().toList() : <Map>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardSection(
          'Informasi Komplain',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Tanggal complaint', disp(a['complaint_date'])),
              _kv('Waktu complaint', disp(a['complaint_time'])),
              _kv('Outlet / lokasi', disp(caseRow['nama_outlet'])),
              _kv('Channel complaint', channelLabel(a['channel']?.toString(), a['channel_other']?.toString())),
              _kv('Nama tamu (optional)', disp(a['guest_name'])),
            ],
          ),
        ),
        _cardSection(
          'Detail Complaint',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: ((b['types'] as List<dynamic>?) ?? [])
                    .map(
                      (t) => Chip(
                        label: Text(complaintTypeLabel(t.toString()), style: const TextStyle(fontSize: 11)),
                      ),
                    )
                    .toList(),
              ),
              if (b['types_other'] != null && '${b['types_other']}'.trim().isNotEmpty)
                Text('Lainnya: ${b['types_other']}', style: const TextStyle(fontSize: 12)),
              _kv('Deskripsi complaint', disp(b['description'])),
            ],
          ),
        ),
        _cardSection(
          'Lampiran bukti & dokumen',
          evList.isEmpty
              ? Text('Belum ada lampiran.', style: TextStyle(color: Colors.grey.shade600))
              : Column(
                  children: evList.map((raw) {
                    final ev = raw.map((k, v) => MapEntry(k.toString(), v));
                    final url = ev['url']?.toString();
                    final name = ev['original_name']?.toString() ?? 'file';
                    if (isImageEvidence(ev) && url != null && url.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _openUrl(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => ListTile(
                                title: Text(name),
                                trailing: const Icon(Icons.link),
                                onTap: () => _openUrl(url),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFF7C3AED))),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: url != null && url.isNotEmpty ? () => _openUrl(url) : null,
                    );
                  }).toList(),
                ),
        ),
        _cardSection(
          'Immediate Action',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: ((c['actions'] as List<dynamic>?) ?? [])
                    .map((x) => Chip(label: Text(immediateActionLabel(x))))
                    .toList(),
              ),
              if (c['actions_other'] != null)
                Text('Lainnya: ${c['actions_other']}', style: const TextStyle(fontSize: 13)),
              _kv('Waktu respon', disp(c['response_time_note'])),
              _kv('PIC', userIdLabel(_authUserId, c['pic_user_id'])),
            ],
          ),
        ),
        _cardSection(
          'Root Cause Analysis',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Masalah', disp(d['problem_statement'])),
              ..._fishboneRows.map((fr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fr.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text(disp(d[fr.$1]), style: const TextStyle(height: 1.3)),
                    ],
                  ),
                );
              }),
              _kv('Akar masalah utama', disp(d['root_cause_summary'])),
            ],
          ),
        ),
        _cardSection(
          'Corrective Action',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Action', disp(e['action'])),
              _kv('PIC', userIdLabel(_authUserId, e['pic_user_id'])),
              _kv('Deadline', disp(e['deadline'])),
              _kv('Status', disp(e['status'])),
            ],
          ),
        ),
        _cardSection(
          'Preventive Action',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: ((f['improvement_areas'] as List<dynamic>?) ?? [])
                    .map((x) => Chip(label: Text(improvementAreaLabel(x))))
                    .toList(),
              ),
              _kv('Action', disp(f['action'])),
              _kv('PIC', userIdLabel(_authUserId, f['pic_user_id'])),
              _kv('Timeline', disp(f['timeline'])),
              _kv('KPI terkait', disp(f['kpi'])),
            ],
          ),
        ),
        _cardSection(
          'Follow Up & Verification (data tersimpan)',
          Column(
            children: [
              _kv('Verifikator (ditunjuk)', userIdLabel(_authUserId, g['verified_by_user_id'])),
              _kv('Hasil saat ini', verificationResultLabel(g['result']?.toString())),
            ],
          ),
        ),
        _cardSection(
          'Customer Recovery',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Tamu dihubungi kembali', contactedLabel(h['contacted']?.toString())),
              _kv('Metode', contactMethodsLine(h['contact_methods'])),
              _kv('Feedback tamu setelah recovery', disp(h['recovery_feedback'])),
              _kv('Status kepuasan', satisfactionLabel(h['satisfaction']?.toString())),
              _kv('Severity (dokumentasi)', disp(h['documented_severity'])),
              _kv('Impact (dokumentasi)', impactLine(h['documented_impact'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            SelectableText(v, style: const TextStyle(height: 1.35)),
          ],
        ),
      );

  Widget _cardSection(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    if (!await launchUrl(u, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka link')));
      }
    }
  }
}

Map<String, dynamic> jsonDeepCopy(Map<String, dynamic> m) {
  return jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
}
