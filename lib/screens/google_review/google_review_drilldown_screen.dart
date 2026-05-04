import 'package:flutter/material.dart';

import '../../services/google_review_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class GoogleReviewDrilldownScreen extends StatefulWidget {
  final String channel;
  final String metric;
  final String keyLabel;

  const GoogleReviewDrilldownScreen({
    super.key,
    required this.channel,
    required this.metric,
    required this.keyLabel,
  });

  @override
  State<GoogleReviewDrilldownScreen> createState() => _GoogleReviewDrilldownScreenState();
}

class _GoogleReviewDrilldownScreenState extends State<GoogleReviewDrilldownScreen> {
  final GoogleReviewService _service = GoogleReviewService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String? _error;

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 120;
  int _days = 30;
  String _sort = 'date_desc';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final targetPage = page ?? _page;
    final result = await _service.dashboardDrilldown(
      channel: widget.channel,
      metric: widget.metric,
      key: widget.keyLabel,
      days: _days,
      limit: _perPage,
      page: targetPage,
      q: _searchController.text.trim(),
      sort: _sort,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['error']?.toString() ?? 'Gagal memuat drilldown';
      });
      return;
    }

    final raw = result['items'];
    final list = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final meta = result['meta'] is Map ? Map<String, dynamic>.from(result['meta'] as Map) : <String, dynamic>{};
    final p = meta['page'] is int ? meta['page'] as int : int.tryParse(meta['page']?.toString() ?? '') ?? targetPage;
    final lp = meta['last_page'] is int
        ? meta['last_page'] as int
        : int.tryParse(meta['last_page']?.toString() ?? '') ?? 1;
    final tot = meta['total'] is int ? meta['total'] as int : int.tryParse(meta['total']?.toString() ?? '') ?? 0;

    setState(() {
      _items = list;
      _page = p;
      _lastPage = lp <= 0 ? 1 : lp;
      _total = tot;
      _loading = false;
    });
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    final result = await _service.exportDashboardDrilldownCsv(
      channel: widget.channel,
      metric: widget.metric,
      key: widget.keyLabel,
      days: _days,
      q: _searchController.text.trim(),
      sort: _sort,
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    final messenger = ScaffoldMessenger.of(context);
    if (result['success'] == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Export dibuka')));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result['error']?.toString() ?? 'Export gagal')));
    }
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

  @override
  void initState() {
    super.initState();
    _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail ${widget.channel}',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Export CSV',
          onPressed: _exporting ? null : _exportCsv,
          icon: _exporting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.metric}: ${widget.keyLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text('Total: $_total • Halaman $_page / $_lastPage', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Cari author / text',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search_rounded),
                            onPressed: () => _load(page: 1),
                          ),
                        ),
                        onSubmitted: (_) => _load(page: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownButton<int>(
                      value: _perPage,
                      items: const [
                        DropdownMenuItem(value: 50, child: Text('50 / hal')),
                        DropdownMenuItem(value: 100, child: Text('100 / hal')),
                        DropdownMenuItem(value: 120, child: Text('120 / hal')),
                        DropdownMenuItem(value: 200, child: Text('200 / hal')),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _perPage = v);
                              _load(page: 1);
                            },
                    ),
                    DropdownButton<int>(
                      value: _days,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 hari')),
                        DropdownMenuItem(value: 14, child: Text('14 hari')),
                        DropdownMenuItem(value: 30, child: Text('30 hari')),
                        DropdownMenuItem(value: 90, child: Text('90 hari')),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _days = v);
                              _load(page: 1);
                            },
                    ),
                    DropdownButton<String>(
                      value: _sort,
                      items: const [
                        DropdownMenuItem(value: 'date_desc', child: Text('Tanggal ↓')),
                        DropdownMenuItem(value: 'date_asc', child: Text('Tanggal ↑')),
                        DropdownMenuItem(value: 'severity_desc', child: Text('Severity ↓')),
                        DropdownMenuItem(value: 'severity_asc', child: Text('Severity ↑')),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _sort = v);
                              _load(page: 1);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: (_loading || _page <= 1) ? null : () => _load(page: _page - 1),
                  child: const Text('Prev'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: (_loading || _page >= _lastPage) ? null : () => _load(page: _page + 1),
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: AppLoadingIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
                    : RefreshIndicator(
                        onRefresh: () => _load(page: _page),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final it = _items[index];
                            final sev = it['severity']?.toString() ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            it['author']?.toString().isNotEmpty == true ? it['author'].toString() : '-',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Text(_sevLabel(sev), style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                                      ],
                                    ),
                                    Text(
                                      it['review_date']?.toString() ?? '-',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    if ((it['summary_id']?.toString() ?? '').isNotEmpty)
                                      Text(
                                        'Summary: ${it['summary_id']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(it['text']?.toString() ?? '-', style: const TextStyle(height: 1.35)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
