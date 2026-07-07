import 'package:flutter/material.dart';
import '../../models/employee_coaching_models.dart';
import '../../services/employee_coaching_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'employee_coaching_form_screen.dart';
import 'employee_coaching_ui.dart';

class EmployeeCoachingDetailScreen extends StatefulWidget {
  final int recordId;

  const EmployeeCoachingDetailScreen({super.key, required this.recordId});

  @override
  State<EmployeeCoachingDetailScreen> createState() => _EmployeeCoachingDetailScreenState();
}

class _EmployeeCoachingDetailScreenState extends State<EmployeeCoachingDetailScreen> {
  final _service = EmployeeCoachingService();

  bool _loading = true;
  Map<String, dynamic>? _record;
  List<ConcernOption> _concernOptions = [];
  List<EmployeeCoachingConcernRow> _concerns = [];

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat detail')),
      );
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map);
    _concernOptions = (res['concern_options'] as List? ?? [])
        .map((e) => ConcernOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _concerns = (_record!['concerns'] as List? ?? [])
        .map((e) => EmployeeCoachingConcernRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    setState(() => _loading = false);
  }

  String _concernLabel(String code) {
    for (final o in _concernOptions) {
      if (o.code == code) return o.labelEn;
    }
    return code;
  }

  String _concernSubLabel(String code) {
    for (final o in _concernOptions) {
      if (o.code == code) return o.labelId;
    }
    return '';
  }

  Widget _metaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: EmployeeCoachingUi.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, String? subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: EmployeeCoachingUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: EmployeeCoachingUi.textMuted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textBlock(String? text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EmployeeCoachingUi.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        (text == null || text.trim().isEmpty) ? '-' : text,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Coaching',
      actions: [
        if (!_loading)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeCoachingFormScreen(recordId: widget.recordId),
                ),
              );
              if (mounted) _load();
            },
          ),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: EmployeeCoachingUi.headerGradient.copyWith(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _record?['employee_name']?.toString() ?? '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_record?['jabatan_name'] ?? '-'} · ${_record?['outlet_name'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Informasi Karyawan',
                    child: Column(
                      children: [
                        _metaLine('Outlet', _record?['outlet_name']?.toString() ?? '-'),
                        _metaLine('Jabatan', _record?['jabatan_name']?.toString() ?? '-'),
                        _metaLine('Divisi', _record?['division_name']?.toString() ?? '-'),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'Point of Concern, Issue, or Incident involving',
                    subtitle: 'Hal yang diperhatikan, masalah / kendala, keterlibatan kejadian',
                    child: _concerns.isEmpty
                        ? const Text('Tidak ada concern.', style: TextStyle(color: EmployeeCoachingUi.textMuted))
                        : Column(
                            children: _concerns.map((row) {
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: EmployeeCoachingUi.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _concernLabel(row.concernCode),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    if (_concernSubLabel(row.concernCode).isNotEmpty)
                                      Text(
                                        _concernSubLabel(row.concernCode),
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: EmployeeCoachingUi.textMuted),
                                      ),
                                    if (row.concernCode == 'other' && (row.otherLabel ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text('Lain-Lain: ${row.otherLabel}', style: const TextStyle(fontSize: 13)),
                                    ],
                                    const SizedBox(height: 8),
                                    _textBlock(row.comment),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  _sectionCard(
                    title: 'Describe specific performance concern or issue',
                    subtitle: 'Jelaskan masalah atau kinerja yang menjadi perhatian khusus',
                    child: _textBlock(_record?['performance_description']?.toString()),
                  ),
                  _sectionCard(
                    title: 'Action taken to improve performance & Due Date',
                    subtitle: 'Tindak lanjut perbaikan kinerja & batas waktu',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textBlock(_record?['action_taken']?.toString()),
                        const SizedBox(height: 12),
                        const Text('Due Date', style: TextStyle(fontSize: 12, color: EmployeeCoachingUi.textMuted)),
                        Text(
                          EmployeeCoachingUi.formatDate(_record?['action_due_date']?.toString()),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'Performance review plan date',
                    subtitle: 'Tanggal rencana peninjauan kinerja',
                    child: Text(
                      EmployeeCoachingUi.formatDate(_record?['performance_review_plan_date']?.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  _sectionCard(
                    title: 'Audit',
                    child: Column(
                      children: [
                        _metaLine('Created At', EmployeeCoachingUi.formatDateTime(_record?['created_at']?.toString())),
                        _metaLine('Created By', _record?['created_by_name']?.toString() ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
