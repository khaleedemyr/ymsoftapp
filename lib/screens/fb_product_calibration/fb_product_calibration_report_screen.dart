import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/fb_product_calibration_models.dart';
import '../../services/fb_product_calibration_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'fb_product_calibration_ui.dart';

class FbProductCalibrationReportScreen extends StatefulWidget {
  const FbProductCalibrationReportScreen({super.key});

  @override
  State<FbProductCalibrationReportScreen> createState() => _FbProductCalibrationReportScreenState();
}

class _FbProductCalibrationReportScreenState extends State<FbProductCalibrationReportScreen> {
  final _service = FbProductCalibrationService();
  final _employeeSearchController = TextEditingController();

  bool _loadingFilters = true;
  bool _loadingReport = false;
  bool _exporting = false;
  bool _showReport = false;

  List<Map<String, dynamic>> _outlets = [];
  List<CalibrationModeOption> _modeOptions = [];
  List<ParameterOption> _parameterOptions = [];
  List<Map<String, dynamic>> _rows = [];
  int _total = 0;

  String? _dateFrom;
  String? _dateTo;
  int? _outletId;
  String _mode = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    _dateFrom = _formatYmd(start);
    _dateTo = _formatYmd(now);
    _loadFilters();
  }

  @override
  void dispose() {
    _employeeSearchController.dispose();
    super.dispose();
  }

  String _formatYmd(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFilters() async {
    setState(() => _loadingFilters = true);
    final res = await _service.getReportFilters();
    if (!mounted) return;

    if (res != null && res['success'] == true) {
      _outlets = (res['outlets'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _modeOptions = (res['modeOptions'] as List? ?? [])
          .map((e) => CalibrationModeOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _parameterOptions = (res['parameter_options'] as List? ?? [])
          .map((e) => ParameterOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    setState(() => _loadingFilters = false);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _dateFrom : _dateTo;
    DateTime initial = DateTime.now();
    if (current != null && current.length >= 10) {
      final p = current.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final formatted = _formatYmd(picked);
      if (isFrom) {
        _dateFrom = formatted;
      } else {
        _dateTo = formatted;
      }
    });
  }

  Future<void> _fetchReport() async {
    if (_dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Tanggal From dan Tanggal To')),
      );
      return;
    }

    setState(() {
      _loadingReport = true;
      _showReport = false;
    });

    final res = await _service.fetchReport(
      dateFrom: _dateFrom!,
      dateTo: _dateTo!,
      outletId: _outletId,
      employeeSearch: _employeeSearchController.text.trim().isEmpty ? null : _employeeSearchController.text.trim(),
      mode: _mode.isEmpty ? null : _mode,
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
      _parameterOptions = (res['parameter_options'] as List? ?? [])
          .map((e) => ParameterOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _loadingReport = false;
      _showReport = true;
    });
  }

  Future<void> _exportExcel() async {
    if (_dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Tanggal From dan Tanggal To')),
      );
      return;
    }

    setState(() => _exporting = true);
    final bytes = await _service.downloadReportExport(
      dateFrom: _dateFrom!,
      dateTo: _dateTo!,
      outletId: _outletId,
      employeeSearch: _employeeSearchController.text.trim().isEmpty ? null : _employeeSearchController.text.trim(),
      mode: _mode.isEmpty ? null : _mode,
    );

    if (!mounted) return;
    setState(() => _exporting = false);

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export gagal'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/fb_calibration_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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

  Widget _dateField({required String label, required String? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: FbCalibrationUi.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(FbCalibrationUi.formatDate(value)),
      ),
    );
  }

  Widget _buildRowCard(Map<String, dynamic> row) {
    final params = Map<String, dynamic>.from(row['parameters'] as Map? ?? {});

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: FbCalibrationUi.cardDecoration,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(row['product_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${row['employee_name'] ?? '-'} · ${row['outlet'] ?? '-'}',
          style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted),
        ),
        children: [
          _metaLine('No', '${row['no'] ?? '-'}'),
          _metaLine('Category', row['category']?.toString() ?? '-'),
          _metaLine('Calibration Date', FbCalibrationUi.formatDate(row['calibration_date']?.toString())),
          _metaLine('Conducted By', row['conducted_by']?.toString() ?? '-'),
          if (_mode.isEmpty)
            _metaLine('Mode', row['mode_label']?.toString() ?? FbCalibrationUi.modeLabel(row['mode']?.toString())),
          const SizedBox(height: 8),
          const Text('Calibration Parameter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ..._parameterOptions.map((param) {
            final val = params[param.code]?.toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(param.label, style: const TextStyle(fontSize: 12))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: val == 'C'
                          ? const Color(0xFFD1FAE5)
                          : val == 'NC'
                              ? const Color(0xFFFEE2E2)
                              : FbCalibrationUi.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      val ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: val == 'C'
                            ? const Color(0xFF059669)
                            : val == 'NC'
                                ? const Color(0xFFDC2626)
                                : FbCalibrationUi.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
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
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Calibration Report',
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
                        decoration: FbCalibrationUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(16)),
                        child: const Text(
                          'Laporan hasil calibration product F&B (status completed)',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: FbCalibrationUi.cardDecoration,
                        child: Column(
                          children: [
                            _dateField(label: 'Tanggal From *', value: _dateFrom, onTap: () => _pickDate(isFrom: true)),
                            const SizedBox(height: 12),
                            _dateField(label: 'Tanggal To *', value: _dateTo, onTap: () => _pickDate(isFrom: false)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _outletId,
                              decoration: const InputDecoration(
                                labelText: 'Outlet',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Semua Outlet')),
                                ..._outlets.map((o) => DropdownMenuItem<int?>(
                                      value: o['id_outlet'] as int?,
                                      child: Text(o['nama_outlet']?.toString() ?? ''),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _outletId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _mode,
                              decoration: const InputDecoration(
                                labelText: 'Mode',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              items: (_modeOptions.isNotEmpty
                                      ? _modeOptions
                                      : [
                                          CalibrationModeOption(value: '', label: 'Semua Mode'),
                                          CalibrationModeOption(value: 'kitchen', label: 'Kitchen'),
                                          CalibrationModeOption(value: 'bar', label: 'Bar'),
                                        ])
                                  .map((o) => DropdownMenuItem<String>(
                                        value: o.value,
                                        child: Text(o.label),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _mode = v ?? ''),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _employeeSearchController,
                              decoration: const InputDecoration(
                                labelText: 'Employee Name',
                                hintText: 'Cari nama karyawan...',
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
                                    style: FilledButton.styleFrom(
                                      backgroundColor: FbCalibrationUi.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: _loadingReport
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Tampilkan'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: (_exporting || _dateFrom == null || _dateTo == null) ? null : _exportExcel,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: _exporting
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
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
                          decoration: FbCalibrationUi.cardDecoration,
                          child: const Center(
                            child: Text(
                              'Pilih rentang tanggal lalu klik Tampilkan untuk melihat report.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FbCalibrationUi.textMuted),
                            ),
                          ),
                        ),
                      if (_showReport && _rows.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: FbCalibrationUi.cardDecoration,
                          child: const Center(
                            child: Text(
                              'Tidak ada data calibration completed pada filter yang dipilih.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FbCalibrationUi.textMuted),
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
