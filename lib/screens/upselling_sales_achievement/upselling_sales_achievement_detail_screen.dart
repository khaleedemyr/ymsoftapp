import 'package:flutter/material.dart';
import '../../models/upselling_sales_achievement_models.dart';
import '../../services/upselling_sales_achievement_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'upselling_sales_achievement_form_screen.dart';
import 'upselling_sales_achievement_ui.dart';

class UpsellingSalesAchievementDetailScreen extends StatefulWidget {
  final int recordId;

  const UpsellingSalesAchievementDetailScreen({super.key, required this.recordId});

  @override
  State<UpsellingSalesAchievementDetailScreen> createState() =>
      _UpsellingSalesAchievementDetailScreenState();
}

class _UpsellingSalesAchievementDetailScreenState
    extends State<UpsellingSalesAchievementDetailScreen> {
  final _service = UpsellingSalesAchievementService();

  bool _loading = true;
  Map<String, dynamic>? _record;
  List<UpsellingDetailRow> _rows = [];
  Map<String, dynamic> _totals = {};
  String _monthLabel = '';
  double _overallPercent = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDetail(widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map? ?? {});
    _monthLabel = res['month_label']?.toString() ?? '';
    final detail = res['detail'] as Map? ?? {};
    _rows = (detail['rows'] as List? ?? [])
        .map((e) => UpsellingDetailRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _totals = Map<String, dynamic>.from(detail['totals'] as Map? ?? {});

    final targetRev = (_totals['target_fb_revenue'] as num?)?.toDouble() ?? 0;
    final actualRev = (_totals['actual_fb_revenue'] as num?)?.toDouble() ?? 0;
    _overallPercent = targetRev > 0 ? (actualRev / targetRev) * 100 : 0;

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final outlet = _record?['outlet_name']?.toString() ?? '-';
    final year = _record?['year']?.toString() ?? '';

    return AppScaffold(
      title: 'Detail Upselling',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: _loading
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpsellingSalesAchievementFormScreen(recordId: widget.recordId),
                    ),
                  );
                  _load();
                },
        ),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outlet,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_monthLabel $year',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _headerStat('Achievement', UpsellingUi.formatPercent(_overallPercent)),
                            const SizedBox(width: 16),
                            _headerStat('Item', '${_rows.length}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _metaRow(),
                  const SizedBox(height: 16),
                  ..._rows.map(_buildItemCard),
                  if (_rows.isNotEmpty) _buildTotalsCard(),
                ],
              ),
            ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _metaRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: UpsellingUi.cardDecoration,
      child: Column(
        children: [
          _metaLine('Created By', _record?['created_by_name']?.toString() ?? '-'),
          const Divider(height: 20),
          _metaLine('Created At', UpsellingUi.formatDateTime(_record?['created_at']?.toString())),
        ],
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: UpsellingUi.textMuted, fontSize: 13))),
        Expanded(
          flex: 2,
          child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildItemCard(UpsellingDetailRow row) {
    final pct = row.achievementPercent;
    final target = row.target;
    final actual = row.actual;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: UpsellingUi.cardDecoration,
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
                    Text(row.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (row.categoryLabel != null && row.categoryLabel!.isNotEmpty)
                      Text(row.categoryLabel!, style: const TextStyle(fontSize: 12, color: UpsellingUi.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: UpsellingUi.achievementBg(pct),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  UpsellingUi.formatPercent(pct),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: UpsellingUi.achievementColor(pct),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Target', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: UpsellingUi.textMuted)),
          const SizedBox(height: 6),
          _metricRow(
            UpsellingUi.formatCurrency((target['average_check'] as num?) ?? 0),
            '${(target['cover'] as num?)?.toString() ?? '0'}',
            UpsellingUi.formatCurrency((target['fb_revenue'] as num?) ?? 0),
          ),
          const SizedBox(height: 12),
          const Text('Actual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: UpsellingUi.textMuted)),
          const SizedBox(height: 6),
          _metricRow(
            UpsellingUi.formatCurrency((actual['average_check'] as num?) ?? 0),
            '${(actual['cover'] as num?)?.toString() ?? '0'}',
            UpsellingUi.formatCurrency((actual['fb_revenue'] as num?) ?? 0),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String avg, String cover, String revenue) {
    return Row(
      children: [
        Expanded(child: _miniMetric('Avg', avg)),
        const SizedBox(width: 8),
        Expanded(child: _miniMetric('Cover', cover)),
        const SizedBox(width: 8),
        Expanded(child: _miniMetric('Revenue', revenue)),
      ],
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: UpsellingUi.surface, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: UpsellingUi.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          _totalLine('Target Cover', '${_totals['target_cover'] ?? 0}'),
          _totalLine('Target FB Revenue', UpsellingUi.formatCurrency((_totals['target_fb_revenue'] as num?) ?? 0)),
          const Divider(color: Colors.white24),
          _totalLine('Actual Cover', '${_totals['actual_cover'] ?? 0}'),
          _totalLine('Actual FB Revenue', UpsellingUi.formatCurrency((_totals['actual_fb_revenue'] as num?) ?? 0)),
          const SizedBox(height: 8),
          Text(
            'Achievement ${UpsellingUi.formatPercent(_overallPercent)}',
            style: TextStyle(
              color: UpsellingUi.achievementColor(_overallPercent),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
