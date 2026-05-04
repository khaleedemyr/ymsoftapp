import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/guest_comment_service.dart';

class GuestCommentGsiDashboardScreen extends StatefulWidget {
  const GuestCommentGsiDashboardScreen({super.key});

  @override
  State<GuestCommentGsiDashboardScreen> createState() =>
      _GuestCommentGsiDashboardScreenState();
}

class _GuestCommentGsiDashboardScreenState
    extends State<GuestCommentGsiDashboardScreen> {
  final _service = GuestCommentService();
  bool _loading = true;
  String? _error;
  String _month = DateFormat('yyyy-MM').format(DateTime.now());
  String? _idOutlet;

  bool _canChooseOutlet = false;
  List<dynamic> _outlets = [];
  Map<String, dynamic>? _lockedOutlet;
  Map<String, dynamic>? _summary;
  List<dynamic> _rows = [];
  List<dynamic> _trend = [];
  List<dynamic> _outletRanking = [];
  Map<String, dynamic>? _issueInsights;

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

    final res = await _service.getGsiDashboard(month: _month, idOutlet: _idOutlet);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat dashboard GSI';
      });
      return;
    }

    setState(() {
      _loading = false;
      _canChooseOutlet = res['can_choose_outlet'] == true;
      _outlets = res['outlets'] as List<dynamic>? ?? [];
      final lo = res['locked_outlet'];
      _lockedOutlet = lo is Map ? Map<String, dynamic>.from(lo) : null;
      _summary = res['summary'] is Map<String, dynamic>
          ? res['summary'] as Map<String, dynamic>
          : null;
      _rows = res['rows'] as List<dynamic>? ?? [];
      _trend = res['trend'] as List<dynamic>? ?? [];
      _outletRanking = res['outlet_ranking'] as List<dynamic>? ?? [];
      _issueInsights = res['issue_insights'] is Map<String, dynamic>
          ? res['issue_insights'] as Map<String, dynamic>
          : null;
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse('$_month-01') ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Pilih bulan GSI',
    );
    if (d == null) return;
    setState(() => _month = DateFormat('yyyy-MM').format(d));
    _load();
  }

  String _pct(dynamic v) {
    if (v == null) return '-';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${n.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('GSI Dashboard'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFilterCard(),
                      const SizedBox(height: 12),
                      _buildSummaryCards(),
                      const SizedBox(height: 12),
                      _buildSurveyTable(),
                      const SizedBox(height: 12),
                      _buildSubjectDistributionChartCard(),
                      const SizedBox(height: 12),
                      _buildTrendCard(),
                      const SizedBox(height: 12),
                      if (_canChooseOutlet && (_idOutlet == null || _idOutlet!.isEmpty))
                        _buildOutletRankingCard(),
                      if (_canChooseOutlet && (_idOutlet == null || _idOutlet!.isEmpty))
                        const SizedBox(height: 12),
                      _buildIssueInsightCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 760;
                final monthBtn = OutlinedButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(DateFormat('MMMM yyyy', 'id_ID').format(
                    DateTime.tryParse('$_month-01') ?? DateTime.now(),
                  )),
                );
                final outletField = _canChooseOutlet
                    ? DropdownButtonFormField<String>(
                        initialValue: _idOutlet,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          labelText: 'Outlet',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Semua Outlet'),
                          ),
                          ..._outlets.map((o) {
                            final m = o as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: m['id_outlet'].toString(),
                              child: Text(
                                m['nama_outlet']?.toString() ?? '-',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) {
                          setState(() => _idOutlet = v);
                          _load();
                        },
                      )
                    : Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'Outlet: ${_lockedOutlet?['nama_outlet'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      monthBtn,
                      const SizedBox(height: 8),
                      outletField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: monthBtn),
                    const SizedBox(width: 8),
                    Expanded(child: outletField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDistributionChartCard() {
    final rows = _rows.map((e) => e as Map<String, dynamic>).toList();
    int maxVal = 0;
    for (final r in rows) {
      for (final k in const ['excellent', 'good', 'average', 'poor']) {
        final v = (r[k] is num) ? (r[k] as num).toInt() : int.tryParse('${r[k]}') ?? 0;
        if (v > maxVal) maxVal = v;
      }
    }
    if (maxVal <= 0) maxVal = 1;

    Widget bar(int value, Color color) {
      final clamped = value < 0 ? 0 : value;
      final h = clamped <= 0 ? 4.0 : ((clamped / maxVal) * 120).clamp(8.0, 120.0);
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$clamped', style: const TextStyle(fontSize: 9)),
          const SizedBox(height: 2),
          Container(
            width: 11,
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );
    }

    Widget legend(String label, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribusi Rating per Subject (Bulan Ini)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                legend('Excellent', const Color(0xFF60A5FA)),
                legend('Good', const Color(0xFFF59E0B)),
                legend('Average', const Color(0xFFA78BFA)),
                legend('Poor', const Color(0xFFEF4444)),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('Belum ada data distribusi rating.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: 190,
                  width: (rows.length * 88).toDouble().clamp(520.0, 2400.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: rows.map((r) {
                      final subject = r['subject']?.toString() ?? '-';
                      final excellent = (r['excellent'] is num)
                          ? (r['excellent'] as num).toInt()
                          : int.tryParse('${r['excellent']}') ?? 0;
                      final good = (r['good'] is num)
                          ? (r['good'] as num).toInt()
                          : int.tryParse('${r['good']}') ?? 0;
                      final average = (r['average'] is num)
                          ? (r['average'] as num).toInt()
                          : int.tryParse('${r['average']}') ?? 0;
                      final poor = (r['poor'] is num)
                          ? (r['poor'] as num).toInt()
                          : int.tryParse('${r['poor']}') ?? 0;
                      return SizedBox(
                        width: 88,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  bar(excellent, const Color(0xFF60A5FA)),
                                  const SizedBox(width: 4),
                                  bar(good, const Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                  bar(average, const Color(0xFFA78BFA)),
                                  const SizedBox(width: 4),
                                  bar(poor, const Color(0xFFEF4444)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalForms = _summary?['total_forms'] ?? 0;
    final mtd = _summary?['overall_mtd_pct'];
    final last = _summary?['overall_last_month_pct'];
    final delta = _summary?['overall_delta_pct'];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _kpi('GSI MTD', _pct(mtd), Colors.blue),
        _kpi('GSI Last Month', _pct(last), Colors.indigo),
        _kpi('Delta', _pct(delta), Colors.orange),
        _kpi('Total Forms', '$totalForms', Colors.green),
      ],
    );
  }

  Widget _kpi(String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSurveyTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guest Satisfaction Survey Summary', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Subject')),
                  DataColumn(label: Text('Exc')),
                  DataColumn(label: Text('Good')),
                  DataColumn(label: Text('Avg')),
                  DataColumn(label: Text('Poor')),
                  DataColumn(label: Text('Abstain')),
                  DataColumn(label: Text('Resp')),
                  DataColumn(label: Text('MTD')),
                  DataColumn(label: Text('Last')),
                ],
                rows: _rows.map((e) {
                  final r = e as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(r['subject']?.toString() ?? '-')),
                    DataCell(Text('${r['excellent'] ?? 0}')),
                    DataCell(Text('${r['good'] ?? 0}')),
                    DataCell(Text('${r['average'] ?? 0}')),
                    DataCell(Text('${r['poor'] ?? 0}')),
                    DataCell(Text('${r['abstain'] ?? 0}')),
                    DataCell(Text('${r['total_responses'] ?? 0}')),
                    DataCell(Text(_pct(r['mtd_pct']))),
                    DataCell(Text(_pct(r['last_month_pct']))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    final points = _trend.map((e) => e as Map<String, dynamic>).toList();
    double maxPct = 0;
    for (final p in points) {
      final v = (p['gsi_pct'] is num)
          ? (p['gsi_pct'] as num).toDouble()
          : double.tryParse('${p['gsi_pct']}') ?? 0;
      if (v > maxPct) maxPct = v;
    }
    if (maxPct <= 0) maxPct = 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trend GSI 6 Bulan', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (points.isEmpty)
              const Text('Belum ada data trend.')
            else
              ...points.map((p) {
                final raw = (p['gsi_pct'] is num)
                    ? (p['gsi_pct'] as num).toDouble()
                    : double.tryParse('${p['gsi_pct']}') ?? 0;
                final frac = (raw / maxPct).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          p['label']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        child: Text(
                          _pct(raw),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletRankingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Outlet GSI', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_outletRanking.isEmpty)
              const Text('Belum ada data outlet.')
            else
              ..._outletRanking.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final r = entry.value as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: Text('$idx', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(r['outlet_name']?.toString() ?? '-'),
                  subtitle: Text('Responses: ${r['responses'] ?? 0}'),
                  trailing: Text(
                    _pct(r['gsi_pct']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _normalizeSeverity(dynamic value) {
    return (value?.toString() ?? 'neutral').trim().toLowerCase();
  }

  bool _isNegativeSeverity(dynamic value) {
    final s = _normalizeSeverity(value);
    return s == 'mild_negative' || s == 'negative' || s == 'severe';
  }

  Color _severityColor(dynamic value) {
    final s = _normalizeSeverity(value);
    if (s == 'severe') return const Color(0xFFDC2626);
    if (s == 'negative') return const Color(0xFFD97706);
    if (s == 'mild_negative') return const Color(0xFFEA580C);
    if (s == 'positive') return const Color(0xFF059669);
    return const Color(0xFF64748B);
  }

  Color _severityBgColor(dynamic value) {
    final s = _normalizeSeverity(value);
    if (s == 'severe') return const Color(0xFFFEE2E2);
    if (s == 'negative') return const Color(0xFFFEF3C7);
    if (s == 'mild_negative') return const Color(0xFFFFEDD5);
    if (s == 'positive') return const Color(0xFFD1FAE5);
    return const Color(0xFFF1F5F9);
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  void _openIssueDetailModal(Map<String, dynamic> topic) {
    final comments = (topic['comments'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Issue Detail', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                topic['label']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${comments.length} komentar',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              const Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _SeverityLegendChip(label: 'Severe', dotColor: Color(0xFFDC2626), bgColor: Color(0xFFFEE2E2), textColor: Color(0xFFB91C1C)),
                                  _SeverityLegendChip(label: 'Negative', dotColor: Color(0xFFD97706), bgColor: Color(0xFFFEF3C7), textColor: Color(0xFF92400E)),
                                  _SeverityLegendChip(label: 'Mild Negative', dotColor: Color(0xFFEA580C), bgColor: Color(0xFFFFEDD5), textColor: Color(0xFF9A3412)),
                                  _SeverityLegendChip(label: 'Neutral', dotColor: Color(0xFF94A3B8), bgColor: Color(0xFFF1F5F9), textColor: Color(0xFF475569)),
                                  _SeverityLegendChip(label: 'Positive', dotColor: Color(0xFF10B981), bgColor: Color(0xFFD1FAE5), textColor: Color(0xFF065F46)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(child: Text('Belum ada komentar detail.'))
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(12),
                            itemCount: comments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final c = comments[index];
                              final severity = _normalizeSeverity(c['severity']);
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _severityBgColor(severity),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _severityColor(severity).withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c['author']?.toString().isNotEmpty == true
                                                ? c['author'].toString()
                                                : '-',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _severityBgColor(severity),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: _severityColor(severity).withValues(alpha: 0.35)),
                                          ),
                                          child: Text(
                                            severity.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: _severityColor(severity),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDateTime(c['created_at']),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(c['text']?.toString() ?? '-', style: const TextStyle(fontSize: 13.5, height: 1.35)),
                                    if (_isNegativeSeverity(c['severity'])) ...[
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Negative comment highlighted',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                    if ((c['summary_id']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'AI: ${c['summary_id']}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
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
      },
    );
  }

  Widget _buildIssueTopicBarRow({
    required String label,
    required int count,
    required int maxMentions,
    required VoidCallback? onTap,
  }) {
    final frac = maxMentions <= 0 ? 0.0 : (count / maxMentions).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 13,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 26,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueInsightCard() {
    final issue = _issueInsights ?? {};
    final status = issue['status']?.toString() ?? 'empty';
    final topTopics = (issue['top_topics'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final topicDetails = (issue['topic_details'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final detailByTopic = <String, Map<String, dynamic>>{};
    for (final t in topicDetails) {
      final key = t['topic']?.toString() ?? '';
      if (key.isNotEmpty) detailByTopic[key] = t;
    }

    final negativeTopicSections = topicDetails
        .map((t) {
          final comments = (t['comments'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((c) => _isNegativeSeverity(c['severity']))
              .toList();
          return {
            'topic': t['topic'],
            'label': t['label'],
            'comments': comments,
          };
        })
        .where((t) => (t['comments'] as List).isNotEmpty)
        .toList();

    final totalNegative = negativeTopicSections.fold<int>(
      0,
      (sum, t) => sum + ((t['comments'] as List).length),
    );

    int maxMentions = 1;
    for (final t in topTopics) {
      final v = (t['count'] is num) ? (t['count'] as num).toInt() : int.tryParse('${t['count']}') ?? 0;
      if (v > maxMentions) maxMentions = v;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('AI Issue Insights', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(
                  'Dataset: ${issue['total_comments'] ?? 0}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (status == 'empty')
              Text(issue['message']?.toString() ?? 'Belum ada komentar.')
            else ...[
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SeverityLegendChip(label: 'Severe', dotColor: Color(0xFFDC2626), bgColor: Color(0xFFFEE2E2), textColor: Color(0xFFB91C1C)),
                  _SeverityLegendChip(label: 'Negative', dotColor: Color(0xFFD97706), bgColor: Color(0xFFFEF3C7), textColor: Color(0xFF92400E)),
                  _SeverityLegendChip(label: 'Mild Negative', dotColor: Color(0xFFEA580C), bgColor: Color(0xFFFFEDD5), textColor: Color(0xFF9A3412)),
                  _SeverityLegendChip(label: 'Neutral', dotColor: Color(0xFF94A3B8), bgColor: Color(0xFFF1F5F9), textColor: Color(0xFF475569)),
                  _SeverityLegendChip(label: 'Positive', dotColor: Color(0xFF10B981), bgColor: Color(0xFFD1FAE5), textColor: Color(0xFF065F46)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Top Issues', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text('Klik bar untuk lihat komentar', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (topTopics.isEmpty)
                      const Text('Belum ada issue terdeteksi.')
                    else
                      ...topTopics.map((t) {
                        final topic = t['topic']?.toString() ?? '';
                        final detail = detailByTopic[topic];
                        final count = (t['count'] is num)
                            ? (t['count'] as num).toInt()
                            : int.tryParse('${t['count']}') ?? 0;
                        return _buildIssueTopicBarRow(
                          label: t['label']?.toString() ?? '-',
                          count: count,
                          maxMentions: maxMentions,
                          onTap: detail == null ? null : () => _openIssueDetailModal(detail),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              Text('Komentar Negatif Terdeteksi ($totalNegative)', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                'Menampilkan komentar dengan severity negatif dari issue yang terdeteksi.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              if (negativeTopicSections.isEmpty)
                const Text('Belum ada komentar negatif pada periode ini.')
              else
                ...negativeTopicSections.map((section) {
                  final label = section['label']?.toString() ?? '-';
                  final comments = section['comments'] as List<Map<String, dynamic>>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: () {
                                  final topicKey = section['topic']?.toString() ?? '';
                                  final detail = detailByTopic[topicKey];
                                  if (detail != null) _openIssueDetailModal(detail);
                                },
                                child: const Text('Lihat semua'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...comments.take(3).map((c) {
                            final sev = _normalizeSeverity(c['severity']);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _severityBgColor(sev),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _severityColor(sev).withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c['author']?.toString().isNotEmpty == true
                                              ? c['author'].toString()
                                              : '-',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _severityBgColor(sev),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: _severityColor(sev).withValues(alpha: 0.35)),
                                        ),
                                        child: Text(
                                          sev.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _severityColor(sev),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_formatDateTime(c['created_at']), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Negative comment highlighted',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c['text']?.toString() ?? '-', style: const TextStyle(fontSize: 12.5)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityLegendChip extends StatelessWidget {
  final String label;
  final Color dotColor;
  final Color bgColor;
  final Color textColor;

  const _SeverityLegendChip({
    required this.label,
    required this.dotColor,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }
}
