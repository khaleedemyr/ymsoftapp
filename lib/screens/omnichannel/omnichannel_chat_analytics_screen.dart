import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/omnichannel_chat_analytics_service.dart';
import '../../utils/omni_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OmnichannelChatAnalyticsScreen extends StatefulWidget {
  const OmnichannelChatAnalyticsScreen({super.key});

  @override
  State<OmnichannelChatAnalyticsScreen> createState() => _OmnichannelChatAnalyticsScreenState();
}

class _OmnichannelChatAnalyticsScreenState extends State<OmnichannelChatAnalyticsScreen> {
  final _service = OmnichannelChatAnalyticsService();
  bool _loading = true;
  OmniChatAnalyticsData? _data;
  String? _dateFrom;
  String? _dateTo;
  String _channel = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetch(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        channel: _channel,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _dateFrom = data.filters['date_from'] as String?;
          _dateTo = data.filters['date_to'] as String?;
          _channel = (data.filters['channel'] as String?) ?? 'all';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = DateTime.tryParse((isFrom ? _dateFrom : _dateTo) ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    final iso = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {
      if (isFrom) {
        _dateFrom = iso;
      } else {
        _dateTo = iso;
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final summary = data?.summary ?? {};
    final series = data?.series ?? {};
    final labels = (series['labels'] as List? ?? []).map((e) => '$e').toList();
    final newChats = (series['new_chats'] as List? ?? []).map((e) => (e as num?)?.toInt() ?? 0).toList();
    final inbound = (series['inbound_messages'] as List? ?? []).map((e) => (e as num?)?.toInt() ?? 0).toList();
    final outbound = (series['outbound_messages'] as List? ?? []).map((e) => (e as num?)?.toInt() ?? 0).toList();
    final frt = (series['avg_first_response_minutes'] as List? ?? [])
        .map((e) => e == null ? null : (e as num).toDouble())
        .toList();
    final byChannel = summary['by_channel'] as List? ?? [];

    return AppScaffold(
      title: 'Analisis Chat',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: OmniTheme.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _filterCard(data),
                  const SizedBox(height: 16),
                  _summaryGrid(summary),
                  const SizedBox(height: 20),
                  _chartCard(
                    title: 'Chat masuk per hari',
                    color: OmniTheme.primary,
                    labels: labels,
                    values: newChats,
                  ),
                  const SizedBox(height: 16),
                  _dualChartCard(
                    title: 'Pesan diterima vs terkirim',
                    labels: labels,
                    seriesA: inbound,
                    seriesB: outbound,
                    colorA: const Color(0xFF0EA5E9),
                    colorB: const Color(0xFF10B981),
                    labelA: 'Diterima',
                    labelB: 'Terkirim',
                  ),
                  const SizedBox(height: 16),
                  _lineChartCard(
                    title: 'Rata-rata balas pertama (menit)',
                    labels: labels,
                    values: frt,
                    color: const Color(0xFFF59E0B),
                  ),
                  if (byChannel.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Per kanal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: OmniTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    ...byChannel.map((row) {
                      final m = Map<String, dynamic>.from(row as Map);
                      return _channelRow(m);
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _filterCard(OmniChatAnalyticsData? data) {
    final options = data?.channelOptions ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: true),
                  child: Text(_dateFrom ?? 'Dari tanggal', style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: false),
                  child: Text(_dateTo ?? 'Sampai tanggal', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _channel,
            decoration: const InputDecoration(labelText: 'Kanal', border: OutlineInputBorder(), isDense: true),
            items: options
                .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _channel = v);
              _load();
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Terapkan filter'),
            style: FilledButton.styleFrom(backgroundColor: OmniTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid(Map<String, dynamic> summary) {
    final items = [
      ('Chat masuk', '${summary['new_chats'] ?? 0}'),
      ('Pesan diterima', '${summary['inbound_messages'] ?? 0}'),
      ('Pesan terkirim', '${summary['outbound_messages'] ?? 0}'),
      ('Balas pertama', '${summary['avg_first_response_label'] ?? '—'}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: items
          .map(
            (e) => Container(
              padding: const EdgeInsets.all(14),
              decoration: OmniTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.$1, style: const TextStyle(fontSize: 12, color: OmniTheme.textSecondary)),
                  const Spacer(),
                  Text(
                    e.$2,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: OmniTheme.textPrimary),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _chartCard({
    required String title,
    required Color color,
    required List<String> labels,
    required List<int> values,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _SimpleBarChart(labels: labels, values: values.map((e) => e.toDouble()).toList(), color: color),
        ],
      ),
    );
  }

  Widget _dualChartCard({
    required String title,
    required List<String> labels,
    required List<int> seriesA,
    required List<int> seriesB,
    required Color colorA,
    required Color colorB,
    required String labelA,
    required String labelB,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(colorA, labelA),
              const SizedBox(width: 12),
              _legendDot(colorB, labelB),
            ],
          ),
          const SizedBox(height: 12),
          _SimpleBarChart(
            labels: labels,
            values: seriesA.map((e) => e.toDouble()).toList(),
            color: colorA,
            secondaryValues: seriesB.map((e) => e.toDouble()).toList(),
            secondaryColor: colorB,
          ),
        ],
      ),
    );
  }

  Widget _lineChartCard({
    required String title,
    required List<String> labels,
    required List<double?> values,
    required Color color,
  }) {
    final numeric = values.map((e) => e ?? 0.0).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _SimpleBarChart(labels: labels, values: numeric, color: color),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary)),
      ],
    );
  }

  Widget _channelRow(Map<String, dynamic> row) {
    final label = (row['label'] ?? row['channel'] ?? '') as String;
    final newChats = (row['new_chats'] as num?)?.toInt() ?? 0;
    final inbound = (row['inbound'] as num?)?.toInt() ?? 0;
    final outbound = (row['outbound'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: OmniTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Chat masuk: $newChats · Diterima: $inbound · Terkirim: $outbound',
              style: const TextStyle(fontSize: 12, color: OmniTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color color;
  final List<double>? secondaryValues;
  final Color? secondaryColor;

  const _SimpleBarChart({
    required this.labels,
    required this.values,
    required this.color,
    this.secondaryValues,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Text('Tidak ada data', style: TextStyle(color: OmniTheme.textSecondary));
    }
    final maxVal = [
      ...values,
      if (secondaryValues != null) ...secondaryValues!,
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final peak = maxVal <= 0 ? 1.0 : maxVal;

    String dayLabel(String iso) {
      final d = DateTime.tryParse('${iso}T12:00:00');
      if (d == null) return iso;
      return DateFormat('d MMM', 'id_ID').format(d);
    }

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final h1 = (values[i] / peak) * 120;
          final h2 = secondaryValues != null ? (secondaryValues![i] / peak) * 120 : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryValues != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            height: h1.clamp(2, 120),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            height: h2.clamp(2, 120),
                            decoration: BoxDecoration(
                              color: (secondaryColor ?? color).withValues(alpha: 0.65),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      height: h1.clamp(2, 120),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    i < labels.length ? dayLabel(labels[i]) : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8, color: OmniTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
