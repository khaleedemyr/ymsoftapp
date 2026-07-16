import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/it_work_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'it_work_report_form_screen.dart';
import 'it_work_report_show_screen.dart';
import 'it_work_report_ui.dart';

class ItWorkReportIndexScreen extends StatefulWidget {
  const ItWorkReportIndexScreen({super.key});

  @override
  State<ItWorkReportIndexScreen> createState() => _ItWorkReportIndexScreenState();
}

class _ItWorkReportIndexScreenState extends State<ItWorkReportIndexScreen> {
  final _service = ItWorkReportService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _filterExpanded = false;
  int _page = 1;
  int _lastPage = 1;

  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _sourceOptions = const {
    'proactive': 'Proaktif',
    'ticket': 'Ticket',
    'whatsapp': 'WhatsApp',
  };
  Map<String, String> _scopeOptions = {};

  String _sourceType = 'all';
  String _status = 'all';
  String _scope = '';
  String _dateFrom = '';
  String _dateTo = '';
  int? _outletId;
  List<Map<String, dynamic>> _outlets = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final create = await _service.getCreateData();
    if (mounted && create['success'] == true) {
      final data = Map<String, dynamic>.from(create['data'] as Map? ?? {});
      setState(() {
        _outlets = (data['outlets'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _sourceOptions = _asStringMap(data['sourceOptions'] ?? _sourceOptions);
        _scopeOptions = _asStringMap(data['scopeOptions'] ?? {});
      });
    }
    await _load(reset: true);
  }

  Map<String, String> _asStringMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
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

    final res = await _service.getReports(
      search: _searchCtrl.text.trim(),
      outletId: _outletId?.toString() ?? '',
      sourceType: _sourceType,
      status: _status,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      scope: _scope,
      page: _page,
    );

    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal memuat data')),
      );
      return;
    }

    final paginated = Map<String, dynamic>.from(res['data'] as Map? ?? {});
    final rows = (paginated['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      if (reset) {
        _rows = rows;
      } else {
        _rows = [..._rows, ...rows];
      }
      _lastPage = paginated['last_page'] as int? ?? 1;
      if (res['sourceOptions'] != null) {
        _sourceOptions = _asStringMap(res['sourceOptions']);
      }
      if (res['scopeOptions'] != null) {
        _scopeOptions = _asStringMap(res['scopeOptions']);
      }
      _loading = false;
      _loadingMore = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _sourceType = 'all';
      _status = 'all';
      _scope = '';
      _dateFrom = '';
      _dateTo = '';
      _outletId = null;
    });
    _load(reset: true);
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = DateTime.tryParse(from ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final v = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {
      if (from) {
        _dateFrom = v;
      } else {
        _dateTo = v;
      }
    });
  }

  String _formatDate(dynamic v) {
    if (v == null || '$v'.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse('$v'));
    } catch (_) {
      return '$v'.length >= 10 ? '$v'.substring(0, 10) : '$v';
    }
  }

  Color _statusColor(String? status) {
    return status == 'submitted' ? const Color(0xFF059669) : const Color(0xFFD97706);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'IT Work Report',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ItWorkReportFormScreen()),
          );
          if (mounted) _load(reset: true);
        },
        backgroundColor: ItWorkReportUi.primary,
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
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IT Work Report',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Laporan kunjungan IT per outlet — ticket, WhatsApp, atau proaktif',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: ItWorkReportUi.cardDecoration,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        _filterExpanded ? 'Sembunyikan Filter' : 'Filter & Cari',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more),
                      onTap: () => setState(() => _filterExpanded = !_filterExpanded),
                    ),
                    if (_filterExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cari',
                                hintText: 'Nomor, outlet, judul...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _outletId,
                              decoration: const InputDecoration(labelText: 'Outlet', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Semua')),
                                ..._outlets.map(
                                  (o) => DropdownMenuItem(
                                    value: ItWorkReportUi.outletId(o),
                                    child: Text(ItWorkReportUi.outletName(o)),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _outletId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _sourceType,
                              decoration: const InputDecoration(labelText: 'Sumber', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('Semua')),
                                ..._sourceOptions.entries.map(
                                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                                ),
                              ],
                              onChanged: (v) => setState(() => _sourceType = v ?? 'all'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Semua')),
                                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? 'all'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _scope.isEmpty ? '' : _scope,
                              decoration: const InputDecoration(labelText: 'Scope', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('Semua')),
                                ..._scopeOptions.entries.map(
                                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                                ),
                              ],
                              onChanged: (v) => setState(() => _scope = v ?? ''),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickDate(from: true),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Dari', border: OutlineInputBorder()),
                                      child: Text(_dateFrom.isEmpty ? '—' : _dateFrom),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickDate(from: false),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Sampai', border: OutlineInputBorder()),
                                      child: Text(_dateTo.isEmpty ? '—' : _dateTo),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: _resetFilters, child: const Text('Reset'))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _load(reset: true),
                                    style: FilledButton.styleFrom(backgroundColor: ItWorkReportUi.primary),
                                    child: const Text('Filter'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoadingIndicator()))
              else if (_rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: ItWorkReportUi.cardDecoration,
                  child: const Center(
                    child: Text('Belum ada IT Work Report.', style: TextStyle(color: ItWorkReportUi.textMuted)),
                  ),
                )
              else
                ..._rows.map((row) {
                  final id = row['id'] as int? ?? int.tryParse('${row['id']}') ?? 0;
                  final status = row['status']?.toString() ?? '';
                  final source = row['source_type']?.toString() ?? '';
                  final ticket = row['ticket'] is Map ? Map<String, dynamic>.from(row['ticket'] as Map) : null;
                  final executor = row['executor'] is Map ? Map<String, dynamic>.from(row['executor'] as Map) : null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: ItWorkReportUi.cardDecoration,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        row['number']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: ItWorkReportUi.primary),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${_formatDate(row['work_date'])} · ${row['outlet_name'] ?? '-'}'),
                          Text(
                            '${_sourceOptions[source] ?? source} · ${executor?['nama_lengkap'] ?? '-'} · ${row['items_count'] ?? 0} device',
                            style: const TextStyle(fontSize: 12, color: ItWorkReportUi.textMuted),
                          ),
                          if (ticket != null)
                            Text(
                              ticket['ticket_number']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12, color: ItWorkReportUi.textMuted),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status == 'submitted' ? 'Submitted' : 'Draft',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                            ),
                          ),
                          if (status == 'draft')
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Color(0xFFD97706)),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ItWorkReportFormScreen(reportId: id)),
                                );
                                if (mounted) _load(reset: true);
                              },
                            ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ItWorkReportShowScreen(reportId: id)),
                        );
                        if (mounted) _load(reset: true);
                      },
                    ),
                  );
                }),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: AppLoadingIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
