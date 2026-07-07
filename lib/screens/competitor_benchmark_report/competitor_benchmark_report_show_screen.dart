import 'package:flutter/material.dart';
import '../../models/competitor_benchmark_report_models.dart';
import '../../services/competitor_benchmark_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'competitor_benchmark_report_form_screen.dart';
import 'competitor_benchmark_report_ui.dart';

class CompetitorBenchmarkReportShowScreen extends StatefulWidget {
  final int recordId;

  const CompetitorBenchmarkReportShowScreen({super.key, required this.recordId});

  @override
  State<CompetitorBenchmarkReportShowScreen> createState() => _CompetitorBenchmarkReportShowScreenState();
}

class _CompetitorBenchmarkReportShowScreenState extends State<CompetitorBenchmarkReportShowScreen> {
  final _service = CompetitorBenchmarkReportService();

  bool _loading = true;
  Map<String, dynamic>? _record;
  List<CbrReportItem> _items = [];
  bool _canEdit = false;
  bool _canDelete = false;

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat detail')));
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map);
    _items = (_record!['items'] as List? ?? [])
        .map((e) => CbrReportItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _canEdit = res['can_edit'] == true;
    _canDelete = res['can_delete'] == true;

    setState(() => _loading = false);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Report?'),
        content: Text('Report ${_record?['number']} akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _service.delete(widget.recordId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: CompetitorBenchmarkReportUi.textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _itemCard(int index, CbrReportItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: CompetitorBenchmarkReportUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${item.brandRestaurantVisited}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          _infoRow('Location', item.location ?? '-'),
          _infoRow('Visit Date', CompetitorBenchmarkReportUi.formatDate(item.visitDate)),
          _infoRow('Product Benchmark', item.productBenchmark ?? '-'),
          _infoRow('Service Benchmark', item.serviceBenchmark ?? '-'),
          _infoRow('Pricing Benchmark', item.pricingBenchmark ?? '-'),
          _infoRow('Operational Benchmark', item.operationalBenchmark ?? '-'),
          _infoRow('Market & Positioning', item.marketPositioningBenchmark ?? '-'),
          _infoRow('Summary Report', item.summaryReport ?? '-'),
          _infoRow('Development & Action Plan', item.developmentActionPlan ?? '-'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _record?['number']?.toString() ?? 'Detail Report',
      actions: [
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CompetitorBenchmarkReportFormScreen(recordId: widget.recordId)));
              if (mounted) _load();
            },
          ),
        if (_canDelete)
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _confirmDelete),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: CompetitorBenchmarkReportUi.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_record?['number']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        _infoRow('Bulan', CompetitorBenchmarkReportUi.formatMonth(_record?['report_month']?.toString())),
                        _infoRow('PIC', CompetitorBenchmarkReportUi.joinPicNames(_record?['pics'] as List?)),
                        _infoRow('Dibuat Oleh', (_record?['creator'] as Map?)?['nama_lengkap']?.toString() ?? '-'),
                        if ((_record?['notes']?.toString() ?? '').isNotEmpty) _infoRow('Catatan', _record!['notes'].toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Daftar Benchmark (${_items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...List.generate(_items.length, (i) => _itemCard(i, _items[i])),
                ],
              ),
            ),
    );
  }
}
