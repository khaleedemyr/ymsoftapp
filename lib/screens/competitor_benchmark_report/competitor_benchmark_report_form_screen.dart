import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/competitor_benchmark_report_models.dart';
import '../../services/competitor_benchmark_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'competitor_benchmark_report_ui.dart';

class _ItemEditorState {
  late final TextEditingController brandCtrl;
  late final TextEditingController locationCtrl;
  late final TextEditingController productCtrl;
  late final TextEditingController serviceCtrl;
  late final TextEditingController pricingCtrl;
  late final TextEditingController operationalCtrl;
  late final TextEditingController marketCtrl;
  late final TextEditingController summaryCtrl;
  late final TextEditingController actionCtrl;
  String? visitDate;

  _ItemEditorState({CbrReportItem? item}) {
    brandCtrl = TextEditingController(text: item?.brandRestaurantVisited ?? '');
    locationCtrl = TextEditingController(text: item?.location ?? '');
    productCtrl = TextEditingController(text: item?.productBenchmark ?? '');
    serviceCtrl = TextEditingController(text: item?.serviceBenchmark ?? '');
    pricingCtrl = TextEditingController(text: item?.pricingBenchmark ?? '');
    operationalCtrl = TextEditingController(text: item?.operationalBenchmark ?? '');
    marketCtrl = TextEditingController(text: item?.marketPositioningBenchmark ?? '');
    summaryCtrl = TextEditingController(text: item?.summaryReport ?? '');
    actionCtrl = TextEditingController(text: item?.developmentActionPlan ?? '');
    visitDate = item?.visitDate;
  }

  void dispose() {
    brandCtrl.dispose();
    locationCtrl.dispose();
    productCtrl.dispose();
    serviceCtrl.dispose();
    pricingCtrl.dispose();
    operationalCtrl.dispose();
    marketCtrl.dispose();
    summaryCtrl.dispose();
    actionCtrl.dispose();
  }
}

class CompetitorBenchmarkReportFormScreen extends StatefulWidget {
  final int? recordId;

  const CompetitorBenchmarkReportFormScreen({super.key, this.recordId});

  @override
  State<CompetitorBenchmarkReportFormScreen> createState() => _CompetitorBenchmarkReportFormScreenState();
}

class _CompetitorBenchmarkReportFormScreenState extends State<CompetitorBenchmarkReportFormScreen> {
  final _service = CompetitorBenchmarkReportService();
  final _notesCtrl = TextEditingController();
  final _picSearchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Timer? _picTimer;

  String _reportMonth = '';
  List<_ItemEditorState> _items = [_ItemEditorState()];
  List<CbrUserOption> _selectedPics = [];
  List<CbrUserOption> _picResults = [];
  bool _showPicResults = false;

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _reportMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() {
    _picTimer?.cancel();
    _notesCtrl.dispose();
    _picSearchCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getCreateData(recordId: widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message']?.toString() ?? 'Gagal memuat form')));
      return;
    }

    final record = res['record'] as Map?;
    if (record != null) {
      _reportMonth = record['report_month']?.toString() ?? _reportMonth;
      _notesCtrl.text = record['notes']?.toString() ?? '';
      _selectedPics = (record['pics'] as List? ?? [])
          .map((e) => CbrUserOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _items = (record['items'] as List? ?? []).map((raw) {
        return _ItemEditorState(item: CbrReportItem.fromJson(Map<String, dynamic>.from(raw as Map)));
      }).toList();
      if (_items.isEmpty) _items = [_ItemEditorState()];
    }

    setState(() => _loading = false);
  }

  Future<void> _pickMonth() async {
    DateTime initial = DateTime.now();
    if (_reportMonth.length >= 7) {
      final p = _reportMonth.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), 1);
    }
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    setState(() => _reportMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
  }

