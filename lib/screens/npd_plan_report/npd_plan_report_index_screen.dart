import 'package:flutter/material.dart';
import '../../models/npd_plan_report_models.dart';
import '../../services/npd_plan_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'npd_plan_report_form_screen.dart';
import 'npd_plan_report_show_screen.dart';
import 'npd_plan_report_report_screen.dart';
import 'npd_plan_report_ui.dart';

class NpdPlanReportIndexScreen extends StatefulWidget {
  const NpdPlanReportIndexScreen({super.key});

  @override
  State<NpdPlanReportIndexScreen> createState() => _NpdPlanReportIndexScreenState();
}

class _NpdPlanReportIndexScreenState extends State<NpdPlanReportIndexScreen> {
  final _service = NpdPlanReportService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _filterExpanded = false;
  int _page = 1;
  int _lastPage = 1;

  List<NpdReportListItem> _reports = [];
  List<Map<String, dynamic>> _outlets = [];
  String? _filterMonth;
  int? _filterOutletId;
  String _filterStatus = '';

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

  bool get _hasActiveFilters =>
      _filterMonth != null || _filterOutletId != null || _filterStatus.isNotEmpty || _searchCtrl.text.trim().isNotEmpty;

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
      outletId: _filterOutletId,
      status: _filterStatus.isEmpty ? null : _filterStatus,
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
        .map((e) => NpdReportListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    setState(() {
      if (reset) {
        _reports = rows;
        _outlets = (res['outlets'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filterMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
    });
  }

  void _resetFilters() {
    setState(() {
      _filterMonth = null;
      _filterOutletId = null;
      _filterStatus = '';
      _searchCtrl.clear();
    });
    _load(reset: true);
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NpdPlanReportUi.statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        NpdPlanReportUi.statusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NpdPlanReportUi.statusColor(status)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'NPD Plan & Report',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NpdPlanReportFormScreen()));
          if (mounted) _load(reset: true);
        },
        backgroundColor: NpdPlanReportUi.primary,
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
                decoration: NpdPlanReportUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  'Rencana dan laporan pengembangan produk F&B per outlet',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NpdPlanReportReportScreen()),
                    );
                  },
                  icon: const Icon(Icons.bar_chart_outlined, size: 20),
                  label: const Text('Report'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NpdPlanReportUi.primary,
                    side: BorderSide(color: NpdPlanReportUi.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: NpdPlanReportUi.cardDecoration,
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
                              decoration: const InputDecoration(
                                labelText: 'Cari',
                                hintText: 'Nomor report atau outlet...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickMonth,
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
                                child: Text(_filterMonth == null ? 'Semua bulan' : NpdPlanReportUi.formatMonth(_filterMonth)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _filterOutletId,
                              decoration: const InputDecoration(labelText: 'Outlet', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Semua')),
                                ..._outlets.map((o) => DropdownMenuItem<int?>(
                                      value: NpdPlanReportUi.outletId(o),
                                      child: Text(NpdPlanReportUi.outletName(o)),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _filterOutletId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _filterStatus.isEmpty ? '' : _filterStatus,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: '', child: Text('Semua')),
                                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                                DropdownMenuItem(value: 'rejected', child: Text('Not Approved')),
                                DropdownMenuItem(value: 'requires_revision', child: Text('Requires Revision')),
                              ],
                              onChanged: (v) => setState(() => _filterStatus = v ?? ''),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(onPressed: _resetFilters, child: const Text('Reset')),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _load(reset: true),
                                    style: FilledButton.styleFrom(backgroundColor: NpdPlanReportUi.primary),
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
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Filter aktif', style: TextStyle(fontSize: 12, color: NpdPlanReportUi.textMuted)),
                ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoadingIndicator()))
              else if (_reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: NpdPlanReportUi.cardDecoration,
                  child: const Center(child: Text('Belum ada report.', style: TextStyle(color: NpdPlanReportUi.textMuted))),
                )
              else
                ..._reports.map((report) {
                  final canEdit = ['submitted', 'approved', 'rejected', 'requires_revision'].contains(report.status);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: NpdPlanReportUi.cardDecoration,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(report.number, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${NpdPlanReportUi.formatMonth(report.reportMonth)} · ${report.outletName}'),
                          Text('${report.itemsCount} produk · ${report.creatorName ?? '-'}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          _statusChip(report.status),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: NpdPlanReportUi.primary),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => NpdPlanReportFormScreen(recordId: report.id)),
                                );
                                if (mounted) _load(reset: true);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => NpdPlanReportShowScreen(recordId: report.id)),
                              );
                              if (mounted) _load(reset: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (_loadingMore)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: AppLoadingIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}
