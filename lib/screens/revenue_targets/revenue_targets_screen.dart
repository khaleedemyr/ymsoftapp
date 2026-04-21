import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/outlet_revenue_target_service.dart';
import '../../widgets/app_loading_indicator.dart';

/// Monthly Target & Daily Forecast — menyamai web `RevenueTargets/Index.vue`.
class RevenueTargetsScreen extends StatefulWidget {
  const RevenueTargetsScreen({super.key});

  @override
  State<RevenueTargetsScreen> createState() => _RevenueTargetsScreenState();
}

class _ForecastLine {
  _ForecastLine({
    required this.isoDate,
    required this.weekdayLabel,
    required this.isWeekend,
    required this.isHoliday,
    required this.holidayDesc,
    required this.controller,
  });

  final String isoDate;
  final String weekdayLabel;
  final bool isWeekend;
  final bool isHoliday;
  final String holidayDesc;
  final TextEditingController controller;
}

class _RevenueTargetsScreenState extends State<RevenueTargetsScreen> {
  final _service = OutletRevenueTargetService();
  final _monthlyTargetCtrl = TextEditingController();
  final _bulkValueCtrl = TextEditingController();
  final _bulkPercentCtrl = TextEditingController();

  DateTime? _bulkStartDate;
  DateTime? _bulkEndDate;
  bool _bulkSetMode = true;

  List<Map<String, dynamic>> _outlets = [];
  int _selectedOutletId = 0;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _canSelectOutlet = false;

  bool _loading = false;
  bool _saving = false;
  bool _suggesting = false;
  String? _errorBanner;

  List<Map<String, dynamic>> _holidays = [];
  List<_ForecastLine> _forecastLines = [];

  int _historyMonthsBack = 1;
  bool _historyLoading = false;
  String _historyMessage = '';
  List<Map<String, dynamic>> _historyCards = [];

  static final _displayFmt = NumberFormat('#,##0.##', 'id_ID');

