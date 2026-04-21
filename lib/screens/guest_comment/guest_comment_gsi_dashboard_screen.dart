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

  Widget _buildIssueInsightCard() {
    final issue = _issueInsights ?? {};
    final status = issue['status']?.toString() ?? 'empty';
    final topTopics = (issue['top_topics'] as List<dynamic>? ?? []);
    final examples = (issue['topic_examples'] as List<dynamic>? ?? []);

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
              ...topTopics.map((e) {
                final t = e as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_important_outline, size: 18),
                  title: Text(t['label']?.toString() ?? '-'),
                  trailing: Text('${t['count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
                );
              }),
              const Divider(),
              const Text('Contoh komentar per issue', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...examples.take(4).map((e) {
                final topic = e as Map<String, dynamic>;
                final ex = (topic['examples'] as List<dynamic>? ?? []);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic['label']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if (ex.isEmpty)
                          const Text('Belum ada contoh.')
                        else
                          Text(
                            '"${(ex.first as Map<String, dynamic>)['text']?.toString() ?? ''}"',
                            style: const TextStyle(fontSize: 12),
                          ),
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
