import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/overtime_submission_service.dart';
import '../../widgets/app_loading_indicator.dart';

class OvertimeSubmissionFormScreen extends StatefulWidget {
  const OvertimeSubmissionFormScreen({super.key});

  @override
  State<OvertimeSubmissionFormScreen> createState() => _OvertimeSubmissionFormScreenState();
}

class _OvertimeSubmissionFormScreenState extends State<OvertimeSubmissionFormScreen> {
  static const Color _indigo = Color(0xFF4F46E5);

  final _service = OvertimeSubmissionService();
  final _notesController = TextEditingController();
  final _approverSearchController = TextEditingController();

  bool _loadingMeta = true;
  bool _saving = false;
  DateTime _submissionDate = DateTime.now();
  int? _selectedOutletId;
  List<Map<String, dynamic>> _outlets = [];

  final List<_OtItemRow> _items = [];
  final List<Map<String, dynamic>> _approvers = [];
  List<Map<String, dynamic>> _approverResults = [];
  bool _searchingApprovers = false;

  @override
  void initState() {
    super.initState();
    _items.add(_OtItemRow(overtimeDate: DateTime.now()));
    _loadMeta();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _approverSearchController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    final meta = await _service.getCreateMeta();
    if (!mounted) return;
    if (meta != null && meta['success'] == true) {
      final outs = meta['outlets'];
      if (outs is List) {
        _outlets = outs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final today = meta['today']?.toString();
      if (today != null) {
        try {
          _submissionDate = DateTime.parse(today);
        } catch (_) {}
      }
    }
    setState(() => _loadingMeta = false);
  }

  Future<void> _pickSubmissionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _submissionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _submissionDate = picked);
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
      _approverResults = results.where((r) => !selectedIds.contains(r['id'])).toList();
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

  Future<void> _save() async {
    if (_saving) return;

    for (final item in _items) {
      if (item.userId == null) {
        _toast('Pilih karyawan di semua baris', isError: true);
        return;
      }
      if (item.hours < 1 || item.hours > 24) {
        _toast('Jam pengajuan harus 1–24 (angka bulat)', isError: true);
        return;
      }
    }
    if (_approvers.isEmpty) {
      _toast('Pilih minimal 1 approver', isError: true);
      return;
    }

    setState(() => _saving = true);
    final payloadItems = _items
        .map((item) => {
              'user_id': item.userId,
              'overtime_date': DateFormat('yyyy-MM-dd').format(item.overtimeDate),
              'requested_hours': item.hours,
              if (item.notesController.text.trim().isNotEmpty) 'notes': item.notesController.text.trim(),
            })
        .toList();

    final res = await _service.store(
      submissionDate: DateFormat('yyyy-MM-dd').format(_submissionDate),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: payloadItems,
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
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: const Text('Buat Pengajuan Lembur', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loadingMeta
          ? const Center(child: AppLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _section(
                  title: 'Informasi Pengajuan',
                  child: Column(
                    children: [
                      _dateField('Tanggal Pengajuan', _submissionDate, _pickSubmissionDate),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: _selectedOutletId,
                        decoration: _inputDecoration('Filter Outlet (opsional)'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Semua Outlet')),
                          ..._outlets.map((o) {
                            final id = int.tryParse('${o['id_outlet']}');
                            return DropdownMenuItem<int?>(
                              value: id,
                              child: Text('${o['nama_outlet'] ?? '-'}'),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _selectedOutletId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: _inputDecoration('Catatan'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Daftar Karyawan Lembur',
                  trailing: TextButton.icon(
                    onPressed: () => setState(() => _items.add(_OtItemRow(overtimeDate: DateTime.now()))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        _buildItemCard(i),
                        if (i < _items.length - 1) const SizedBox(height: 10),
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
                        decoration: _inputDecoration('Cari nama / jabatan approver...').copyWith(
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
                                subtitle: Text(user['jabatan_name']?.toString() ?? user['email']?.toString() ?? ''),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _indigo.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'L${i + 1}',
                                    style: const TextStyle(color: _indigo, fontWeight: FontWeight.w800, fontSize: 12),
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
                                        a['jabatan_name']?.toString() ?? a['email']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: i == 0 ? null : () => _moveApprover(i, i - 1),
                                  icon: const Icon(Icons.arrow_upward, size: 18),
                                ),
                                IconButton(
                                  onPressed: i == _approvers.length - 1 ? null : () => _moveApprover(i, i + 1),
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
                  onPressed: _saving || _approvers.isEmpty || _items.isEmpty ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _indigo, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Baris ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: _indigo)),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _items.removeAt(index).dispose();
                    });
                  },
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                ),
            ],
          ),
          _EmployeeSearchField(
            selectedLabel: item.userLabel,
            outletId: _selectedOutletId,
            service: _service,
            onSelected: (user) {
              setState(() {
                item.userId = int.tryParse('${user['id']}');
                item.userLabel = user['name']?.toString() ??
                    user['nama_lengkap']?.toString() ??
                    'User #${user['id']}';
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  'Tanggal Lembur',
                  item.overtimeDate,
                  () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: item.overtimeDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => item.overtimeDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: '${item.hours}',
                  decoration: _inputDecoration('Jam *'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => item.hours = int.tryParse(v) ?? item.hours,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.notesController,
            decoration: _inputDecoration('Catatan baris (opsional)'),
          ),
        ],
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
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
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

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Row(
          children: [
            Expanded(child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(value))),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}

class _OtItemRow {
  int? userId;
  String? userLabel;
  DateTime overtimeDate;
  int hours;
  final TextEditingController notesController = TextEditingController();

  _OtItemRow({required this.overtimeDate, this.hours = 1});

  void dispose() => notesController.dispose();
}

class _EmployeeSearchField extends StatefulWidget {
  final String? selectedLabel;
  final int? outletId;
  final OvertimeSubmissionService service;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _EmployeeSearchField({
    required this.selectedLabel,
    required this.outletId,
    required this.service,
    required this.onSelected,
  });

  @override
  State<_EmployeeSearchField> createState() => _EmployeeSearchFieldState();
}

class _EmployeeSearchFieldState extends State<_EmployeeSearchField> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final users = await widget.service.searchUsers(search: q, outletId: widget.outletId);
    if (!mounted) return;
    setState(() {
      _results = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Nama Karyawan *',
            hintText: widget.selectedLabel ?? 'Cari nama / NIK / jabatan...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: (v) {
            if (v.trim().length >= 2 || v.trim().isEmpty) _search(v.trim());
          },
          onTap: () {
            if (_results.isEmpty) _search(_controller.text.trim());
          },
        ),
        if (widget.selectedLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Terpilih: ${widget.selectedLabel}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
            ),
          ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _results[index];
                final name = user['name']?.toString() ?? user['nama_lengkap']?.toString() ?? '-';
                final jabatan = user['jabatan']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  title: Text(name),
                  subtitle: Text(jabatan),
                  onTap: () {
                    widget.onSelected(user);
                    setState(() {
                      _results = [];
                      _controller.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