  String get _monthYm =>
      '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _holidays = await _service.fetchCompanyHolidays();
    await _loadIndex();
  }

  @override
  void dispose() {
    _monthlyTargetCtrl.dispose();
    _bulkValueCtrl.dispose();
    _bulkPercentCtrl.dispose();
    _disposeForecastLines();
    super.dispose();
  }

  void _disposeForecastLines() {
    for (final l in _forecastLines) {
      l.controller.dispose();
    }
    _forecastLines = [];
  }

  double? _parseMoney(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.trim().toLowerCase().replaceAll(RegExp(r'\s'), '');
    double mult = 1;
    if (RegExp(r'(k|rb)$').hasMatch(s)) {
      mult = 1000;
      s = s.replaceAll(RegExp(r'(k|rb)$'), '');
    } else if (RegExp(r'(jt|juta)$').hasMatch(s)) {
      mult = 1e6;
      s = s.replaceAll(RegExp(r'(jt|juta)$'), '');
    }
    s = s.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (s.contains('.') && s.contains(',')) {
      s = s.replaceAll('.', '').replaceFirst(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceFirst(',', '.');
    } else if (s.contains('.')) {
      final isGrouped = RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s);
      if (isGrouped) s = s.replaceAll('.', '');
    }
    final n = double.tryParse(s);
    if (n == null) return null;
    return n * mult;
  }

  String _formatMoneyDisplay(double? v) {
    if (v == null || !v.isFinite) return '';
    return _displayFmt.format(v);
  }

  void _rebuildForecastLinesFromMaps(List<Map<String, dynamic>> existing) {
    _disposeForecastLines();
    final map = <String, double>{};
    for (final row in existing) {
      final d = row['forecast_date']?.toString() ?? '';
      final key = d.length >= 10 ? d.substring(0, 10) : d;
      final rev = row['forecast_revenue'];
      final n = rev is num ? rev.toDouble() : double.tryParse('$rev') ?? 0;
      map[key] = n;
    }

    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(_year, _month, day);
      final iso =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final weekend = dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
      Map<String, dynamic>? hol;
      for (final h in _holidays) {
        final t = h['tgl_libur']?.toString() ?? '';
        if (t.length >= 10 && t.substring(0, 10) == iso) {
          hol = h;
          break;
        }
      }
      final initial = map[iso];
      final ctrl = TextEditingController(
        text: initial != null && initial > 0 ? _formatMoneyDisplay(initial) : '',
      );
      _forecastLines.add(_ForecastLine(
        isoDate: iso,
        weekdayLabel: DateFormat('EEEE', 'id_ID').format(dt),
        isWeekend: weekend,
        isHoliday: hol != null,
        holidayDesc: hol?['keterangan']?.toString() ?? '',
        controller: ctrl,
      ));
    }
    _syncBulkDatesFromForecastLines();
  }

  void _syncBulkDatesFromForecastLines() {
    if (_forecastLines.isEmpty) {
      _bulkStartDate = null;
      _bulkEndDate = null;
      return;
    }
    _bulkStartDate = DateTime.tryParse(_forecastLines.first.isoDate);
    _bulkEndDate = DateTime.tryParse(_forecastLines.last.isoDate);
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBulkDate({required bool isStart}) async {
    final initial = isStart ? (_bulkStartDate ?? DateTime.now()) : (_bulkEndDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_year, _month, 1),
      lastDate: DateTime(_year, _month + 1, 0),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _bulkStartDate = picked;
        } else {
          _bulkEndDate = picked;
        }
      });
    }
  }

  void _applyBulkUpdate() {
    if (_bulkStartDate == null || _bulkEndDate == null) {
      setState(() => _errorBanner = 'Isi tanggal awal dan akhir untuk bulk update.');
      return;
    }
    final sa = _isoDate(_bulkStartDate!);
    final sb = _isoDate(_bulkEndDate!);
    final start = sa.compareTo(sb) <= 0 ? sa : sb;
    final end = sa.compareTo(sb) <= 0 ? sb : sa;

    if (_bulkSetMode) {
      final base = _parseMoney(_bulkValueCtrl.text);
      if (base == null || base < 0) {
        setState(() => _errorBanner = 'Isi nominal bulk update yang valid.');
        return;
      }
      final formatted = _formatMoneyDisplay(base);
      setState(() {
        _errorBanner = null;
        for (final l in _forecastLines) {
          if (l.isoDate.compareTo(start) >= 0 && l.isoDate.compareTo(end) <= 0) {
            l.controller.text = formatted;
          }
        }
      });
      return;
    }

    final pct = double.tryParse(_bulkPercentCtrl.text.trim().replaceAll(',', '.'));
    if (pct == null || !pct.isFinite) {
      setState(() => _errorBanner = 'Isi persentase bulk update yang valid.');
      return;
    }
    setState(() {
      _errorBanner = null;
      for (final l in _forecastLines) {
        if (l.isoDate.compareTo(start) < 0 || l.isoDate.compareTo(end) > 0) continue;
        final current = _parseMoney(l.controller.text) ?? 0;
        final updated = current * (1 + pct / 100);
        l.controller.text = updated > 0 ? _formatMoneyDisplay(updated) : '';
      }
    });
  }

  Future<void> _loadIndex() async {
    setState(() {
      _loading = true;
      _errorBanner = null;
    });
    final data = await _service.fetchIndex(
      outletId: _selectedOutletId > 0 ? _selectedOutletId : 1,
      monthYm: _monthYm,
    );
    if (!mounted) return;
    if (data == null || data['success'] != true) {
      setState(() {
        _loading = false;
        _errorBanner = 'Gagal memuat data revenue targets.';
      });
      return;
    }

    final outlets = (data['outlets'] as List?) ?? [];
    _outlets = outlets.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _selectedOutletId = _parseInt(data['selectedOutletId']) ?? 1;
    _canSelectOutlet = data['canSelectOutlet'] == true;

    final sm = data['selectedMonth']?.toString();
    if (sm != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(sm)) {
      final p = sm.split('-');
      _year = int.tryParse(p[0]) ?? _year;
      _month = int.tryParse(p[1]) ?? _month;
    }

    final mt = data['monthlyTarget'];
    double? mtv;
    if (mt is num) {
      mtv = mt.toDouble();
    } else if (mt != null) {
      mtv = double.tryParse('$mt');
    }
    _monthlyTargetCtrl.text = mtv != null && mtv > 0 ? _formatMoneyDisplay(mtv) : '';

    final existing = (data['existingForecasts'] as List?) ?? [];
    final existingMaps = existing.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    _rebuildForecastLinesFromMaps(existingMaps);

    setState(() => _loading = false);
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

  double _totalForecastInput() {
    double sum = 0;
    for (final l in _forecastLines) {
      final v = _parseMoney(l.controller.text);
      if (v != null) sum += v;
    }
    return sum;
  }

  Future<void> _save() async {
    final outletId = _selectedOutletId;
    if (outletId <= 0) return;
    final mt = _parseMoney(_monthlyTargetCtrl.text) ?? 0;
    final forecasts = <Map<String, dynamic>>[];
    for (final l in _forecastLines) {
      final v = _parseMoney(l.controller.text);
      if (v != null && v >= 0) {
        forecasts.add({'forecast_date': l.isoDate, 'forecast_revenue': v});
      }
    }
    setState(() {
      _saving = true;
      _errorBanner = null;
    });
    final res = await _service.save(
      outletId: outletId,
      monthYm: _monthYm,
      monthlyTarget: mt,
      forecasts: forecasts,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Tersimpan')),
      );
      await _loadIndex();
    } else {
      setState(() {
        _errorBanner = res?['message']?.toString() ?? 'Gagal menyimpan.';
      });
    }
  }

  Future<void> _runSuggest() async {
    final outletId = _selectedOutletId;
    if (outletId <= 0) {
      setState(() => _errorBanner = 'Pilih outlet dulu.');
      return;
    }
    final mt = _parseMoney(_monthlyTargetCtrl.text);
    if (mt == null || mt <= 0) {
      setState(() => _errorBanner = 'Isi Monthly Target dulu (lebih dari 0), baru klik AI Suggest.');
      return;
    }
    setState(() {
      _suggesting = true;
      _errorBanner = null;
    });
    final res = await _service.suggest(
      outletId: outletId,
      monthYm: _monthYm,
      monthlyTarget: mt,
    );
    if (!mounted) return;
    setState(() => _suggesting = false);
    if (res == null) {
      setState(() => _errorBanner = 'Gagal AI Suggest.');
      return;
    }
    if (res['message'] != null && res['forecasts'] == null) {
      setState(() => _errorBanner = res['message']?.toString());
      return;
    }
    final list = (res['forecasts'] as List?) ?? [];
    final byDate = <String, double>{};
    for (final row in list) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final d = m['forecast_date']?.toString() ?? '';
      final key = d.length >= 10 ? d.substring(0, 10) : d;
      final rv = m['forecast_revenue'];
      final n = rv is num ? rv.toDouble() : double.tryParse('$rv') ?? 0;
      byDate[key] = n;
    }
    setState(() {
      for (final l in _forecastLines) {
        final v = byDate[l.isoDate];
        l.controller.text = v != null && v > 0 ? _formatMoneyDisplay(v) : '';
      }
    });
    if (res['factors'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Suggest diterapkan. Cek faktor di web untuk detail.')),
      );
    }
  }

  Future<void> _runHistorical() async {
    final outletId = _selectedOutletId;
    if (outletId <= 0) {
      setState(() => _errorBanner = 'Pilih outlet dulu.');
      return;
    }
    setState(() {
      _historyLoading = true;
      _historyMessage = '';
      _errorBanner = null;
    });
    final res = await _service.generateHistorical(
      outletId: outletId,
      endMonthYm: _monthYm,
      monthsBack: _historyMonthsBack,
    );
    if (!mounted) return;
    setState(() {
      _historyLoading = false;
      if (res != null) {
        _historyMessage = res['message']?.toString() ?? '';
        final cards = res['month_cards'];
        _historyCards = cards is List
            ? cards.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
      } else {
        _errorBanner = 'Gagal generate historis.';
      }
    });
  }

  Future<void> _openHistoryDetail(Map<String, dynamic> card) async {
    final ym = card['ym']?.toString();
    if (ym == null || _selectedOutletId <= 0) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, scroll) => _HistoryDetailSheet(
          service: _service,
          outletId: _selectedOutletId,
          monthYm: ym,
          scrollController: scroll,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Revenue Targets'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadIndex,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _buildHero(),
                  if (_errorBanner != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_errorBanner!, style: TextStyle(color: Colors.red.shade900)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildControls(),
                  const SizedBox(height: 12),
                  _buildHint(),
                  const SizedBox(height: 20),
                  _buildHistoricalSection(),
                  const SizedBox(height: 20),
                  _buildForecastSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVENUE PLANNING',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monthly Target & Daily Forecast',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gunakan AI Suggest sebagai baseline, lalu sesuaikan angka sesuai strategi outlet.',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                if (v != null) {
                  setState(() {
                    _selectedOutletId = v;
                    _rebuildForecastLinesFromMaps([]);
                  });
                }
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
          const SizedBox(height: 14),
          const Text('Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _styledDropdown<int>(
                  value: _month,
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2000, m)))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _month = v;
                        _rebuildForecastLinesFromMaps([]);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _styledDropdown<int>(
                  value: _year,
                  items: List.generate(7, (i) => DateTime.now().year - 3 + i)
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _year = v;
                        _rebuildForecastLinesFromMaps([]);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Monthly Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: _monthlyTargetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco(hint: '0'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _loadIndex,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF475569)),
                child: const Text('Load'),
              ),
              FilledButton(
                onPressed: _suggesting ? null : _runSuggest,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: Text(_suggesting ? 'Generating...' : 'AI Suggest'),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                child: Text(_saving ? 'Saving...' : 'Simpan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _styledDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return InputDecorator(
      decoration: _inputDeco(),
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

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Monthly Target wajib diisi dulu. AI Suggest akan membagi forecast harian berdasarkan pola 3 bulan terakhir + kalender (weekday/weekend/libur), '
        'lalu menyesuaikan total agar tetap mengikuti Monthly Target yang kamu input.',
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
      ),
    );
  }

  Widget _buildHistoricalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Revenue Historis',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bulan di kolom "Bulan" = acuan (misal April). Jumlah bulan = berapa bulan ke belakang dari acuan, '
            'tanpa menyertakan bulan acuan. Contoh: April + 2 bulan → Februari & Maret (agregasi dari orders). '
            'Hanya untuk referensi di layar — tidak menyimpan ke database target/forecast.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah Bulan',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    _styledDropdown<int>(
                      value: _historyMonthsBack,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} bulan')))
                          .toList(),
                      onChanged: (v) => setState(() => _historyMonthsBack = v ?? 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _historyLoading ? null : _runHistorical,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                child: Text(_historyLoading ? 'Generating...' : 'Generate Historis (Orders)'),
              ),
            ],
          ),
          if (_historyMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_historyMessage, style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
          ],
          if (_historyCards.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                children: [
                  const TextSpan(text: 'Ringkasan per bulan', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                    text: ' — klik card untuk breakdown harian, weekday/weekend, lunch/dinner',
                    style: TextStyle(fontWeight: FontWeight.w400, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._historyCards.map((c) => _historyCard(c)),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> c) {
    final ym = c['ym']?.toString() ?? '';
    final label = c['label']?.toString() ?? ym;
    final total = c['monthly_total'];
    final days = c['days_with_orders'];
    final t = total is num ? total.toDouble() : double.tryParse('$total') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openHistoryDetail(c),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Dari orders', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                Text(ym, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Rp ${_displayFmt.format(t)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Hari ada transaksi: $days', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastSection() {
    final total = _totalForecastInput();
    final holidayDays = _forecastLines.where((l) => l.isHoliday).length;
    final weekendDays = _forecastLines.where((l) => !l.isHoliday && l.isWeekend).length;
    final dfShort = DateFormat.yMMMd('id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daily Forecast',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              'Total Forecast: Rp ${_displayFmt.format(total)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text('Hari Libur: $holidayDays', style: const TextStyle(fontSize: 12)),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
            ),
            Chip(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text('Weekend: $weekendDays', style: const TextStyle(fontSize: 12)),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.amber.shade300))),
            const SizedBox(width: 6),
            const Text('Weekend', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
            const SizedBox(width: 14),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.red.shade300))),
            const SizedBox(width: 6),
            const Text('Hari Libur', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bulk Update',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickBulkDate(isStart: true),
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _inputDeco(hint: 'Awal').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                        ),
                        child: Text(
                          _bulkStartDate != null ? dfShort.format(_bulkStartDate!) : 'Tanggal awal',
                          style: TextStyle(fontSize: 13, color: _bulkStartDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickBulkDate(isStart: false),
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _inputDeco(hint: 'Akhir').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                        ),
                        child: Text(
                          _bulkEndDate != null ? dfShort.format(_bulkEndDate!) : 'Tanggal akhir',
                          style: TextStyle(fontSize: 13, color: _bulkEndDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _styledDropdown<bool>(
                value: _bulkSetMode,
                items: const [
                  DropdownMenuItem(value: true, child: Text('Set Nominal')),
                  DropdownMenuItem(value: false, child: Text('Naik/Turun %')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _bulkSetMode = v);
                },
              ),
              const SizedBox(height: 10),
              if (_bulkSetMode)
                TextField(
                  controller: _bulkValueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco(hint: 'Nominal'),
                )
              else
                TextField(
                  controller: _bulkPercentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: _inputDeco(hint: 'Persen, contoh -5'),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _forecastLines.isEmpty ? null : _applyBulkUpdate,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                  child: const Text('Terapkan ke Rentang Tanggal'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._forecastLines.map(_forecastRow),
      ],
    );
  }

  Widget _forecastRow(_ForecastLine l) {
    final bg = l.isHoliday
        ? Colors.red.shade50
        : l.isWeekend
            ? Colors.amber.shade50
            : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.isoDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(
                  l.weekdayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: l.isWeekend ? Colors.amber.shade900 : const Color(0xFF64748B),
                  ),
                ),
                if (l.isHoliday)
                  Text(
                    'Libur${l.holidayDesc.isNotEmpty ? ': ${l.holidayDesc}' : ''}',
                    style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: l.controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco(hint: '0').copyWith(isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailSheet extends StatefulWidget {
  const _HistoryDetailSheet({
    required this.service,
    required this.outletId,
    required this.monthYm,
    required this.scrollController,
  });

  final OutletRevenueTargetService service;
  final int outletId;
  final String monthYm;
  final ScrollController scrollController;

  @override
  State<_HistoryDetailSheet> createState() => _HistoryDetailSheetState();
}

class _HistoryDetailSheetState extends State<_HistoryDetailSheet> {
  bool _loading = true;
  String? _err;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.service.historicalMonthDetail(
      outletId: widget.outletId,
      monthYm: widget.monthYm,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (d == null) {
        _err = 'Gagal memuat detail';
      } else {
        _data = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _data?['month_label']?.toString() ?? widget.monthYm,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator(size: 28, color: Color(0xFF6366F1)))
                : _err != null
                    ? Center(child: Text(_err!))
                    : ListView(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (_data != null) ...[
                            Text(
                              _data!['outlet']?['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            _kv('Weekday total', _data!['weekday_weekend']?['weekday_total']),
                            _kv('Weekend total', _data!['weekday_weekend']?['weekend_total']),
                            _kv('Lunch', _data!['lunch_dinner']?['lunch']?['revenue']),
                            _kv('Dinner', _data!['lunch_dinner']?['dinner']?['revenue']),
                            const Divider(height: 28),
                            const Text('Harian', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...(List<Map<String, dynamic>>.from(
                              (_data!['daily'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
                            ))
                                .map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('${r['date']} · ${r['day_name']}')),
                                        Text(
                                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                                              .format(num.tryParse('${r['revenue']}') ?? 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(n),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
