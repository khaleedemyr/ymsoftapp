import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/employee_coaching_models.dart';
import '../../services/employee_coaching_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'employee_coaching_ui.dart';

class EmployeeCoachingFormScreen extends StatefulWidget {
  final int? recordId;

  const EmployeeCoachingFormScreen({super.key, this.recordId});

  @override
  State<EmployeeCoachingFormScreen> createState() => _EmployeeCoachingFormScreenState();
}

class _EmployeeCoachingFormScreenState extends State<EmployeeCoachingFormScreen> {
  final _service = EmployeeCoachingService();
  final _employeeSearchController = TextEditingController();
  final _performanceDescController = TextEditingController();
  final _actionTakenController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _showEmployeeSuggestions = false;
  Timer? _searchTimer;

  List<ConcernOption> _concernOptions = [];
  final Map<String, ConcernState> _concernState = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, TextEditingController> _otherLabelControllers = {};

  int? _employeeId;
  EmployeeSuggestion? _selectedEmployee;
  List<EmployeeSuggestion> _employeeSuggestions = [];
  String? _actionDueDate;
  String? _reviewPlanDate;

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _employeeSearchController.dispose();
    _performanceDescController.dispose();
    _actionTakenController.dispose();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    for (final c in _otherLabelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initConcernControllers() {
    for (final option in _concernOptions) {
      _concernState.putIfAbsent(option.code, () => ConcernState());
      _commentControllers.putIfAbsent(
        option.code,
        () => TextEditingController(text: _concernState[option.code]!.comment),
      );
      _otherLabelControllers.putIfAbsent(
        option.code,
        () => TextEditingController(text: _concernState[option.code]!.otherLabel),
      );
    }
  }

  Future<void> _loadFormData() async {
    setState(() => _loading = true);
    final res = await _service.getCreateData(recordId: widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat form')),
      );
      return;
    }

    _concernOptions = (res['concern_options'] as List? ?? [])
        .map((e) => ConcernOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _initConcernControllers();

    final record = res['record'] as Map?;
    if (record != null) {
      _employeeId = record['employee_id'] as int?;
      _employeeSearchController.text = record['employee_name']?.toString() ?? '';
      _selectedEmployee = EmployeeSuggestion(
        id: _employeeId ?? 0,
        namaLengkap: record['employee_name']?.toString() ?? '',
        jabatanName: record['jabatan_name']?.toString() ?? '-',
        outletName: record['outlet_name']?.toString() ?? '-',
        divisionName: record['division_name']?.toString() ?? '-',
      );
      _performanceDescController.text = record['performance_description']?.toString() ?? '';
      _actionTakenController.text = record['action_taken']?.toString() ?? '';
      _actionDueDate = record['action_due_date']?.toString();
      _reviewPlanDate = record['performance_review_plan_date']?.toString();

      for (final item in (record['concerns'] as List? ?? [])) {
        final row = EmployeeCoachingConcernRow.fromJson(Map<String, dynamic>.from(item as Map));
        final state = _concernState[row.concernCode];
        if (state == null) continue;
        state.checked = true;
        state.comment = row.comment;
        state.otherLabel = row.otherLabel ?? '';
        _commentControllers[row.concernCode]?.text = row.comment;
        _otherLabelControllers[row.concernCode]?.text = row.otherLabel ?? '';
      }
    }

    setState(() => _loading = false);
  }

  void _onEmployeeSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final q = value.trim();
      if (q.length < 2) {
        if (mounted) {
          setState(() {
            _employeeSuggestions = [];
            _showEmployeeSuggestions = false;
          });
        }
        return;
      }
      final results = await _service.searchEmployees(q);
      if (!mounted) return;
      setState(() {
        _employeeSuggestions = results.map(EmployeeSuggestion.fromJson).toList();
        _showEmployeeSuggestions = _employeeSuggestions.isNotEmpty;
      });
    });
  }

  void _selectEmployee(EmployeeSuggestion emp) {
    setState(() {
      _selectedEmployee = emp;
      _employeeId = emp.id;
      _employeeSearchController.text = emp.namaLengkap;
      _showEmployeeSuggestions = false;
      _employeeSuggestions = [];
    });
  }

  Future<void> _pickDate({required bool isActionDue}) async {
    DateTime initial = DateTime.now();
    final current = isActionDue ? _actionDueDate : _reviewPlanDate;
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
    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (isActionDue) {
        _actionDueDate = formatted;
      } else {
        _reviewPlanDate = formatted;
      }
    });
  }

  List<Map<String, dynamic>> _buildConcernsPayload() {
    return _concernOptions
        .where((o) => _concernState[o.code]?.checked == true)
        .map((o) {
          final state = _concernState[o.code]!;
          state.comment = _commentControllers[o.code]?.text ?? '';
          state.otherLabel = _otherLabelControllers[o.code]?.text ?? '';
          return state.toPayload(o.code);
        })
        .toList();
  }

  bool _validate() {
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Karyawan wajib dipilih')),
      );
      return false;
    }

    final concerns = _buildConcernsPayload();
    if (concerns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu Point of Concern')),
      );
      return false;
    }

    for (final item in concerns) {
      if ((item['comment'] as String).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment wajib diisi untuk setiap concern yang dipilih')),
        );
        return false;
      }
      if (item['code'] == 'other' && (item['other_label'] == null || (item['other_label'] as String).isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isian Lain-Lain wajib diisi jika opsi Other dipilih')),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    final payload = {
      'employee_id': _employeeId,
      'performance_description': _performanceDescController.text.trim().isEmpty
          ? null
          : _performanceDescController.text.trim(),
      'action_taken': _actionTakenController.text.trim().isEmpty
          ? null
          : _actionTakenController.text.trim(),
      'action_due_date': _actionDueDate,
      'performance_review_plan_date': _reviewPlanDate,
      'concerns': _buildConcernsPayload(),
    };

    final res = await _service.save(payload: payload, recordId: widget.recordId);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil disimpan')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menyimpan')),
      );
    }
  }

  Widget _dateField({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: EmployeeCoachingUi.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          EmployeeCoachingUi.formatDate(value),
          style: TextStyle(
            color: value == null ? EmployeeCoachingUi.textMuted : EmployeeCoachingUi.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Coaching' : 'Tambah Coaching',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: EmployeeCoachingUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Karyawan *',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _employeeSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Cari nama karyawan...',
                                  filled: true,
                                  fillColor: EmployeeCoachingUi.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  suffixIcon: _employeeId != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _employeeId = null;
                                              _selectedEmployee = null;
                                              _employeeSearchController.clear();
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (v) {
                                  _employeeId = null;
                                  _selectedEmployee = null;
                                  _onEmployeeSearchChanged(v);
                                },
                              ),
                              if (_showEmployeeSuggestions)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: EmployeeCoachingUi.border),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _employeeSuggestions.length,
                                    itemBuilder: (_, i) {
                                      final emp = _employeeSuggestions[i];
                                      return ListTile(
                                        dense: true,
                                        title: Text(emp.namaLengkap, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text('${emp.jabatanName} · ${emp.outletName}'),
                                        onTap: () => _selectEmployee(emp),
                                      );
                                    },
                                  ),
                                ),
                              if (_selectedEmployee != null) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _infoChip('Outlet', _selectedEmployee!.outletName)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _infoChip('Jabatan', _selectedEmployee!.jabatanName)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _infoChip('Divisi', _selectedEmployee!.divisionName),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: EmployeeCoachingUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Point of Concern',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const Text(
                                'Hal yang diperhatikan, masalah / kendala, keterlibatan kejadian',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: EmployeeCoachingUi.textMuted),
                              ),
                              const SizedBox(height: 12),
                              ..._concernOptions.map((option) => _buildConcernTile(option)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: EmployeeCoachingUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Performance Concern / Issue',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _performanceDescController,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText: 'Tulis deskripsi...',
                                  filled: true,
                                  fillColor: EmployeeCoachingUi.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: EmployeeCoachingUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Action Taken & Due Date',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _actionTakenController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Tulis tindak lanjut...',
                                  filled: true,
                                  fillColor: EmployeeCoachingUi.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _dateField(
                                label: 'Due Date',
                                value: _actionDueDate,
                                onTap: () => _pickDate(isActionDue: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: EmployeeCoachingUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Performance Review Plan Date',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              _dateField(
                                label: 'Review Plan Date',
                                value: _reviewPlanDate,
                                onTap: () => _pickDate(isActionDue: false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: EmployeeCoachingUi.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEdit ? 'Update' : 'Simpan'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EmployeeCoachingUi.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: EmployeeCoachingUi.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildConcernTile(ConcernOption option) {
    final state = _concernState[option.code]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: state.checked ? EmployeeCoachingUi.primary.withValues(alpha: 0.4) : EmployeeCoachingUi.border,
        ),
        borderRadius: BorderRadius.circular(12),
        color: state.checked ? EmployeeCoachingUi.primary.withValues(alpha: 0.04) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                state.checked = !state.checked;
                if (!state.checked) {
                  state.comment = '';
                  state.otherLabel = '';
                  _commentControllers[option.code]?.clear();
                  _otherLabelControllers[option.code]?.clear();
                }
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: state.checked,
                  activeColor: EmployeeCoachingUi.primary,
                  onChanged: (v) {
                    setState(() {
                      state.checked = v ?? false;
                      if (!state.checked) {
                        state.comment = '';
                        state.otherLabel = '';
                        _commentControllers[option.code]?.clear();
                        _otherLabelControllers[option.code]?.clear();
                      }
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.labelEn, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        option.labelId,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: EmployeeCoachingUi.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (state.checked) ...[
            if (option.code == 'other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _otherLabelControllers[option.code],
                decoration: InputDecoration(
                  labelText: 'Lain-Lain (sebutkan)',
                  filled: true,
                  fillColor: EmployeeCoachingUi.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _commentControllers[option.code],
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Comment *',
                filled: true,
                fillColor: EmployeeCoachingUi.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
