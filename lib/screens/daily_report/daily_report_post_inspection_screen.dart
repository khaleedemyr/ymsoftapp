import 'package:flutter/material.dart';
import '../../services/daily_report_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'daily_report_ui.dart';

class DailyReportPostInspectionScreen extends StatefulWidget {
  final int reportId;
  const DailyReportPostInspectionScreen({super.key, required this.reportId});

  @override
  State<DailyReportPostInspectionScreen> createState() => _DailyReportPostInspectionScreenState();
}

class _DailyReportPostInspectionScreenState extends State<DailyReportPostInspectionScreen> {
  final DailyReportService _svc = DailyReportService();

  Map<String, dynamic>? _report;
  List<dynamic> _visitTables = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _sectionIndex = 0;

  bool _isLunch = true;
  bool _showProductivity = false;
  String _deptName = '';

  // Briefing
  final _timeConduct = TextEditingController();
  final _participant = TextEditingController();
  final _serviceInCharge = TextEditingController();
  final _barInCharge = TextEditingController();
  final _kitchenInCharge = TextEditingController();
  final _soProduct = TextEditingController();
  final _productUpselling = TextEditingController();
  final _commodityIssue = TextEditingController();
  final _oeIssue = TextEditingController();
  final _guestReservationPax = TextEditingController();
  final _dailyRevenueTarget = TextEditingController();
  final _promotionCampaign = TextEditingController();
  final _guestCommentTarget = TextEditingController();
  final _googleReviewTarget = TextEditingController();
  final _otherPreparation = TextEditingController();

  // Productivity
  final _productKnowledge = TextEditingController();
  final _sosRolePlay = TextEditingController();
  final _dailyCoaching = TextEditingController();
  final _othersActivity = TextEditingController();

  // Visit table form
  final _guestName = TextEditingController();
  final _tableNo = TextEditingController();
  final _noOfPax = TextEditingController();
  final _guestExperience = TextEditingController();

  // Summary
  final _summaryNotes = TextEditingController();

  List<String> get _sectionLabels => [
        _isLunch ? 'Morning Briefing' : 'Afternoon Briefing',
        if (_showProductivity) 'Productivity',
        'Visit Table (${_visitTables.length})',
        'Summary',
      ];

