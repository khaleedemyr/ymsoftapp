import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/wfh_request_service.dart';
import '../../widgets/app_loading_indicator.dart';

class WfhRequestFormScreen extends StatefulWidget {
  const WfhRequestFormScreen({super.key});

  @override
  State<WfhRequestFormScreen> createState() => _WfhRequestFormScreenState();
}

class _WfhRequestFormScreenState extends State<WfhRequestFormScreen> {
  static const Color _teal = Color(0xFF0D9488);

  final _service = WfhRequestService();
  final _reasonController = TextEditingController();
  final _approverSearchController = TextEditingController();

  bool _loadingMeta = true;
  bool _saving = false;
  bool _checkingShift = false;
  DateTime _wfhDate = DateTime.now();

  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _shiftInfo;
  String? _shiftError;

  final List<_WfhTaskRow> _tasks = [_WfhTaskRow()];
  final List<Map<String, dynamic>> _approvers = [];
  List<Map<String, dynamic>> _approverResults = [];
  bool _searchingApprovers = false;

  bool get _hasValidTask =>
      _tasks.any((t) => t.controller.text.trim().isNotEmpty);

  bool get _canSubmit =>
      !_saving &&
      _reasonController.text.trim().isNotEmpty &&
      _hasValidTask &&
      _approvers.isNotEmpty &&
      _shiftInfo != null;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _approverSearchController.dispose();
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    final meta = await _service.getCreateMeta();
    if (!mounted) return;
    if (meta != null && meta['success'] == true) {
      if (meta['employee'] is Map) {
        _employee = Map<String, dynamic>.from(meta['employee'] as Map);
      }
      final today = meta['today']?.toString();
      if (today != null) {
        try {
          _wfhDate = DateTime.parse(today);
        } catch (_) {}
      }
    }
    setState(() => _loadingMeta = false);
    await _checkShift();
  }

  Future<void> _pickWfhDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _wfhDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _wfhDate = picked;
      _shiftInfo = null;
      _shiftError = null;
    });
    await _checkShift();
  }

  Future<void> _checkShift() async {
    setState(() {
      _checkingShift = true;
      _shiftInfo = null;
      _shiftError = null;
    });

    final res = await _service.checkShift(DateFormat('yyyy-MM-dd').format(_wfhDate));
    if (!mounted) return;

    setState(() {
      _checkingShift = false;
      if (res['success'] == true && res['shift'] is Map) {
        _shiftInfo = Map<String, dynamic>.from(res['shift'] as Map);
        _shiftError = null;
      } else {
        _shiftInfo = null;
        _shiftError = res['message']?.toString() ??
            'Shift tidak ditemukan untuk tanggal ini.';
      }
    });
  }

  Future<void> _searchApprovers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _approverResults = []);
      return;
    }
    setState(() => _searchingApprovers = true);
    final results = await _service.searchApprovers(search: query);
    if (!mounted) return;
    final selectedIds = _approvers.map((a) => a['id']).toSet();
    setState(() {
      _approverResults =
          results.where((r) => !selectedIds.contains(r['id'])).toList();
      _searchingApprovers = false;
    });
  }

  void _addApprover(Map<String, dynamic> user) {
    if (_approvers.any((a) => a['id'] == user['id'])) return;
    setState(() {
      _approvers.add(user);
      _approverResults = [];
      _approverSearchController.clear();
    });
  }

  void _moveApprover(int from, int to) {
    if (to < 0 || to >= _approvers.length) return;
    setState(() {
      final item = _approvers.removeAt(from);
      _approvers.insert(to, item);
    });
  }

  void _addTask() {
    if (_tasks.length >= 10) return;
    setState(() => _tasks.add(_WfhTaskRow()));
  }

  void _removeTask(int index) {
    if (_tasks.length <= 1) return;
    setState(() {
      _tasks.removeAt(index).dispose();
    });
  }

  String _formatTime(dynamic value) {
    if (value == null) return '-';
    final s = value.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Future<void> _save() async {
    if (_saving || !_canSubmit) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _toast('Alasan WFH wajib diisi', isError: true);
      return;
    }
    if (!_hasValidTask) {
      _toast('Isi minimal 1 pekerjaan', isError: true);
      return;
    }
    if (_approvers.isEmpty) {
      _toast('Pilih minimal 1 approver', isError: true);
      return;
    }
    if (_shiftInfo == null) {
      _toast('Shift belum valid untuk tanggal ini', isError: true);
      return;
    }

    setState(() => _saving = true);

    final tasks = _tasks
        .map((t) => t.controller.text.trim())
        .where((d) => d.isNotEmpty)
        .map((d) => {'description': d})
        .toList();

    final res = await _service.store(
      wfhDate: DateFormat('yyyy-MM-dd').format(_wfhDate),
      reason: reason,
      tasks: tasks,
      approvers: _approvers.map((a) => int.parse(a['id'].toString())).toList(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      _toast(res['message']?.toString() ?? 'Berhasil disimpan');
      Navigator.pop(context, true);
    } else {
      _toast(res['message']?.toString() ?? 'Gagal menyimpan', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text(
          'Buat Pengajuan WFH',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingMeta
          ? const Center(child: AppLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _section(
                  title: 'Data Karyawan',
                  child: Column(
                    children: [
                      _infoRow('Nama', _employee?['nama_lengkap']?.toString() ?? '-'),
                      _infoRow('Jabatan', _employee?['jabatan']?.toString() ?? '-'),
                      _infoRow('Divisi', _employee?['divisi']?.toString() ?? '-'),
                      const SizedBox(height: 12),
                      _dateField('Tanggal WFH *', _wfhDate, _pickWfhDate),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: _inputDecoration('Alasan WFH *'),
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_checkingShift) ...[
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Memeriksa shift...',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                      ] else if (_shiftInfo != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shift ditemukan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_shiftInfo!['shift_name'] ?? '-'} · '
                                '${_formatTime(_shiftInfo!['time_start'])} – '
                                '${_formatTime(_shiftInfo!['time_end'])}'
                                '${_shiftInfo!['outlet_name'] != null ? ' · ${_shiftInfo!['outlet_name']}' : ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF134E4A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Setelah fully approved, jam ini yang akan dicatat ke absensi.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_shiftError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            _shiftError!,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'List yang dikerjakan *',
                  trailing: TextButton.icon(
                    onPressed: _tasks.length >= 10 ? null : _addTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                    style: TextButton.styleFrom(foregroundColor: _teal),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _tasks.length; i++) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: SizedBox(
                                width: 28,
                                child: Text(
                                  '${i + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _tasks[i].controller,
                                decoration: _inputDecoration('Pekerjaan ${i + 1}'),
                                maxLength: 500,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (_tasks.length > 1)
                              IconButton(
                                onPressed: () => _removeTask(i),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade600,
                                ),
                              ),
                          ],
                        ),
                        if (i < _tasks.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Approval Flow *',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Urutkan dari level terendah ke tertinggi. Wajib minimal 1 approver.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _approverSearchController,
                        decoration: _inputDecoration('Cari nama / jabatan approver...')
                            .copyWith(
                          prefixIcon: const Icon(Icons.person_search),
                          suffixIcon: _searchingApprovers
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: _searchApprovers,
                      ),
                      if (_approverResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _approverResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = _approverResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(user['nama_lengkap']?.toString() ?? '-'),
                                subtitle: Text(
                                  user['jabatan_name']?.toString() ??
                                      user['email']?.toString() ??
                                      '',
                                ),
                                onTap: () => _addApprover(user),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_approvers.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Text(
                            'Belum ada approver. Tambahkan minimal 1 orang.',
                            style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
                          ),
                        )
                      else
                        ..._approvers.asMap().entries.map((entry) {
                          final i = entry.key;
                          final a = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _teal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'L${i + 1}',
                                    style: const TextStyle(
                                      color: _teal,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['nama_lengkap']?.toString() ?? '-',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        a['jabatan_name']?.toString() ??
                                            a['email']?.toString() ??
                                            '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: i == 0 ? null : () => _moveApprover(i, i - 1),
                                  icon: const Icon(Icons.arrow_upward, size: 18),
                                ),
                                IconButton(
                                  onPressed: i == _approvers.length - 1
                                      ? null
                                      : () => _moveApprover(i, i + 1),
                                  icon: const Icon(Icons.arrow_downward, size: 18),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _approvers.removeAt(i)),
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canSubmit ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_saving ? 'Menyimpan...' : 'Ajukan WFH'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Row(
          children: [
            Expanded(
              child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(value)),
            ),
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
    );
  }
}

class _WfhTaskRow {
  final TextEditingController controller = TextEditingController();

  void dispose() => controller.dispose();
}
