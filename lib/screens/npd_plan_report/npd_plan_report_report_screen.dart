import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/npd_plan_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'npd_plan_report_ui.dart';

class NpdPlanReportReportScreen extends StatefulWidget {
  const NpdPlanReportReportScreen({super.key});

  @override
  State<NpdPlanReportReportScreen> createState() => _NpdPlanReportReportScreenState();
}

class _NpdPlanReportReportScreenState extends State<NpdPlanReportReportScreen> {
  final _service = NpdPlanReportService();
  final _searchCtrl = TextEditingController();

  bool _loadingFilters = true;
  bool _loadingReport = false;
  bool _exporting = false;
  bool _showReport = false;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _purposeOptions = [];
  List<Map<String, dynamic>> _statusOptions = [];
  List<Map<String, dynamic>> _rows = [];
  int _total = 0;

  String? _monthFrom;
  String? _monthTo;
  int? _outletId;
  String _status = '';
  String _purpose = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthFrom = _formatYm(now);
    _monthTo = _formatYm(now);
    _loadFilters();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatYm(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  Future<void> _loadFilters() async {
    setState(() => _loadingFilters = true);
    final res = await _service.getReportFilters();
    if (!mounted) return;

    if (res != null && res['success'] == true) {
      _outlets = (res['outlets'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _purposeOptions = (res['purpose_options'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _statusOptions = (res['status_options'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    setState(() => _loadingFilters = false);
  }

  Future<void> _pickMonth({required bool isFrom}) async {
    final current = isFrom ? _monthFrom : _monthTo;
    DateTime initial = DateTime.now();
    if (current != null && current.length >= 7) {
      final p = current.split('-');
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
      final formatted = _formatYm(picked);
      if (isFrom) {
        _monthFrom = formatted;
      } else {
        _monthTo = formatted;
      }
    });
  }

  Future<void> _fetchReport() async {
    if (_monthFrom == null || _monthTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Bulan From dan Bulan To')));
      return;
    }

    setState(() {
      _loadingReport = true;
      _showReport = false;
    });

    final res = await _service.fetchReport(
      monthFrom: _monthFrom!,
      monthTo: _monthTo!,
      outletId: _outletId,
      status: _status.isEmpty ? null : _status,
      purpose: _purpose.isEmpty ? null : _purpose,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
    );

    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loadingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message']?.toString() ?? 'Gagal memuat report')),
      );
      return;
    }

    setState(() {
      _rows = (res['rows'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _total = res['total'] as int? ?? _rows.length;
      _loadingReport = false;
      _showReport = true;
    });
  }

  Future<void> _exportExcel() async {
    if (_monthFrom == null || _monthTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Bulan From dan Bulan To')));
      return;
    }

    setState(() => _exporting = true);
    final bytes = await _service.downloadReportExport(
      monthFrom: _monthFrom!,
      monthTo: _monthTo!,
      outletId: _outletId,
      status: _status.isEmpty ? null : _status,
      purpose: _purpose.isEmpty ? null : _purpose,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _exporting = false);

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export gagal'), backgroundColor: Colors.red));
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/npd_plan_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _monthField({required String label, required String? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: NpdPlanReportUi.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
        ),
        child: Text(NpdPlanReportUi.formatMonth(value)),
      ),
    );
  }

  Widget _buildRowCard(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: NpdPlanReportUi.cardDecoration,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(row['product_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${row['report_number'] ?? '-'} · ${row['outlet'] ?? '-'}',
          style: const TextStyle(fontSize: 12, color: NpdPlanReportUi.textMuted),
        ),
        children: [
          _metaLine('No', '${row['no'] ?? '-'}'),
          _metaLine('Report Month', NpdPlanReportUi.formatMonth(row['report_month']?.toString())),
          _metaLine('Status', row['status_label']?.toString() ?? row['status']?.toString() ?? '-'),
          _metaLine('Created By', row['created_by']?.toString() ?? '-'),
          _metaLine('Category', row['category']?.toString() ?? '-'),
          _metaLine('PIC', row['pics']?.toString() ?? '-'),
          _metaLine('Dev. Date', NpdPlanReportUi.formatDate(row['development_date']?.toString())),
          _metaLine('Purpose', row['purpose_label']?.toString() ?? row['purpose']?.toString() ?? '-'),
          _metaLine('Launch Date', NpdPlanReportUi.formatDate(row['proposed_launch_date']?.toString())),
          _metaLine('Area / Outlet', row['launch_outlets']?.toString() ?? '-'),
          _metaLine('F&B Cost', NpdPlanReportUi.formatCurrency(row['fb_cost'] as num?)),
          _metaLine('Selling Price', NpdPlanReportUi.formatCurrency(row['selling_price'] as num?)),
        ],
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: NpdPlanReportUi.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'NPD Report',
      body: _loadingFilters
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: NpdPlanReportUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(16)),
                        child: const Text(
                          'Rekap produk NPD Plan & Report per periode bulan',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: NpdPlanReportUi.cardDecoration,
                        child: Column(
                          children: [
                            _monthField(label: 'Bulan From *', value: _monthFrom, onTap: () => _pickMonth(isFrom: true)),
                            const SizedBox(height: 12),
                            _monthField(label: 'Bulan To *', value: _monthTo, onTap: () => _pickMonth(isFrom: false)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _outletId,
                              decoration: const InputDecoration(labelText: 'Outlet', border: OutlineInputBorder(), filled: true),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Semua Outlet')),
                                ..._outlets.map((o) => DropdownMenuItem<int?>(
                                      value: NpdPlanReportUi.outletId(o),
                                      child: Text(NpdPlanReportUi.outletName(o)),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _outletId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), filled: true),
                              items: (_statusOptions.isNotEmpty
                                      ? _statusOptions
                                      : [
                                          {'value': '', 'label': 'Semua Status'},
                                          {'value': 'approved', 'label': 'Approved'},
                                        ])
                                  .map((o) => DropdownMenuItem<String>(
                                        value: o['value']?.toString() ?? '',
                                        child: Text(o['label']?.toString() ?? ''),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _status = v ?? ''),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _purpose,
                              decoration: const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder(), filled: true),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('Semua Purpose')),
                                ..._purposeOptions.map((o) => DropdownMenuItem<String>(
                                      value: o['value']?.toString() ?? '',
                                      child: Text(o['label']?.toString() ?? ''),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _purpose = v ?? ''),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cari',
                                hintText: 'Nomor report / produk...',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _loadingReport ? null : _fetchReport,
                                    style: FilledButton.styleFrom(backgroundColor: NpdPlanReportUi.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                                    child: _loadingReport
                                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Tampilkan'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: (_exporting || _monthFrom == null || _monthTo == null) ? null : _exportExcel,
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 14)),
                                    child: _exporting
                                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Export Excel'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_showReport && !_loadingReport)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: NpdPlanReportUi.cardDecoration,
                          child: const Center(
                            child: Text(
                              'Pilih rentang bulan lalu klik Tampilkan untuk melihat report.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: NpdPlanReportUi.textMuted),
                            ),
                          ),
                        ),
                      if (_showReport && _rows.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: NpdPlanReportUi.cardDecoration,
                          child: const Center(
                            child: Text(
                              'Tidak ada data pada filter yang dipilih.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: NpdPlanReportUi.textMuted),
                            ),
                          ),
                        ),
                      if (_showReport && _rows.isNotEmpty) ...[
                        Text('Total baris: $_total', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ..._rows.map(_buildRowCard),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
