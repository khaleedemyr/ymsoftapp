import 'package:flutter/material.dart';

import '../../services/qa2_audit_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'qa2_audit_ui.dart';

class Qa2AuditSummaryScreen extends StatefulWidget {
  const Qa2AuditSummaryScreen({super.key});

  @override
  State<Qa2AuditSummaryScreen> createState() => _Qa2AuditSummaryScreenState();
}

class _Qa2AuditSummaryScreenState extends State<Qa2AuditSummaryScreen> {
  final _service = Qa2AuditService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _outlets = [];
  int? _outletId;
  late String _fromMonth;
  late String _toMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _toMonth = _fromMonth;
    _load();
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.fetchReportSummary(
      outletId: _outletId,
      fromMonth: _fromMonth,
      toMonth: _toMonth,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat report summary.';
      });
      return;
    }
    setState(() {
      _rows = (res['rows'] is List)
          ? (res['rows'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      _outlets = (res['outlets'] is List)
          ? (res['outlets'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      final f = res['filters'];
      if (f is Map) {
        _fromMonth = (f['from_month']?.toString().isNotEmpty ?? false) ? f['from_month'].toString() : _fromMonth;
        _toMonth = (f['to_month']?.toString().isNotEmpty ?? false) ? f['to_month'].toString() : _toMonth;
        _outletId = _parseInt(f['outlet_id']);
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'QA2 Report Summary',
      showDrawer: false,
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator(size: 36, color: Qa2AuditUi.primary))
                : _error != null
                    ? Center(child: Text(_error!))
                    : _rows.isEmpty
                        ? const Center(child: Text('Belum ada data summary.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final row = _rows[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row['outlet_name']?.toString() ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Jumlah Audit: ${row['audit_count'] ?? 0}'),
                                    const SizedBox(height: 4),
                                    Text('Rata-rata Audit Result: ${row['avg_audit_result'] ?? '0.00'}%'),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _monthInput(
                  label: 'From',
                  value: _fromMonth,
                  onChanged: (v) => setState(() => _fromMonth = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _monthInput(
                  label: 'To',
                  value: _toMonth,
                  onChanged: (v) => setState(() => _toMonth = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            value: _outletId,
            decoration: const InputDecoration(
              labelText: 'Outlet',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Semua Outlet')),
              ..._outlets.expand((o) sync* {
                final id = _parseInt(o['id_outlet']);
                if (id == null) return;
                yield DropdownMenuItem<int?>(
                  value: id,
                  child: Text(o['nama_outlet']?.toString() ?? '-'),
                );
              }),
            ],
            onChanged: (v) => setState(() => _outletId = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Terapkan Filter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final ctrl = TextEditingController(text: value);
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: const Icon(Icons.calendar_month_rounded, size: 18),
      ),
      onTap: () async {
        final now = DateTime.now();
        final parts = value.split('-');
        int y = now.year;
        int m = now.month;
        if (parts.length == 2) {
          y = int.tryParse(parts[0]) ?? y;
          m = int.tryParse(parts[1]) ?? m;
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(y, m, 1),
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime(now.year + 2, 12, 31),
          helpText: 'Pilih bulan',
        );
        if (picked != null) {
          onChanged('${picked.year}-${picked.month.toString().padLeft(2, '0')}');
        }
      },
    );
  }
}