  List<Widget> get _sectionViews => [
        _briefingTab(),
        if (_showProductivity) _productivityTab(),
        _visitTab(),
        _summaryTab(),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _timeConduct, _participant, _serviceInCharge, _barInCharge, _kitchenInCharge,
      _soProduct, _productUpselling, _commodityIssue, _oeIssue, _guestReservationPax,
      _dailyRevenueTarget, _promotionCampaign, _guestCommentTarget, _googleReviewTarget,
      _otherPreparation, _productKnowledge, _sosRolePlay, _dailyCoaching, _othersActivity,
      _guestName, _tableNo, _noOfPax, _guestExperience, _summaryNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _svc.getPostInspectionData(widget.reportId);
    if (!mounted) return;

    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat data';
      });
      return;
    }

    final report = _asMap(res['daily_report']);
    if (report == null) {
      setState(() {
        _loading = false;
        _error = 'Data report tidak valid';
      });
      return;
    }

    _isLunch = report['inspection_time']?.toString() == 'lunch';
    final department = _asMap(report['department']);
    _deptName = department?['nama_departemen']?.toString().toLowerCase() ?? '';
    _showProductivity = _isLunch && (_deptName.contains('kitchen') || _deptName.contains('service') || _deptName.contains('bar'));

    final briefing = report['briefing'] is Map ? Map<String, dynamic>.from(report['briefing'] as Map) : null;
    final productivity = report['productivity'] is Map ? Map<String, dynamic>.from(report['productivity'] as Map) : null;
    final summaries = report['summaries'] is List ? report['summaries'] as List<dynamic> : <dynamic>[];
    final summaryType = _isLunch ? 'summary_1' : 'summary_2';
    Map<String, dynamic>? summary;
    for (final s in summaries) {
      if (s is Map && s['summary_type']?.toString() == summaryType) {
        summary = Map<String, dynamic>.from(s);
        break;
      }
    }

    void setIf(TextEditingController c, dynamic v) {
      if (v != null && v.toString().isNotEmpty) c.text = v.toString();
    }

    if (briefing != null) {
      setIf(_timeConduct, briefing['time_of_conduct']);
      setIf(_participant, briefing['participant']);
      setIf(_serviceInCharge, briefing['service_in_charge']);
      setIf(_barInCharge, briefing['bar_in_charge']);
      setIf(_kitchenInCharge, briefing['kitchen_in_charge']);
      setIf(_soProduct, briefing['so_product']);
      setIf(_productUpselling, briefing['product_up_selling']);
      setIf(_commodityIssue, briefing['commodity_issue']);
      setIf(_oeIssue, briefing['oe_issue']);
      setIf(_guestReservationPax, briefing['guest_reservation_pax']);
      setIf(_dailyRevenueTarget, briefing['daily_revenue_target']);
      setIf(_promotionCampaign, briefing['promotion_program_campaign']);
      setIf(_guestCommentTarget, briefing['guest_comment_target']);
      setIf(_googleReviewTarget, briefing['trip_advisor_target']);
      setIf(_otherPreparation, briefing['other_preparation']);
    }
    if (productivity != null) {
      setIf(_productKnowledge, productivity['product_knowledge_test']);
      setIf(_sosRolePlay, productivity['sos_hospitality_role_play']);
      setIf(_dailyCoaching, productivity['employee_daily_coaching']);
      setIf(_othersActivity, productivity['others_activity']);
    }
    if (summary != null) setIf(_summaryNotes, summary['notes']);

    final visitTables = _asList(report['visit_tables']);
    final visitTablesAlt = visitTables.isEmpty ? _asList(report['visitTables']) : visitTables;

    setState(() {
      _report = report;
      _visitTables = visitTablesAlt;
      _sectionIndex = _sectionIndex.clamp(0, (_showProductivity ? 4 : 3) - 1);
      _loading = false;
    });
  }

  Future<void> _saveBriefing() async {
    setState(() => _saving = true);
    final res = await _svc.saveBriefing(widget.reportId, {
      'briefing_type': _isLunch ? 'morning' : 'afternoon',
      'time_of_conduct': _timeConduct.text.trim().isEmpty ? null : _timeConduct.text.trim(),
      'participant': _participant.text.trim(),
      'service_in_charge': _serviceInCharge.text.trim(),
      'bar_in_charge': _barInCharge.text.trim(),
      'kitchen_in_charge': _kitchenInCharge.text.trim(),
      'so_product': _soProduct.text.trim(),
      'product_up_selling': _productUpselling.text.trim(),
      'commodity_issue': _commodityIssue.text.trim(),
      'oe_issue': _oeIssue.text.trim(),
      'guest_reservation_pax': int.tryParse(_guestReservationPax.text.trim()),
      'daily_revenue_target': double.tryParse(_dailyRevenueTarget.text.trim()),
      'promotion_program_campaign': _promotionCampaign.text.trim(),
      'guest_comment_target': _guestCommentTarget.text.trim(),
      'trip_advisor_target': _googleReviewTarget.text.trim(),
      'other_preparation': _otherPreparation.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Tersimpan' : 'Gagal')), behavior: SnackBarBehavior.floating));
    if (res['success'] == true) _load();
  }

  Future<void> _saveProductivity() async {
    setState(() => _saving = true);
    final res = await _svc.saveProductivity(widget.reportId, {
      'product_knowledge_test': _productKnowledge.text.trim(),
      'sos_hospitality_role_play': _sosRolePlay.text.trim(),
      'employee_daily_coaching': _dailyCoaching.text.trim(),
      'others_activity': _othersActivity.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? ''), behavior: SnackBarBehavior.floating));
    if (res['success'] == true) _load();
  }

  Future<void> _addVisitTable() async {
    setState(() => _saving = true);
    final res = await _svc.saveVisitTable(widget.reportId, {
      'guest_name': _guestName.text.trim(),
      'table_no': _tableNo.text.trim(),
      'no_of_pax': int.tryParse(_noOfPax.text.trim()),
      'guest_experience': _guestExperience.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      _guestName.clear();
      _tableNo.clear();
      _noOfPax.clear();
      _guestExperience.clear();
      _load();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? ''), behavior: SnackBarBehavior.floating));
  }

  Future<void> _saveSummary() async {
    setState(() => _saving = true);
    final res = await _svc.saveSummary(widget.reportId, {
      'summary_type': _isLunch ? 'summary_1' : 'summary_2',
      'notes': _summaryNotes.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? ''), behavior: SnackBarBehavior.floating));
    if (res['success'] == true) {
      await _load();
      if (_report?['status']?.toString() == 'completed' && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _forceComplete() async {
    final res = await _svc.forceComplete(widget.reportId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  Widget _field(TextEditingController c, String label, {int lines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: drInputDecoration(label),
        maxLines: lines,
        keyboardType: keyboard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Post Inspection', body: Center(child: AppLoadingIndicator()));
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Post Inspection',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
      );
    }

    if (_report == null) {
      return const AppScaffold(title: 'Post Inspection', body: Center(child: AppLoadingIndicator()));
    }

    final outletMap = _asMap(_report!['outlet']);
    final outlet = outletMap?['nama_outlet']?.toString() ?? '';
    final sections = _sectionLabels;
    final views = _sectionViews;
    final safeIndex = _sectionIndex.clamp(0, views.length - 1);

    return AppScaffold(
      title: 'Post Inspection',
      body: Container(
        color: DrColors.surface,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: DrColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(outlet, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DrColors.textPrimary)),
                        Text('${_isLunch ? 'Lunch' : 'Dinner'} · Post Inspection Form', style: const TextStyle(fontSize: 12, color: DrColors.textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _forceComplete, child: const Text('Force Complete')),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: List.generate(sections.length, (index) {
                  final selected = safeIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(sections[index]),
                      selected: selected,
                      onSelected: (_) => setState(() => _sectionIndex = index),
                      selectedColor: DrColors.primaryLight,
                      labelStyle: TextStyle(
                        color: selected ? DrColors.primary : DrColors.textSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      side: BorderSide(color: selected ? DrColors.primary : DrColors.border),
                      backgroundColor: Colors.white,
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: views,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _briefingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DrSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_timeConduct, 'Time of Conduct (HH:mm)'),
              _field(_participant, 'Participant'),
              if (_deptName.contains('service')) _field(_serviceInCharge, 'Service In Charge'),
              if (_deptName.contains('bar')) _field(_barInCharge, 'Bar In Charge'),
              if (_deptName.contains('kitchen')) _field(_kitchenInCharge, 'Kitchen In Charge'),
              _field(_soProduct, 'SO Product', lines: 2),
              _field(_productUpselling, 'Product Up Selling', lines: 2),
              _field(_commodityIssue, 'Commodity Issue', lines: 2),
              _field(_oeIssue, 'OE Issue', lines: 2),
              _field(_guestReservationPax, 'Guest Reservation Pax', keyboard: TextInputType.number),
              _field(_dailyRevenueTarget, 'Daily Revenue Target', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _field(_promotionCampaign, 'Promotion Program Campaign', lines: 2),
              _field(_guestCommentTarget, 'Guest Comment Target'),
              _field(_googleReviewTarget, 'Google Review Target'),
              _field(_otherPreparation, 'Other Preparation', lines: 3),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: DrColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _saveBriefing,
                child: const Text('Simpan Briefing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _productivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DrSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_productKnowledge, 'Product Knowledge Test', lines: 2),
              _field(_sosRolePlay, 'SOS Hospitality Role Play', lines: 2),
              _field(_dailyCoaching, 'Employee Daily Coaching', lines: 2),
              _field(_othersActivity, 'Others Activity', lines: 2),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: DrColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _saveProductivity,
                child: const Text('Simpan Productivity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _visitTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Minimum 5 visit table untuk auto-complete', style: TextStyle(color: DrColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        ..._visitTables.map((vt) {
          final m = _asMap(vt);
          if (m == null) return const SizedBox.shrink();
          return DrSectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m['guest_name'] ?? '-'} · Meja ${m['table_no'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Pax: ${m['no_of_pax'] ?? '-'} · ${m['guest_experience'] ?? ''}'),
            ),
          );
        }),
        const SizedBox(height: 8),
        DrSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_guestName, 'Guest Name'),
              _field(_tableNo, 'Table No'),
              _field(_noOfPax, 'No of Pax', keyboard: TextInputType.number),
              _field(_guestExperience, 'Guest Experience', lines: 3),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: DrColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _addVisitTable,
                child: const Text('Tambah Visit Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DrSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_summaryNotes, 'Report Summary Notes', lines: 6),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: DrColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _saveSummary,
                child: const Text('Simpan Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
