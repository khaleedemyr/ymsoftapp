import 'package:flutter/material.dart';
import '../../services/daily_report_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'daily_report_inspect_screen.dart';
import 'daily_report_ui.dart';

class DailyReportCreateScreen extends StatefulWidget {
  const DailyReportCreateScreen({super.key});

  @override
  State<DailyReportCreateScreen> createState() => _DailyReportCreateScreenState();
}

class _DailyReportCreateScreenState extends State<DailyReportCreateScreen> {
  final DailyReportService _svc = DailyReportService();

  List<dynamic> _outlets = [];
  List<dynamic> _departments = [];
  int? _outletId;
  int? _departmentId;
  String _inspectionTime = 'lunch';
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final res = await _svc.getCreateData();
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _outlets = res['outlets'] as List<dynamic>? ?? [];
        _departments = res['departments'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal memuat data'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _submit() async {
    if (_outletId == null || _departmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet dan department'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _submitting = true);
    final res = await _svc.createReport(
      outletId: _outletId!,
      inspectionTime: _inspectionTime,
      departmentId: _departmentId!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res['success'] == true) {
      final reportId = (res['report_id'] as num?)?.toInt();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil'), behavior: SnackBarBehavior.floating));
      if (reportId != null) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DailyReportInspectScreen(reportId: reportId)),
        );
      } else {
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Daily Report',
      body: Container(
        color: DrColors.surface,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DrSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: DrColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.add_chart_rounded, color: DrColors.primary),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Laporan Inspeksi Baru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: DrColors.textPrimary)),
                                    SizedBox(height: 2),
                                    Text('Pilih outlet, waktu, dan department', style: TextStyle(fontSize: 12, color: DrColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DrSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: _outletId,
                            decoration: drInputDecoration('Outlet', icon: Icons.storefront_outlined),
                            items: _outlets.map((o) {
                              final m = o as Map<String, dynamic>;
                              final name = m['nama_outlet']?.toString() ?? '';
                              return DropdownMenuItem(
                                value: (m['id_outlet'] as num).toInt(),
                                child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) => _outlets.map((o) {
                              final m = o as Map<String, dynamic>;
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  m['nama_outlet']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _outletId = v),
                          ),
                          const SizedBox(height: 16),
                          const Text('Waktu Inspeksi', style: TextStyle(fontWeight: FontWeight.w600, color: DrColors.textPrimary)),
                          const SizedBox(height: 10),
                          SegmentedButton<String>(
                            style: ButtonStyle(
                              visualDensity: VisualDensity.comfortable,
                              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                            segments: const [
                              ButtonSegment(value: 'lunch', label: Text('Lunch'), icon: Icon(Icons.wb_sunny_outlined)),
                              ButtonSegment(value: 'dinner', label: Text('Dinner'), icon: Icon(Icons.nightlight_outlined)),
                            ],
                            selected: {_inspectionTime},
                            onSelectionChanged: (s) => setState(() => _inspectionTime = s.first),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: _departmentId,
                            decoration: drInputDecoration('Department', icon: Icons.category_outlined),
                            items: _departments.map((d) {
                              final m = d as Map<String, dynamic>;
                              final name = m['nama_departemen']?.toString() ?? '';
                              return DropdownMenuItem(
                                value: (m['id'] as num).toInt(),
                                child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) => _departments.map((d) {
                              final m = d as Map<String, dynamic>;
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  m['nama_departemen']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _departmentId = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DrColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Buat & Mulai Inspeksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