  Future<void> _pickVisitDate(_ItemEditorState item) async {
    DateTime initial = DateTime.now();
    if (item.visitDate != null && item.visitDate!.length >= 10) {
      final p = item.visitDate!.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    setState(() => item.visitDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  void _searchPics(String query) {
    _picTimer?.cancel();
    _picTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _service.searchPicUsers(query.trim());
      if (!mounted) return;
      setState(() {
        _picResults = results.where((u) => !_selectedPics.any((a) => a.id == u.id)).toList();
        _showPicResults = query.isNotEmpty && _picResults.isNotEmpty;
      });
    });
  }

  Future<void> _save() async {
    for (final item in _items) {
      if (item.brandCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brand/restaurant wajib diisi.')));
        return;
      }
    }

    setState(() => _saving = true);
    final payload = {
      'report_month': _reportMonth,
      'notes': _notesCtrl.text.trim(),
      'pic_user_ids': _selectedPics.map((e) => e.id).toList(),
      'items': _items
          .map((item) => {
                'brand_restaurant_visited': item.brandCtrl.text.trim(),
                'location': item.locationCtrl.text.trim().isEmpty ? null : item.locationCtrl.text.trim(),
                'visit_date': item.visitDate,
                'product_benchmark': item.productCtrl.text.trim().isEmpty ? null : item.productCtrl.text.trim(),
                'service_benchmark': item.serviceCtrl.text.trim().isEmpty ? null : item.serviceCtrl.text.trim(),
                'pricing_benchmark': item.pricingCtrl.text.trim().isEmpty ? null : item.pricingCtrl.text.trim(),
                'operational_benchmark': item.operationalCtrl.text.trim().isEmpty ? null : item.operationalCtrl.text.trim(),
                'market_positioning_benchmark': item.marketCtrl.text.trim().isEmpty ? null : item.marketCtrl.text.trim(),
                'summary_report': item.summaryCtrl.text.trim().isEmpty ? null : item.summaryCtrl.text.trim(),
                'development_action_plan': item.actionCtrl.text.trim().isEmpty ? null : item.actionCtrl.text.trim(),
              })
          .toList(),
    };

    final res = await _service.save(payload: payload, recordId: widget.recordId);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menyimpan')));
    }
  }

  Widget _buildItemCard(int index, _ItemEditorState item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: CompetitorBenchmarkReportUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Baris ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() {
                    item.dispose();
                    _items.removeAt(index);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: item.brandCtrl, decoration: const InputDecoration(labelText: 'Brand / Restaurant *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.locationCtrl, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickVisitDate(item),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Visit Date', border: OutlineInputBorder()),
              child: Text(item.visitDate == null ? 'Pilih tanggal' : CompetitorBenchmarkReportUi.formatDate(item.visitDate)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(controller: item.productCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Product Benchmark', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.serviceCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Service Benchmark', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.pricingCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Pricing Benchmark', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.operationalCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Operational Benchmark', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.marketCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Market & Positioning Benchmark', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.summaryCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Summary Report', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: item.actionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Development & Action Plan', border: OutlineInputBorder())),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Benchmark Report' : 'Buat Benchmark Report',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: CompetitorBenchmarkReportUi.cardDecoration,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _pickMonth,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Bulan *', border: OutlineInputBorder()),
                            child: Text(CompetitorBenchmarkReportUi.formatMonth(_reportMonth)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _picSearchCtrl,
                          decoration: const InputDecoration(labelText: 'Cari PIC', hintText: 'Nama user...', border: OutlineInputBorder()),
                          onChanged: _searchPics,
                        ),
                        if (_showPicResults)
                          ..._picResults.map((user) => ListTile(
                                dense: true,
                                title: Text(user.name),
                                subtitle: Text(user.jabatan ?? user.email ?? ''),
                                onTap: () => setState(() {
                                  _selectedPics.add(user);
                                  _picSearchCtrl.clear();
                                  _showPicResults = false;
                                }),
                              )),
                        if (_selectedPics.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedPics
                                .map((pic) => Chip(
                                      label: Text(pic.name),
                                      onDeleted: () => setState(() => _selectedPics.removeWhere((p) => p.id == pic.id)),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Daftar Benchmark', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(() => _items.add(_ItemEditorState())),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Baris'),
                      ),
                    ],
                  ),
                  ...List.generate(_items.length, (i) => _buildItemCard(i, _items[i])),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: CompetitorBenchmarkReportUi.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
