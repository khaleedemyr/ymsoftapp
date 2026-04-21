import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/floor_order_vs_forecast_service.dart';
import '../../widgets/app_loading_indicator.dart';

/// RO Food Floor vs Forecast Harian — mirror web `Reports/FloorOrderVsForecast.vue`.
class FloorOrderVsForecastScreen extends StatefulWidget {
  const FloorOrderVsForecastScreen({super.key});

  @override
  State<FloorOrderVsForecastScreen> createState() => _FloorOrderVsForecastScreenState();
}

class _FloorOrderVsForecastScreenState extends State<FloorOrderVsForecastScreen> {
  final _service = FloorOrderVsForecastService();

  List<Map<String, dynamic>> _outlets = [];
  int _selectedOutletId = 0;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _canSelectOutlet = false;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _totals = {};
  bool _hasForecastHeader = false;
  String _monthLabel = '';
  double? _monthlyTarget;
  int _kbPct = 35;
  int _svcPct = 5;

  final _nf = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String get _monthYm =>
      '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadReport();
  }

  Future<void> _loadReport() async {
    final oid = _selectedOutletId > 0 ? _selectedOutletId : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await _service.fetchReport(outletId: oid, monthYm: _monthYm);
    if (!mounted) return;
    if (data == null || data['success'] != true) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat laporan.';
      });
      return;
    }

    final outletsRaw = data['outlets'];
    final outlets = (outletsRaw is List)
        ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final rowsRaw = data['rows'];
    final rows = (rowsRaw is List)
        ? rowsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final totalsRaw = data['totals'];
    final Map<String, dynamic> totals =
        totalsRaw is Map<String, dynamic> ? Map<String, dynamic>.from(totalsRaw) : {};

    final sm = data['selectedMonth']?.toString();
    if (sm != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(sm)) {
      final p = sm.split('-');
      _year = int.tryParse(p[0]) ?? _year;
      _month = int.tryParse(p[1]) ?? _month;
    }

    setState(() {
      _outlets = outlets;
      _selectedOutletId = _parseInt(data['selectedOutletId']) ?? oid;
      _canSelectOutlet = data['canSelectOutlet'] == true;
      _rows = rows;
      _totals = totals;
      _hasForecastHeader = data['has_forecast_header'] == true;
      _monthLabel = data['month_label']?.toString() ?? '';
      final mt = data['monthlyTarget'];
      if (mt is num) {
        _monthlyTarget = mt.toDouble();
      } else if (mt != null) {
        _monthlyTarget = double.tryParse('$mt');
      } else {
        _monthlyTarget = null;
      }
      _kbPct = _parseInt(data['kitchen_bar_ratio_pct']) ?? 35;
      _svcPct = _parseInt(data['service_ratio_pct']) ?? 5;
      _loading = false;
    });
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String get _outletNameText {
    for (final o in _outlets) {
      final id = _parseInt(o['id']);
      if (id != null && id == _selectedOutletId) {
        return o['name']?.toString() ?? '—';
      }
    }
    if (_outlets.length == 1) {
      return _outlets.first['name']?.toString() ?? '—';
    }
    return '—';
  }

  double _toD(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  Color _diffColor(double d) {
    if (!d.isFinite || d == 0) return const Color(0xFF475569);
    return d > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857);
  }

  Widget _styledDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return InputDecorator(
      decoration: _decoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('RO vs Forecast Harian'),
        elevation: 0,
      ),
      body: _loading && _rows.isEmpty
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAPORAN',
                          style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'RO Food Floor vs Forecast Harian',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
          Text(
          'Nilai Kitchen+Bar & Service: jika ada GR Outlet (completed), Σ qty terima × harga RO per item '
          '(seperti Invoice Outlet); jika belum ada GR, subtotal FO. '
          'Plafon $_kbPct% / $_svcPct% dari forecast harian (Revenue Targets).',
                          style: TextStyle(fontSize: 12, height: 1.35, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Outlet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        if (_canSelectOutlet)
                          _styledDropdown<int>(
                            value: _selectedOutletId > 0 ? _selectedOutletId : null,
                            items: _outlets
                                .map((o) => DropdownMenuItem<int>(
                                      value: _parseInt(o['id']),
                                      child: Text(o['name']?.toString() ?? '-'),
                                    ))
                                .where((e) => e.value != null && e.value! > 0)
                                .cast<DropdownMenuItem<int>>()
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedOutletId = v);
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _outletNameText,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _styledDropdown<int>(
                                value: _month,
                                items: List.generate(12, (i) => i + 1)
                                    .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2000, m))),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _month = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _styledDropdown<int>(
                                value: _year,
                                items: List.generate(7, (i) => DateTime.now().year - 3 + i)
                                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _year = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loading ? null : _loadReport,
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                          child: Text(_loading ? 'Memuat…' : 'Tampilkan'),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!_hasForecastHeader)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        'Belum ada data Revenue Targets (forecast harian) untuk outlet & bulan ini. '
                        'Forecast ditampilkan sebagai 0 — isi di menu Revenue Targets agar plafon $_kbPct% / $_svcPct% bermakna.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: Colors.amber.shade900),
                      ),
                    )
                  else if (_monthlyTarget != null && _monthlyTarget! > 0) ...[
                    Text(
                      '$_monthLabel · Monthly target tersimpan: ${_nf.format(_monthlyTarget)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Geser horizontal untuk melihat semua kolom.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildTable(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '* RO lain: warehouse FO selain K/B/Service. '
                    'Nilai K+B & Service: GR completed → qty terima × harga RO; lainnya subtotal FO.',
                    style: TextStyle(fontSize: 10, height: 1.4, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTable() {
    const wDate = 92.0;
    const wDay = 88.0;
    const wNum = 96.0;

    final headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade800);

    TableRow headerRow() {
      return TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade100),
        children: [
          _head('Tanggal', wDate, headerStyle),
          _head('Hari', wDay, headerStyle),
          _head('Forecast', wNum, headerStyle),
          _head('Plafon KB ($_kbPct%)', wNum, headerStyle),
          _head('RO K+B', wNum, headerStyle),
          _head('Δ KB', wNum, headerStyle),
          _head('% plafon', wNum, headerStyle),
          _head('Plafon Svc ($_svcPct%)', wNum, headerStyle),
          _head('RO Svc', wNum, headerStyle),
          _head('Δ Svc', wNum, headerStyle),
          _head('% plafon', wNum, headerStyle),
          _head('RO lain*', wNum, headerStyle),
        ],
      );
    }

    List<TableRow> body = [headerRow()];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final bg = i.isEven ? Colors.white : const Color(0xFFF8FAFC);
      final fr = _toD(r['forecast_revenue']);
      final dKb = _toD(r['diff_kitchen_bar']);
      final dSvc = _toD(r['diff_service']);
      final pctKb = r['pct_kitchen_bar_vs_cap'];
      final pctSvc = r['pct_service_vs_cap'];

      body.add(
        TableRow(
          decoration: BoxDecoration(color: bg),
          children: [
            _cellFixed(r['date']?.toString() ?? '', wDate),
            _cellFixed(r['day_name']?.toString() ?? '', wDay),
            _cellFixed(fr > 0 ? _nf.format(fr) : '—', wNum, right: true),
            _cellFixed(fr > 0 ? _nf.format(_toD(r['cap_kitchen_bar'])) : '—', wNum, right: true),
            _cellFixed(_toD(r['ro_kitchen_bar']) > 0 ? _nf.format(_toD(r['ro_kitchen_bar'])) : '—', wNum, right: true),
            _cellFixed(
              fr > 0 || _toD(r['ro_kitchen_bar']) > 0 ? '${dKb >= 0 ? '+' : ''}${_nf.format(dKb)}' : '—',
              wNum,
              right: true,
              color: fr > 0 || _toD(r['ro_kitchen_bar']) > 0 ? _diffColor(dKb) : null,
            ),
            _cellFixed(pctKb != null ? '${_toD(pctKb)}%' : '—', wNum, right: true),
            _cellFixed(fr > 0 ? _nf.format(_toD(r['cap_service'])) : '—', wNum, right: true),
            _cellFixed(_toD(r['ro_service']) > 0 ? _nf.format(_toD(r['ro_service'])) : '—', wNum, right: true),
            _cellFixed(
              fr > 0 || _toD(r['ro_service']) > 0 ? '${dSvc >= 0 ? '+' : ''}${_nf.format(dSvc)}' : '—',
              wNum,
              right: true,
              color: fr > 0 || _toD(r['ro_service']) > 0 ? _diffColor(dSvc) : null,
            ),
            _cellFixed(pctSvc != null ? '${_toD(pctSvc)}%' : '—', wNum, right: true),
            _cellFixed(_toD(r['ro_other']) > 0 ? _nf.format(_toD(r['ro_other'])) : '—', wNum, right: true),
          ],
        ),
      );
    }

    final t = _totals;
    body.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: [
          _cellFixed('Total bulan', wDate, weight: FontWeight.w700),
          _cellFixed('', wDay),
          _cellFixed(_nf.format(_toD(t['forecast_revenue'])), wNum, right: true, weight: FontWeight.w700),
          _cellFixed(_nf.format(_toD(t['cap_kitchen_bar'])), wNum, right: true, weight: FontWeight.w700),
          _cellFixed(_nf.format(_toD(t['ro_kitchen_bar'])), wNum, right: true, weight: FontWeight.w700),
          _cellFixed(
            '${_toD(t['diff_kitchen_bar']) >= 0 ? '+' : ''}${_nf.format(_toD(t['diff_kitchen_bar']))}',
            wNum,
            right: true,
            color: _diffColor(_toD(t['diff_kitchen_bar'])),
            weight: FontWeight.w700,
          ),
          _cellFixed('—', wNum, right: true, weight: FontWeight.w700),
          _cellFixed(_nf.format(_toD(t['cap_service'])), wNum, right: true, weight: FontWeight.w700),
          _cellFixed(_nf.format(_toD(t['ro_service'])), wNum, right: true, weight: FontWeight.w700),
          _cellFixed(
            '${_toD(t['diff_service']) >= 0 ? '+' : ''}${_nf.format(_toD(t['diff_service']))}',
            wNum,
            right: true,
            color: _diffColor(_toD(t['diff_service'])),
            weight: FontWeight.w700,
          ),
          _cellFixed('—', wNum, right: true, weight: FontWeight.w700),
          _cellFixed(_toD(t['ro_other']) > 0 ? _nf.format(_toD(t['ro_other'])) : '—', wNum, right: true, weight: FontWeight.w700),
        ],
      ),
    );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
      children: body,
    );
  }

  Widget _head(String label, double w, TextStyle style) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(label, style: style, maxLines: 3),
      ),
    );
  }

  Widget _cellFixed(String text, double colW, {bool right = false, Color? color, FontWeight? weight}) {
    return SizedBox(
      width: colW,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: color ?? const Color(0xFF0F172A), fontWeight: weight),
          ),
        ),
      ),
    );
  }
}
