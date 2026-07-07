import 'package:flutter/material.dart';
import '../../models/competitor_benchmark_report_models.dart';
import '../../services/competitor_benchmark_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'competitor_benchmark_report_form_screen.dart';
import 'competitor_benchmark_report_show_screen.dart';
import 'competitor_benchmark_report_ui.dart';

class CompetitorBenchmarkReportIndexScreen extends StatefulWidget {
  const CompetitorBenchmarkReportIndexScreen({super.key});

  @override
  State<CompetitorBenchmarkReportIndexScreen> createState() => _CompetitorBenchmarkReportIndexScreenState();
}

class _CompetitorBenchmarkReportIndexScreenState extends State<CompetitorBenchmarkReportIndexScreen> {
  final _service = CompetitorBenchmarkReportService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _filterExpanded = false;
  int _page = 1;
  int _lastPage = 1;

  List<CbrReportListItem> _reports = [];
  String? _filterMonth;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _page = 1;
      if (!_loading) setState(() => _loading = true);
    } else {
      if (_loadingMore || _page >= _lastPage) return;
      setState(() => _loadingMore = true);
      _page += 1;
    }

    final res = await _service.fetchIndex(
      page: _page,
      search: _searchCtrl.text.trim(),
      month: _filterMonth,
    );

    if (!mounted) return;
    if (res == null || res['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      return;
    }

    final pagination = res['pagination'] as Map? ?? {};
    final rows = (res['reports'] as List? ?? [])
        .map((e) => CbrReportListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    setState(() {
      if (reset) {
        _reports = rows;
      } else {
        _reports = [..._reports, ...rows];
      }
      _lastPage = pagination['last_page'] as int? ?? 1;
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    DateTime initial = now;
    if (_filterMonth != null && _filterMonth!.length >= 7) {
      final p = _filterMonth!.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), 1);
    }
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    setState(() => _filterMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
  }

  void _resetFilters() {
    setState(() {
      _filterMonth = null;
      _searchCtrl.clear();
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Competitor Benchmark',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompetitorBenchmarkReportFormScreen()));
          if (mounted) _load(reset: true);
        },
        backgroundColor: CompetitorBenchmarkReportUi.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120 && !_loading && !_loadingMore) {
              _load(reset: false);
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: CompetitorBenchmarkReportUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(16)),
                child: const Text('Laporan benchmark kompetitor', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: CompetitorBenchmarkReportUi.cardDecoration,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(_filterExpanded ? 'Sembunyikan Filter' : 'Filter & Cari', style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more),
                      onTap: () => setState(() => _filterExpanded = !_filterExpanded),
                    ),
                    if (_filterExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(labelText: 'Cari', hintText: 'Nomor report atau brand...', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickMonth,
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
                                child: Text(_filterMonth == null ? 'Semua bulan' : CompetitorBenchmarkReportUi.formatMonth(_filterMonth)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: _resetFilters, child: const Text('Reset'))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _load(reset: true),
                                    style: FilledButton.styleFrom(backgroundColor: CompetitorBenchmarkReportUi.primary),
                                    child: const Text('Filter'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoadingIndicator()))
              else if (_reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: CompetitorBenchmarkReportUi.cardDecoration,
                  child: const Center(child: Text('Belum ada report.', style: TextStyle(color: CompetitorBenchmarkReportUi.textMuted))),
                )
              else
                ..._reports.map((report) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: CompetitorBenchmarkReportUi.cardDecoration,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(report.number, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CompetitorBenchmarkReportUi.formatMonth(report.reportMonth)),
                          Text('${report.itemsCount} baris · ${report.creatorName ?? '-'}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (report.canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: CompetitorBenchmarkReportUi.primary),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CompetitorBenchmarkReportFormScreen(recordId: report.id)),
                                );
                                if (mounted) _load(reset: true);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CompetitorBenchmarkReportShowScreen(recordId: report.id)),
                              ).then((_) => _load(reset: true));
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CompetitorBenchmarkReportShowScreen(recordId: report.id)),
                        ).then((_) => _load(reset: true));
                      },
                    ),
                  );
                }),
              if (_loadingMore) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}
