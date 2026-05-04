import 'package:flutter/material.dart';

import 'google_review_drilldown_screen.dart';

class GoogleReviewDashboardPanel extends StatelessWidget {
  final Map<String, dynamic>? dashboard;
  final VoidCallback? onRefresh;
  final bool loading;

  const GoogleReviewDashboardPanel({
    super.key,
    required this.dashboard,
    this.onRefresh,
    this.loading = false,
  });

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _barPct(int v, int maxVal) {
    if (maxVal <= 0) return 0;
    return (v / maxVal * 100).clamp(0, 100);
  }

  String _sevLabel(String key) {
    switch (key) {
      case 'positive':
        return 'Positif';
      case 'neutral':
        return 'Netral';
      case 'mild_negative':
        return 'Negatif ringan';
      case 'negative':
        return 'Negatif';
      case 'severe':
        return 'Sangat parah';
      default:
        return key;
    }
  }

  int _maxSentiment(Map<String, dynamic>? m) {
    if (m == null) return 1;
    var mx = 1;
    for (final v in m.values) {
      final n = _toInt(v);
      if (n > mx) mx = n;
    }
    return mx;
  }

  @override
  Widget build(BuildContext context) {
    final dash = dashboard;
    if (loading && dash == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (dash == null) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh?.call(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Dashboard belum dimuat. Tarik ke bawah atau ketuk ikon workspace untuk menyegarkan.')),
          ],
        ),
      );
    }

    final cards = dash['cards'] is Map ? Map<String, dynamic>.from(dash['cards'] as Map) : <String, dynamic>{};
    final sentiment = dash['sentiment'] is Map ? Map<String, dynamic>.from(dash['sentiment'] as Map) : <String, dynamic>{};
    final sentGoogle = sentiment['google'] is Map ? Map<String, dynamic>.from(sentiment['google'] as Map) : <String, dynamic>{};
    final sentIg = sentiment['instagram'] is Map ? Map<String, dynamic>.from(sentiment['instagram'] as Map) : <String, dynamic>{};

    final topicG = dash['topNegativeTopics'] is Map
        ? ((dash['topNegativeTopics'] as Map)['google'] as List?)
        : null;
    final topicI = dash['topNegativeTopics'] is Map
        ? ((dash['topNegativeTopics'] as Map)['instagram'] as List?)
        : null;

    final daily = dash['daily'] is List ? (dash['daily'] as List) : [];
    final profileRisk = dash['profileRisk'] is List ? (dash['profileRisk'] as List) : [];
    final insights = dash['aiInsights'] is List ? (dash['aiInsights'] as List) : [];
    final recs = dash['recommendedActions'] is List ? (dash['recommendedActions'] as List) : [];
    final weekly = dash['weeklySpike'] is Map ? Map<String, dynamic>.from(dash['weeklySpike'] as Map) : <String, dynamic>{};

    final gMax = _maxSentiment(sentGoogle);
    final iMax = _maxSentiment(sentIg);

    int topicMax(List? rows) {
      if (rows == null) return 1;
      var m = 1;
      for (final r in rows) {
        if (r is Map) {
          final t = _toInt(r['total']);
          if (t > m) m = t;
        }
      }
      return m;
    }

    final tgMax = topicMax(topicG);
    final tiMax = topicMax(topicI);

    void openDrill(String channel, String metric, String key) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GoogleReviewDrilldownScreen(
            channel: channel,
            metric: metric,
            keyLabel: key,
          ),
        ),
      );
    }

    Widget barRow(String label, int value, int maxVal, VoidCallback onTap, {bool ig = false}) {
      final fill = ig ? const Color(0xFFDB2777) : const Color(0xFF2563EB);
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12))),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _barPct(value, maxVal) / 100,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 36, child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh?.call(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dashboard & AI Insights', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniCard('IG Posts', '${_toInt(cards['instagram_posts'])}'),
              _miniCard('IG Komentar', '${_toInt(cards['instagram_comments'])}'),
              _miniCard('Laporan AI', '${_toInt(cards['ai_reports_completed'])}'),
              _miniCard('Item AI', '${_toInt(cards['ai_items_total'])}'),
            ],
          ),
          const SizedBox(height: 12),
          for (final ins in insights)
            if (ins is Map)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ins['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(ins['detail']?.toString() ?? ''),
                ),
              ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spike mingguan', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    'IG komentar: ${weekly['instagram_comments'] is Map ? (weekly['instagram_comments'] as Map)['current_7d'] : '-'} vs sebelumnya ${weekly['instagram_comments'] is Map ? (weekly['instagram_comments'] as Map)['previous_7d'] : '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  Text(
                    'IG negatif: ${weekly['instagram_negative'] is Map ? (weekly['instagram_negative'] as Map)['current_7d'] : '-'} (Δ ${weekly['instagram_negative'] is Map ? (weekly['instagram_negative'] as Map)['change_pct'] : '-' }%)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Sentimen Google (ketuk baris untuk detail)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ...['positive', 'neutral', 'mild_negative', 'negative', 'severe'].map((k) {
            final v = _toInt(sentGoogle[k]);
            return barRow(_sevLabel(k), v, gMax, () => openDrill('google', 'sentiment', k));
          }),
          const SizedBox(height: 12),
          Text('Sentimen Instagram', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ...['positive', 'neutral', 'mild_negative', 'negative', 'severe'].map((k) {
            final v = _toInt(sentIg[k]);
            return barRow(_sevLabel(k), v, iMax, () => openDrill('instagram', 'sentiment', k), ig: true);
          }),
          const SizedBox(height: 12),
          Text('Top isu negatif Google', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          if (topicG == null || topicG.isEmpty)
            Text('Belum ada data.', style: TextStyle(color: Colors.grey.shade600))
          else
            ...topicG.map((row) {
              if (row is! Map) return const SizedBox.shrink();
              final topic = row['topic']?.toString() ?? '';
              final total = _toInt(row['total']);
              return barRow(topic, total, tgMax, () => openDrill('google', 'topic', topic));
            }),
          const SizedBox(height: 12),
          Text('Top isu negatif Instagram', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          if (topicI == null || topicI.isEmpty)
            Text('Belum ada data.', style: TextStyle(color: Colors.grey.shade600))
          else
            ...topicI.map((row) {
              if (row is! Map) return const SizedBox.shrink();
              final topic = row['topic']?.toString() ?? '';
              final total = _toInt(row['total']);
              return barRow(topic, total, tiMax, () => openDrill('instagram', 'topic', topic), ig: true);
            }),
          const SizedBox(height: 12),
          Text('Rekomendasi aksi', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ...recs.map((r) {
            if (r is! Map) return const SizedBox.shrink();
            return ListTile(
              dense: true,
              title: Text('${r['channel'] ?? '-'} • ${r['topic'] ?? '-'}'),
              subtitle: Text(r['action']?.toString() ?? ''),
            );
          }),
          const SizedBox(height: 12),
          Text('Tren 14 hari', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('IG komentar')),
                DataColumn(label: Text('AI klasifikasi')),
              ],
              rows: daily.map((r) {
                final m = r is Map<String, dynamic> ? Map<String, dynamic>.from(r) : <String, dynamic>{};
                return DataRow(cells: [
                  DataCell(Text(m['date']?.toString() ?? '-')),
                  DataCell(Text('${_toInt(m['instagram_comments'])}')),
                  DataCell(Text('${_toInt(m['ai_classified'])}')),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Profil IG risiko', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ...profileRisk.map((r) {
            if (r is! Map) return const SizedBox.shrink();
            return ListTile(
              dense: true,
              title: Text(r['profile']?.toString() ?? '-'),
              subtitle: Text(
                'Negatif ${_toInt(r['negative_count'])}/${_toInt(r['total_count'])} (${r['negative_rate'] ?? '-'}%)',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniCard(String title, String value) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
