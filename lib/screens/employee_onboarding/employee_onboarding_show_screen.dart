import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../services/employee_onboarding_service.dart';
import 'employee_onboarding_ui.dart';

class EmployeeOnboardingShowScreen extends StatefulWidget {
  final int recordId;

  const EmployeeOnboardingShowScreen({super.key, required this.recordId});

  @override
  State<EmployeeOnboardingShowScreen> createState() => _EmployeeOnboardingShowScreenState();
}

class _EmployeeOnboardingShowScreenState extends State<EmployeeOnboardingShowScreen> {
  final _service = EmployeeOnboardingService();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _record;
  int _activeWeek = 1;
  bool _canApproveWeek = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDetail(widget.recordId);
    if (!mounted) return;
    if (res == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat detail')));
      return;
    }
    _record = Map<String, dynamic>.from(res['record'] as Map);
    _canApproveWeek = res['can_approve_week'] == true;
    _activeWeek = _record?['unlocked_week'] as int? ?? 1;
    setState(() => _loading = false);
  }

  List<dynamic> get _weeks => (_record?['weeks'] as List? ?? []);

  Map<String, dynamic>? get _currentWeek {
    for (final w in _weeks) {
      if ((w as Map)['week_number'] == _activeWeek) return Map<String, dynamic>.from(w);
    }
    return null;
  }

  List<Map<String, dynamic>> get _items {
    final week = _currentWeek;
    if (week == null) return [];
    return (week['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _saveItems() async {
    setState(() => _saving = true);
    final res = await _service.updateItems(
      id: widget.recordId,
      items: _items
          .where((item) => item['can_edit'] == true)
          .map((item) => {
                'id': item['id'],
                'status': item['status'],
                'remark': item['remark'],
              })
          .toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      _record = Map<String, dynamic>.from(res['record'] as Map);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Future<void> _processApproval(String action) async {
    final res = await _service.approve(id: widget.recordId, weekNumber: _activeWeek, action: action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Selesai')));
    if (res['success'] == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final week = _currentWeek;
    final submission = week?['submission'] as Map?;

    return AppScaffold(
      title: _record?['number']?.toString() ?? 'Onboarding',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: EmployeeOnboardingUi.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_record?['employee_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(_record?['template_name']?.toString() ?? '-', style: const TextStyle(color: EmployeeOnboardingUi.textMuted)),
                        const SizedBox(height: 8),
                        Text('Minggu ${_record?['unlocked_week']}/${_record?['total_weeks']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _weeks.map((w) {
                        final weekNum = (w as Map)['week_number'] as int;
                        final unlocked = w['is_unlocked'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('M$weekNum'),
                            selected: _activeWeek == weekNum,
                            onSelected: unlocked ? (_) => setState(() => _activeWeek = weekNum) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_canApproveWeek && submission?['status'] == 'submitted') ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(onPressed: () => _processApproval('approve'), child: const Text('Approve')),
                        FilledButton(onPressed: () => _processApproval('requires_revision'), style: FilledButton.styleFrom(backgroundColor: Colors.amber), child: const Text('Revisi')),
                        FilledButton(onPressed: () => _processApproval('reject'), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Tolak')),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  ..._items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: EmployeeOnboardingUi.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['area_name']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: EmployeeOnboardingUi.textMuted)),
                          Text(item['checklist_text']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('PIC: ${item['assigned_pic_name'] ?? '-'}'),
                          if (item['can_edit'] == true) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: item['status']?.toString() ?? 'pending',
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                                DropdownMenuItem(value: 'done', child: Text('Done')),
                              ],
                              onChanged: (v) => setState(() => item['status'] = v),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: TextEditingController(text: item['remark']?.toString() ?? ''),
                              decoration: const InputDecoration(labelText: 'Remark', border: OutlineInputBorder()),
                              onChanged: (v) => item['remark'] = v,
                            ),
                          ] else
                            Text('Status: ${EmployeeOnboardingUi.statusLabel(item['status']?.toString() ?? '')}'),
                        ],
                      ),
                    );
                  }),
                  if (_items.any((item) => item['can_edit'] == true))
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveItems,
                        style: FilledButton.styleFrom(backgroundColor: EmployeeOnboardingUi.primary),
                        child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
