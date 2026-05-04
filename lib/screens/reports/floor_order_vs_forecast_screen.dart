import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/floor_order_vs_forecast_service.dart';
import '../../widgets/app_loading_indicator.dart';

/// RO Food Floor vs Forecast Harian — align UI with web `Reports/FloorOrderVsForecast.vue`.
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
  int _kbPct = 40;
  int _svcPct = 5;
  List<Map<String, dynamic>> _categoryCostTypes = [];
  String? _selectedRowDate;

  static const double _wDate = 92;
  static const double _wDay = 82;
  static const double _wNum = 100;
  static const double _headerH = 72;
  static const double _g1 = 34;

  /// Match Vue `formatRp` (0–2 fraction digits).
  final NumberFormat _formatRp = NumberFormat('#,##0.##', 'id_ID');
  final NumberFormat _numPlain = NumberFormat('#,##0.##', 'id_ID');

  String get _monthYm =>
      '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}';

  int get _effectiveOutletId {
    if (_selectedOutletId > 0) return _selectedOutletId;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadReport();
  }

  Future<void> _loadReport() async {
    final oid = _effectiveOutletId;
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
      _kbPct = _parseInt(data['kitchen_bar_ratio_pct']) ?? 40;
      _svcPct = _parseInt(data['service_ratio_pct']) ?? 5;
      final catRaw = data['category_cost_types'];
      _categoryCostTypes = (catRaw is List)
          ? catRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      _loading = false;
      final sel = _selectedRowDate;
      if (sel != null && !rows.any((r) => '${r['date'] ?? ''}' == sel)) {
        _selectedRowDate = null;
      }
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month, 1),
      firstDate: DateTime(now.year - 4, 1),
      lastDate: DateTime(now.year + 1, 12),
      helpText: 'Pilih bulan',
    );
    if (d != null) {
      setState(() {
        _year = d.year;
        _month = d.month;
      });
    }
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

  String get _monthButtonLabel =>
      DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_year, _month, 1));

  double _toD(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String _rp(dynamic n) {
    final v = _toD(n);
    return 'Rp ${_formatRp.format(v)}';
  }

  double _categoryCostFromRow(Map<String, dynamic> row, String typeKey) {
    final raw = row['category_cost_values'];
    if (raw is! Map) return 0;
    return _toD(raw[typeKey]);
  }

  double _categoryCostFromTotals(String typeKey) {
    final raw = _totals['category_cost_values'];
    if (raw is! Map) return 0;
    return _toD(raw[typeKey]);
  }

  String _fmtPctVsCap(dynamic v) {
    if (v == null) return '—';
    return '${_numPlain.format(_toD(v))}%';
  }

  String _fmtCostRatioPct(dynamic v) {
    if (v == null) return '—';
    return '${_numPlain.format(_toD(v))}%';
  }

  Color _diffColor(double d) {
    if (!d.isFinite || d == 0) return const Color(0xFF475569);
    return d > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857);
  }

  InputDecoration _decoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFFFFFFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF172554)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAPORAN',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC7D2FE).withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'RO Food Floor vs Forecast Harian',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterCard(context),
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
                  const SizedBox(height: 16),
                  _buildTablePanel(context),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 560;
          final outletBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Outlet',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              if (_canSelectOutlet)
                InputDecorator(
                  decoration: _decoration(),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
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
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _outletNameText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
            ],
          );
          final monthBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bulan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Material(
                color: Colors.white,
                child: InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _decoration(),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _monthButtonLabel,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Icon(Icons.calendar_month, size: 20, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
          final tampilkanButton = FilledButton(
            onPressed: _loading ? null : _loadReport,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Tampilkan'),
          );

          if (wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 2, child: outletBlock),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: monthBlock),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: tampilkanButton),
                  ],
                ),
                if (!_hasForecastHeader) ...[
                  const SizedBox(height: 14),
                  _forecastWarning(),
                ] else if (_monthlyTarget != null) ...[
                  const SizedBox(height: 14),
                  _monthlyTargetLine(),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              outletBlock,
              const SizedBox(height: 12),
              monthBlock,
              const SizedBox(height: 12),
              tampilkanButton,
              if (!_hasForecastHeader) ...[
                const SizedBox(height: 14),
                _forecastWarning(),
              ] else if (_monthlyTarget != null) ...[
                const SizedBox(height: 14),
                _monthlyTargetLine(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _forecastWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF78350F)),
          children: [
            const TextSpan(text: 'Belum ada data '),
            const TextSpan(text: 'Revenue Targets', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(
              text:
                  ' (forecast harian) untuk outlet & bulan ini. Forecast ditampilkan sebagai 0 — isi di menu Revenue Targets agar plafon $_kbPct% / $_svcPct% bermakna.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthlyTargetLine() {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        children: [
          TextSpan(text: _monthLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const TextSpan(text: ' · Monthly target tersimpan: '),
          TextSpan(text: _rp(_monthlyTarget!), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildTablePanel(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: h,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _buildFullTable(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullTable() {
    final cats = _categoryCostTypes;
    final rows = <Widget>[
      _headerCombined(cats),
      ...List.generate(_rows.length, (i) {
        final r = _rows[i];
        final dateKey = '${r['date'] ?? ''}';
        final selected = _selectedRowDate == dateKey;
        final stripe = i.isEven ? Colors.white : const Color(0xFFF8FAFC);
        final bg = selected ? const Color(0xFFC7D2FE).withValues(alpha: 0.75) : stripe;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _selectedRowDate = selected ? null : dateKey;
            });
          },
          child: Container(
            color: bg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _bodyCells(r, bg),
            ),
          ),
        );
      }),
      _footerRow(cats),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  /// Web table: rowspan 2 on Tanggal / Hari / Forecast; group titles on row 1; subcolumns on row 2.
  Widget _headerCombined(List<Map<String, dynamic>> cats) {
    const edge = Color(0xFF94A3B8);
    const subH = _headerH - _g1;

    Widget leftR(String label, double w, {bool thickRightAfter = false}) {
      return Container(
        width: w,
        height: _headerH,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          border: Border(
            right: BorderSide(color: edge, width: thickRightAfter ? 2 : 1),
            bottom: const BorderSide(color: Color(0xFF94A3B8), width: 1.2),
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade800, height: 1.15),
        ),
      );
    }

    Widget spanTop(String title, double w, Color bg, {bool thickRight = false}) {
      return Container(
        width: w,
        height: _g1,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(color: edge, width: thickRight ? 2 : 1),
            bottom: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade800, height: 1.1),
        ),
      );
    }

    TextStyle stSub(Color c) => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c, height: 1.1);

    Widget sub(String label, double w, Color bg, {bool thickRight = false, Color text = const Color(0xFF1E293B)}) {
      return Container(
        width: w,
        height: subH,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(color: edge, width: thickRight ? 2 : 1),
            bottom: const BorderSide(color: Color(0xFF94A3B8), width: 1.2),
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(label, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: stSub(text)),
      );
    }

    final catW = cats.isEmpty ? 0.0 : cats.length * _wNum;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leftR('Tanggal', _wDate),
        leftR('Hari', _wDay),
        leftR('Forecast', _wNum, thickRightAfter: true),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                spanTop('F & B Purchase', 4 * _wNum, const Color(0xFFEEF2FF), thickRight: true),
                spanTop('Service Purchase', 4 * _wNum, const Color(0xFFCCFBF1), thickRight: true),
                spanTop('Revenue', 4 * _wNum, const Color(0xFFD1FAE5), thickRight: true),
                spanTop('Begin Stock', 3 * _wNum, const Color(0xFFE0F2FE), thickRight: true),
                spanTop('Cost', 4 * _wNum, const Color(0xFFF5D0FE).withValues(alpha: 0.55), thickRight: true),
                if (cats.isNotEmpty) spanTop('Category Cost', catW, const Color(0xFFA5F3FC), thickRight: true),
                spanTop('% Cost', 2 * _wNum, const Color(0xFFD9F99D), thickRight: true),
                spanTop('Outlet Transfer', 2 * _wNum, const Color(0xFFFED7AA), thickRight: true),
                spanTop('Stock Adjustment', 2 * _wNum, const Color(0xFFE9D5FF), thickRight: true),
                spanTop('Stock on Hand', 3 * _wNum, const Color(0xFFFDE68A), thickRight: false),
              ],
            ),
            Row(
              children: [
                sub('Budget ($_kbPct%)', _wNum, const Color(0xFFEEF2FF), text: const Color(0xFF312E81)),
                sub('Purchased', _wNum, const Color(0xFFEEF2FF), text: const Color(0xFF312E81)),
                sub('Variance', _wNum, const Color(0xFFEEF2FF), text: const Color(0xFF312E81)),
                sub('%', _wNum, const Color(0xFFEEF2FF), thickRight: true, text: const Color(0xFF312E81)),
                sub('Budget ($_svcPct%)', _wNum, const Color(0xFFCCFBF1), text: const Color(0xFF134E4A)),
                sub('Purchased', _wNum, const Color(0xFFCCFBF1), text: const Color(0xFF134E4A)),
                sub('Variance', _wNum, const Color(0xFFCCFBF1), text: const Color(0xFF134E4A)),
                sub('%', _wNum, const Color(0xFFCCFBF1), thickRight: true, text: const Color(0xFF134E4A)),
                sub('Revenue', _wNum, const Color(0xFFD1FAE5), text: const Color(0xFF064E3B)),
                sub('Engineering', _wNum, const Color(0xFFD1FAE5), text: const Color(0xFF064E3B)),
                sub('Discount', _wNum, const Color(0xFFFECACA), text: const Color(0xFF7F1D1D)),
                sub('% Disc', _wNum, const Color(0xFFFFE4E6), thickRight: true, text: const Color(0xFF881337)),
                sub('F & B', _wNum, const Color(0xFFE0F2FE), text: const Color(0xFF0C4A6E)),
                sub('Service', _wNum, const Color(0xFFE0F2FE), text: const Color(0xFF0C4A6E)),
                sub('Total', _wNum, const Color(0xFFE0F2FE), thickRight: true, text: const Color(0xFF0C4A6E)),
                sub('Menu', _wNum, const Color(0xFFECFEFF), text: const Color(0xFF155E75)),
                sub('Modifier', _wNum, const Color(0xFFFAF5FF), text: const Color(0xFF581C87)),
                sub('Usage', _wNum, const Color(0xFFF5F3FF), text: const Color(0xFF5B21B6)),
                sub('Total', _wNum, const Color(0xFFFFF1F2), thickRight: true, text: const Color(0xFF881337)),
                ...cats.asMap().entries.map((e) {
                  final last = e.key == cats.length - 1;
                  return sub(
                    e.value['label']?.toString() ?? '',
                    _wNum,
                    const Color(0xFFECFEFF),
                    thickRight: last,
                    text: const Color(0xFF155E75),
                  );
                }),
                sub('Cost % Revenue', _wNum, const Color(0xFFD9F99D), text: const Color(0xFF365314)),
                sub('Cost % Eng.', _wNum, const Color(0xFFD9F99D), thickRight: true, text: const Color(0xFF365314)),
                sub('Transfer Out', _wNum, const Color(0xFFFFEDD5), text: const Color(0xFF9A3412)),
                sub('Transfer In', _wNum, const Color(0xFFFFEDD5), thickRight: true, text: const Color(0xFF9A3412)),
                sub('Adj In', _wNum, const Color(0xFFF3E8FF), text: const Color(0xFF581C87)),
                sub('Adj Out', _wNum, const Color(0xFFF3E8FF), thickRight: true, text: const Color(0xFF581C87)),
                sub('F & B', _wNum, const Color(0xFFFEF3C7), text: const Color(0xFF78350F)),
                sub('Service', _wNum, const Color(0xFFFFEDD5), text: const Color(0xFF9A3412)),
                sub('Total', _wNum, const Color(0xFFFEF9C3), thickRight: false, text: const Color(0xFF713F12)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _bodyCells(Map<String, dynamic> r, Color rowBg) {
    const fbC = Color(0xFFEEF2FF);
    const svcC = Color(0xFFF0FDFA);
    const revC = Color(0xFFECFDF5);
    const engC = Color(0xFFECFDF5);
    const discC = Color(0xFFFECACA);
    const pctDiscC = Color(0xFFFFE4E6);
    const beginC = Color(0xFFF0F9FF);
    const costMenuC = Color(0xFFECFEFF);
    const costModC = Color(0xFFFAF5FF);
    const costUsageC = Color(0xFFF5F3FF);
    const costTotC = Color(0xFFFFF1F2);
    const catC = Color(0xFFECFEFF);
    const limeC = Color(0xFFF7FEE7);
    const xferC = Color(0xFFFFF7ED);
    const adjC = Color(0xFFF5F3FF);
    const sohKbC = Color(0xFFFFFBEB);
    const sohSvcC = Color(0xFFFFF7ED);
    const sohTotC = Color(0xFFFEFCE8);

    final fr = _toD(r['forecast_revenue']);
    final roKb = _toD(r['ro_kitchen_bar']);
    final roSv = _toD(r['ro_service']);
    final dKb = _toD(r['diff_kitchen_bar']);
    final dSvc = _toD(r['diff_service']);

    String moneyPositive(double v) => v > 0 ? _rp(v) : '—';

    return [
      _cellFixed(r['date']?.toString() ?? '', _wDate, bgColor: rowBg),
      _cellFixed(_capitalize(r['day_name']?.toString() ?? ''), _wDay, bgColor: rowBg, color: const Color(0xFF475569)),
      _cellFixed(fr > 0 ? _rp(fr) : '—', _wNum, right: true, bgColor: rowBg, thickRight: true),
      _cellFixed(fr > 0 ? _rp(_toD(r['cap_kitchen_bar'])) : '—', _wNum, right: true, bgColor: fbC),
      _cellFixed(roKb > 0 ? _rp(roKb) : '—', _wNum, right: true, bgColor: fbC, weight: FontWeight.w600),
      _cellFixed(
        fr > 0 || roKb > 0 ? '${dKb >= 0 ? '+' : ''}${_rp(dKb)}' : '—',
        _wNum,
        right: true,
        bgColor: fbC,
        color: fr > 0 || roKb > 0 ? _diffColor(dKb) : null,
      ),
      _cellFixed(_fmtPctVsCap(r['pct_kitchen_bar_vs_cap']), _wNum, right: true, bgColor: fbC, thickRight: true),
      _cellFixed(fr > 0 ? _rp(_toD(r['cap_service'])) : '—', _wNum, right: true, bgColor: svcC),
      _cellFixed(roSv > 0 ? _rp(roSv) : '—', _wNum, right: true, bgColor: svcC, weight: FontWeight.w600),
      _cellFixed(
        fr > 0 || roSv > 0 ? '${dSvc >= 0 ? '+' : ''}${_rp(dSvc)}' : '—',
        _wNum,
        right: true,
        bgColor: svcC,
        color: fr > 0 || roSv > 0 ? _diffColor(dSvc) : null,
      ),
      _cellFixed(_fmtPctVsCap(r['pct_service_vs_cap']), _wNum, right: true, bgColor: svcC, thickRight: true),
      _cellFixed(moneyPositive(_toD(r['revenue'])), _wNum, right: true, bgColor: revC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['revenue_before_discount'])), _wNum, right: true, bgColor: engC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['discount'])), _wNum, right: true, bgColor: discC, weight: FontWeight.w600),
      _cellFixed(
        r['pct_discount'] != null ? '${_numPlain.format(_toD(r['pct_discount']))}%' : '—',
        _wNum,
        right: true,
        bgColor: pctDiscC,
        weight: FontWeight.w600,
        thickRight: true,
      ),
      _cellFixed(moneyPositive(_toD(r['begin_stock_kitchen_bar'])), _wNum, right: true, bgColor: beginC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['begin_stock_service'])), _wNum, right: true, bgColor: beginC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['begin_stock_total'])), _wNum, right: true, bgColor: beginC, weight: FontWeight.w600, thickRight: true),
      _cellFixed(moneyPositive(_toD(r['cost_menu'])), _wNum, right: true, bgColor: costMenuC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['cost_modifier'])), _wNum, right: true, bgColor: costModC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['category_cost_usage'])), _wNum, right: true, bgColor: costUsageC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['cost_total'])), _wNum, right: true, bgColor: costTotC, weight: FontWeight.w600, thickRight: true),
      ..._categoryCostTypes.asMap().entries.map((e) {
        final key = e.value['key']?.toString() ?? '';
        final v = _categoryCostFromRow(r, key);
        final last = e.key == _categoryCostTypes.length - 1;
        return _cellFixed(
          v > 0 ? _rp(v) : '—',
          _wNum,
          right: true,
          bgColor: catC,
          weight: FontWeight.w600,
          thickRight: last,
        );
      }),
      _cellFixed(_fmtCostRatioPct(r['cost_x_revenue']), _wNum, right: true, bgColor: limeC, weight: FontWeight.w600),
      _cellFixed(_fmtCostRatioPct(r['cost_x_engineering']), _wNum, right: true, bgColor: limeC, weight: FontWeight.w600, thickRight: true),
      _cellFixed(moneyPositive(_toD(r['transfer_out'])), _wNum, right: true, bgColor: xferC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['transfer_in'])), _wNum, right: true, bgColor: xferC, weight: FontWeight.w600, thickRight: true),
      _cellFixed(moneyPositive(_toD(r['adj_in'])), _wNum, right: true, bgColor: adjC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['adj_out'])), _wNum, right: true, bgColor: adjC, weight: FontWeight.w600, thickRight: true),
      _cellFixed(moneyPositive(_toD(r['stock_on_hand_kitchen_bar'])), _wNum, right: true, bgColor: sohKbC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['stock_on_hand_service'])), _wNum, right: true, bgColor: sohSvcC, weight: FontWeight.w600),
      _cellFixed(moneyPositive(_toD(r['stock_on_hand_total'])), _wNum, right: true, bgColor: sohTotC, weight: FontWeight.w600),
    ];
  }

  Widget _footerRow(List<Map<String, dynamic>> cats) {
    final t = _totals;
    const fbH = Color(0xFFE0E7FF);
    const svcH = Color(0xFFCCFBF1);
    const revH = Color(0xFFD1FAE5);
    const beginH = Color(0xFFE0F2FE);
    const costMenuH = Color(0xFFCCFBF1);
    const costModH = Color(0xFFF5D0FE);
    const costUsageH = Color(0xFFE9D5FF);
    const costTotH = Color(0xFFFBCFE8);
    const catH = Color(0xFFA5F3FC);
    const limeH = Color(0xFFD9F99D);
    const xferH = Color(0xFFFED7AA);
    const adjH = Color(0xFFE9D5FF);
    const sohKbH = Color(0xFFFDE68A);
    const sohSvcH = Color(0xFFFDBA74);
    const sohTotH = Color(0xFFFACC15);

    Widget rpCell(String key, {Color? bg, FontWeight fw = FontWeight.w700, bool thickRight = false}) =>
        _cellFixed(_rp(t[key]), _wNum, right: true, weight: fw, bgColor: bg, thickRight: thickRight);

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cellFixed(
            'Total bulan (SOH: posisi akhir bulan)',
            _wDate + _wDay,
            weight: FontWeight.w700,
            bgColor: const Color(0xFFF1F5F9),
          ),
          rpCell('forecast_revenue', thickRight: true),
          rpCell('cap_kitchen_bar', bg: fbH),
          rpCell('ro_kitchen_bar', bg: fbH),
          _cellFixed(
            '${_toD(t['diff_kitchen_bar']) >= 0 ? '+' : ''}${_rp(t['diff_kitchen_bar'])}',
            _wNum,
            right: true,
            bgColor: fbH,
            color: _diffColor(_toD(t['diff_kitchen_bar'])),
            weight: FontWeight.w700,
          ),
          _cellFixed('—', _wNum, right: true, weight: FontWeight.w700, bgColor: fbH, thickRight: true),
          rpCell('cap_service', bg: svcH),
          rpCell('ro_service', bg: svcH),
          _cellFixed(
            '${_toD(t['diff_service']) >= 0 ? '+' : ''}${_rp(t['diff_service'])}',
            _wNum,
            right: true,
            bgColor: svcH,
            color: _diffColor(_toD(t['diff_service'])),
            weight: FontWeight.w700,
          ),
          _cellFixed('—', _wNum, right: true, weight: FontWeight.w700, bgColor: svcH, thickRight: true),
          rpCell('revenue', bg: revH),
          rpCell('revenue_before_discount', bg: revH),
          rpCell('discount', bg: revH),
          _cellFixed(
            t['pct_discount'] != null ? '${_numPlain.format(_toD(t['pct_discount']))}%' : '—',
            _wNum,
            right: true,
            weight: FontWeight.w700,
            bgColor: revH,
            thickRight: true,
          ),
          rpCell('begin_stock_kitchen_bar_start', bg: beginH),
          rpCell('begin_stock_service_start', bg: beginH),
          rpCell('begin_stock_total_start', bg: beginH, thickRight: true),
          rpCell('cost_menu', bg: costMenuH),
          rpCell('cost_modifier', bg: costModH),
          rpCell('category_cost_usage', bg: costUsageH),
          rpCell('cost_total', bg: costTotH, thickRight: true),
          ...cats.asMap().entries.map((e) {
            final key = e.value['key']?.toString() ?? '';
            final v = _categoryCostFromTotals(key);
            final last = e.key == cats.length - 1;
            return _cellFixed(_rp(v), _wNum, right: true, weight: FontWeight.w700, bgColor: catH, thickRight: last);
          }),
          _cellFixed(_fmtCostRatioPct(t['cost_x_revenue']), _wNum, right: true, weight: FontWeight.w700, bgColor: limeH),
          _cellFixed(
            _fmtCostRatioPct(t['cost_x_engineering']),
            _wNum,
            right: true,
            weight: FontWeight.w700,
            bgColor: limeH,
            thickRight: true,
          ),
          rpCell('transfer_out', bg: xferH),
          rpCell('transfer_in', bg: xferH, thickRight: true),
          rpCell('adj_in', bg: adjH),
          rpCell('adj_out', bg: adjH, thickRight: true),
          rpCell('stock_on_hand_kitchen_bar_end', bg: sohKbH),
          rpCell('stock_on_hand_service_end', bg: sohSvcH),
          rpCell('stock_on_hand_total_end', bg: sohTotH),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _cellFixed(
    String text,
    double colW, {
    bool right = false,
    Color? color,
    FontWeight? weight,
    Color? bgColor,
    bool thickRight = false,
  }) {
    const edge = Color(0xFFCBD5E1);
    return Container(
      width: colW,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: edge, width: thickRight ? 2 : 1),
          bottom: BorderSide(color: edge.withValues(alpha: 0.85)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color ?? const Color(0xFF0F172A),
          fontWeight: weight,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
