import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/fb_product_calibration_models.dart';
import '../../services/fb_product_calibration_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'fb_product_calibration_detail_screen.dart';
import 'fb_product_calibration_form_screen.dart';
import 'fb_product_calibration_ui.dart';

class FbProductCalibrationIndexScreen extends StatefulWidget {
  const FbProductCalibrationIndexScreen({super.key});

  @override
  State<FbProductCalibrationIndexScreen> createState() => _FbProductCalibrationIndexScreenState();
}

class _FbProductCalibrationIndexScreenState extends State<FbProductCalibrationIndexScreen> {
  final _service = FbProductCalibrationService();

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _loading = true;
  List<CalibrationCalendarEvent> _events = [];
  Map<String, String> _holidays = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _monthTitle() {
    final dt = DateTime(_year, _month, 1);
    return DateFormat('MMMM yyyy', 'id_ID').format(dt);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.getCalendar(year: _year, month: _month),
      _service.fetchCompanyHolidays(),
    ]);
    if (!mounted) return;

    final calRes = results[0] as Map<String, dynamic>?;
    final holidayList = results[1] as List<Map<String, dynamic>>;

    final holidayMap = <String, String>{};
    for (final h in holidayList) {
      final raw = h['tgl_libur']?.toString() ?? '';
      final key = raw.length >= 10 ? raw.substring(0, 10) : raw;
      if (key.isNotEmpty) {
        holidayMap[key] = h['keterangan']?.toString() ?? 'Libur nasional';
      }
    }

    setState(() {
      _events = (calRes?['calendar_events'] as List? ?? [])
          .map((e) => CalibrationCalendarEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _holidays = holidayMap;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    setState(() {
      _month = m;
      _year = y;
    });
    _load();
  }

  void _goThisMonth() {
    final n = DateTime.now();
    setState(() {
      _year = n.year;
      _month = n.month;
    });
    _load();
  }

  List<CalibrationCalendarEvent> _eventsOn(String dateStr) {
    return _events.where((e) => e.date == dateStr).toList();
  }

  bool _canCreateOn(String dateStr) => dateStr.isNotEmpty && dateStr.compareTo(_todayStr) >= 0;

  void _openCreate(String dateStr) {
    if (!_canCreateOn(dateStr)) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FbProductCalibrationFormScreen(scheduledDate: dateStr)),
    ).then((_) => _load());
  }

  void _showDayEventsSheet(String dateStr, List<CalibrationCalendarEvent> dayEvents) {
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.parse(dateStr));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('${dayEvents.length} jadwal calibration', style: const TextStyle(color: FbCalibrationUi.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: dayEvents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final ev = dayEvents[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEventSheet(ev);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: FbCalibrationUi.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: FbCalibrationUi.parseHexColor(ev.backgroundColor),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ev.outletName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${ev.modeLabel} · ${FbCalibrationUi.statusLabel(ev.status)}',
                                    style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted),
                                  ),
                                  if (ev.conductorName.isNotEmpty)
                                    Text('Conducted by: ${ev.conductorName}', style: const TextStyle(fontSize: 11, color: FbCalibrationUi.textMuted)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: FbCalibrationUi.textMuted),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventSheet(CalibrationCalendarEvent event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.outletName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Conducted by: ${event.conductorName}', style: const TextStyle(color: FbCalibrationUi.textMuted)),
            Text('Mode: ${event.modeLabel}', style: const TextStyle(color: FbCalibrationUi.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Status: ${FbCalibrationUi.statusLabel(event.status)}'),
            const SizedBox(height: 8),
            Text('Products (${event.productCount}):'),
            ...event.products.map((p) => Text('• $p', style: const TextStyle(fontSize: 13))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FbProductCalibrationDetailScreen(recordId: event.calibrationId),
                      ),
                    ).then((_) => _load());
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Detail'),
                  style: FilledButton.styleFrom(backgroundColor: FbCalibrationUi.inProgress),
                ),
                if (event.status != 'completed')
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FbProductCalibrationFormScreen(recordId: event.calibrationId),
                        ),
                      ).then((_) => _load());
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Hapus jadwal?'),
                        content: Text('Hapus jadwal ${event.outletName}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && mounted) {
                      final res = await _service.delete(event.calibrationId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message']?.toString() ?? 'Selesai')),
                        );
                        _load();
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: FbCalibrationUi.border),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final startWeekday = firstDay.weekday; // Mon=1
    final leading = startWeekday - 1;

    return AppScaffold(
      title: 'F&B Calibration',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(_todayStr),
        backgroundColor: FbCalibrationUi.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              decoration: FbCalibrationUi.headerGradient,
              child: const Text(
                'Kalender jadwal calibration product F&B per outlet',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton.outlined(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Text(
                      _monthTitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.outlined(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _goThisMonth, child: const Text('Bulan ini')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _legendItem(FbCalibrationUi.scheduled, 'Scheduled'),
                  _legendItem(FbCalibrationUi.inProgress, 'In Progress'),
                  _legendItem(FbCalibrationUi.completed, 'Completed'),
                  _legendItem(Colors.red.shade300, 'Hari Libur'),
                ],
              ),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoadingIndicator()))
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: FbCalibrationUi.cardDecoration,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                            .map((d) => Expanded(
                                  child: Center(
                                    child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: FbCalibrationUi.textMuted)),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 4),
                      ...List.generate((leading + daysInMonth + 6) ~/ 7, (week) {
                        return Row(
                          children: List.generate(7, (wd) {
                            final cell = week * 7 + wd;
                            final dayNum = cell - leading + 1;
                            if (dayNum < 1 || dayNum > daysInMonth) {
                              return const Expanded(child: SizedBox(height: 88));
                            }
                            final dateStr =
                                '$_year-${_month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                            final dayEvents = _eventsOn(dateStr);
                            final isHoliday = _holidays.containsKey(dateStr);
                            final canAdd = _canCreateOn(dateStr);

                            return Expanded(
                              child: GestureDetector(
                                onTap: canAdd ? () => _openCreate(dateStr) : null,
                                child: Container(
                                  height: 88,
                                  margin: const EdgeInsets.all(2),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isHoliday ? const Color(0xFFFEF2F2) : Colors.white,
                                    border: Border.all(
                                      color: dateStr == _todayStr ? FbCalibrationUi.primary : FbCalibrationUi.border,
                                      width: dateStr == _todayStr ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text('$dayNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                          const Spacer(),
                                          if (canAdd)
                                            InkWell(
                                              onTap: () => _openCreate(dateStr),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEDE9FE),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFC4B5FD)),
                                                ),
                                                child: const Text('+', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: FbCalibrationUi.primary)),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (isHoliday)
                                        Text(
                                          _holidays[dateStr] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 8, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                                        ),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: dayEvents.length > 2 ? 2 : dayEvents.length,
                                          itemBuilder: (_, i) {
                                            final ev = dayEvents[i];
                                            return GestureDetector(
                                              onTap: () => _showEventSheet(ev),
                                              child: Container(
                                                margin: const EdgeInsets.only(top: 2),
                                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: FbCalibrationUi.parseHexColor(ev.backgroundColor),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  ev.outletName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (dayEvents.length > 2)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _showDayEventsSheet(dateStr, dayEvents),
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              '+${dayEvents.length - 2} lagi',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700,
                                                color: FbCalibrationUi.primary,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
