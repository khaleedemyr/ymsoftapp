import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/daily_report_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'daily_report_inspect_screen.dart';
import 'daily_report_post_inspection_screen.dart';
import 'daily_report_ui.dart';
import 'daily_report_media.dart';

class DailyReportShowScreen extends StatefulWidget {
  final int reportId;
  const DailyReportShowScreen({super.key, required this.reportId});

  @override
  State<DailyReportShowScreen> createState() => _DailyReportShowScreenState();
}

class _DailyReportShowScreenState extends State<DailyReportShowScreen> {
  final DailyReportService _svc = DailyReportService();
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _permissions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _svc.getReport(widget.reportId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _report = res['report'] as Map<String, dynamic>?;
        _stats = res['inspection_stats'] as Map<String, dynamic>?;
        _permissions = res['permissions'] as Map<String, dynamic>?;
      }
    });
  }

  bool get _canEdit {
    if (_report == null || _permissions == null) return false;
    if (_permissions!['can_edit'] == true) return true;
    return '${_permissions!['current_user_id']}' == '${_report!['user_id']}';
  }

  String _fmt(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return AppScaffold(
      title: 'Detail Daily Report',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : r == null
              ? const Center(child: Text('Report tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _headerCard(r),
                      if (_stats != null) ...[const SizedBox(height: 12), _statsCard(_stats!)],
                      const SizedBox(height: 12),
                      _sectionTitle('Area Inspeksi'),
                      ..._areaTiles(r),
                      if (r['briefing'] != null) ...[const SizedBox(height: 16), _sectionTitle('Briefing'), _briefingCard(r['briefing'] as Map<String, dynamic>)],
                      if (r['productivity'] != null) ...[const SizedBox(height: 16), _sectionTitle('Productivity'), _kvCard(r['productivity'] as Map<String, dynamic>)],
                      if ((r['visit_tables'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _sectionTitle('Visit Table'),
                        ...(r['visit_tables'] as List).map((vt) => _visitTableCard(vt as Map<String, dynamic>)),
                      ],
                      if ((r['summaries'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _sectionTitle('Summary'),
                        ...(r['summaries'] as List).map((s) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text((s as Map)['notes']?.toString() ?? '-'),
                              ),
                            )),
                      ],
                      const SizedBox(height: 16),
                      if (r['status'] == 'draft' && _canEdit) ...[
                        FilledButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportInspectScreen(reportId: widget.reportId))).then((_) => _load()),
                          icon: const Icon(Icons.fact_check),
                          label: const Text('Lanjut Inspeksi'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportPostInspectionScreen(reportId: widget.reportId))).then((_) => _load()),
                          icon: const Icon(Icons.assignment),
                          label: const Text('Post Inspection'),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _headerCard(Map<String, dynamic> r) {
    final outlet = r['outlet'] is Map ? (r['outlet'] as Map)['nama_outlet'] : '-';
    final dept = r['department'] is Map ? (r['department'] as Map)['nama_departemen'] : '-';
    final user = r['user'] is Map ? (r['user'] as Map)['nama_lengkap'] : '-';
    final status = r['status']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(outlet?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('$dept · ${r['inspection_time'] == 'lunch' ? 'Lunch' : 'Dinner'}'),
            Text('Creator: $user'),
            Text('Dibuat: ${_fmt(r['created_at']?.toString())}'),
            const SizedBox(height: 8),
            Chip(label: Text(status == 'completed' ? 'Completed' : 'Draft')),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(Map<String, dynamic> s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _miniStat('G', '${s['good_areas']}'),
            _miniStat('NG', '${s['not_good_areas']}'),
            _miniStat('NA', '${s['not_available_areas']}'),
            _miniStat('Rating', '${s['rating']}%'),
            _miniStat('Bintang', '${s['star_rating']}'),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  List<Widget> _areaTiles(Map<String, dynamic> r) {
    final areas = (r['report_areas'] ?? r['reportAreas']) as List<dynamic>? ?? [];
    if (areas.isEmpty) return [const Text('Belum ada area diinspeksi')];

    return areas.map((a) {
      final m = a as Map<String, dynamic>;
      final areaName = _areaName(m);
      final status = m['status']?.toString() ?? '';
      final finding = m['finding_problem']?.toString().trim() ?? '';
      final deptConcern = _deptConcernName(m);
      final urls = _parseDocumentation(m['documentation']);

      return DrSectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusBadge(status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    areaName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DrColors.textPrimary),
                  ),
                ),
              ],
            ),
            if (finding.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Finding Problem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DrColors.textSecondary)),
              const SizedBox(height: 4),
              Text(finding, style: const TextStyle(fontSize: 13, height: 1.4, color: DrColors.textPrimary)),
            ],
            if (deptConcern != null && deptConcern.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Dept. Concern', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DrColors.textSecondary)),
              const SizedBox(height: 4),
              Text(deptConcern, style: const TextStyle(fontSize: 13, color: DrColors.textPrimary)),
            ],
            if (urls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Dokumentasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DrColors.textSecondary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    return drDocumentationThumbnail(
                      context,
                      rawUrl: urls[i],
                      allUrls: urls,
                    );
                  },
                ),
              ),
            ],
            if (finding.isEmpty && (deptConcern == null || deptConcern.isEmpty) && urls.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 12, color: _statusColor(status)),
                ),
              ),
          ],
        ),
      );
    }).map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)).toList();
  }

  String _areaName(Map<String, dynamic> m) {
    final area = m['area'];
    if (area is Map) return area['nama_area']?.toString() ?? 'Area';
    return 'Area';
  }

  String? _deptConcernName(Map<String, dynamic> m) {
    final dc = m['dept_concern'] ?? m['deptConcern'];
    if (dc is Map) return dc['nama_divisi']?.toString();
    return null;
  }

  List<String> _parseDocumentation(dynamic docs) {
    if (docs == null) return [];
    if (docs is List) {
      return docs.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    }
    if (docs is String && docs.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(docs);
        if (parsed is List) {
          return parsed.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
        }
      } catch (_) {
        return [docs];
      }
    }
    return [];
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'G':
        return 'Good — tidak ada temuan';
      case 'NG':
        return 'Not Good';
      case 'NA':
        return 'Not Available';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'G':
        return DrColors.success;
      case 'NG':
        return DrColors.danger;
      case 'NA':
        return DrColors.warning;
      default:
        return DrColors.textSecondary;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    final bg = switch (status) {
      'G' => const Color(0xFFDCFCE7),
      'NG' => const Color(0xFFFEE2E2),
      'NA' => const Color(0xFFFFEDD5),
      _ => const Color(0xFFF1F5F9),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        _statusLabelShort(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  String _statusLabelShort(String status) {
    switch (status) {
      case 'G':
        return 'Good';
      case 'NG':
        return 'Not Good';
      case 'NA':
        return 'Not Available';
      default:
        return status;
    }
  }

  Widget _briefingCard(Map<String, dynamic> b) => _kvCard(b);

  Widget _kvCard(Map<String, dynamic> data) {
    final skip = {'id', 'daily_report_id', 'created_at', 'updated_at', 'briefing_type', 'summary_type'};
    final entries = data.entries.where((e) => !skip.contains(e.key) && e.value != null && '$e'.isNotEmpty).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: entries.map((e) => ListTile(
                dense: true,
                title: Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text('${e.value}'),
              )).toList(),
        ),
      ),
    );
  }

  Widget _visitTableCard(Map<String, dynamic> vt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Meja ${vt['table_no'] ?? '-'} · ${vt['guest_name'] ?? '-'}'),
        subtitle: Text('Pax: ${vt['no_of_pax'] ?? '-'} · ${vt['guest_experience'] ?? ''}'),
      ),
    );
  }
}
