import 'package:flutter/material.dart';
import '../../services/schedule_attendance_correction_service.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../approvals/correction_approval_detail_screen.dart';

class ScheduleAttendanceCorrectionScreen extends StatefulWidget {
  const ScheduleAttendanceCorrectionScreen({super.key});

  @override
  State<ScheduleAttendanceCorrectionScreen> createState() => _ScheduleAttendanceCorrectionScreenState();
}

class _ScheduleAttendanceCorrectionScreenState extends State<ScheduleAttendanceCorrectionScreen>
    with SingleTickerProviderStateMixin {
  final ScheduleAttendanceCorrectionService _service = ScheduleAttendanceCorrectionService();
  final ApprovalService _approvalService = ApprovalService();

  late TabController _tabController;
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _divisions = [];
  List<dynamic> _users = [];
  List<dynamic> _shifts = [];
  List<dynamic> _scheduleData = [];
  List<dynamic> _attendanceData = [];
  Map<String, dynamic> _filters = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _outletId;
  String? _divisionId;
  String? _startDate;
  String? _endDate;
  int? _selectedUserId;
  String _correctionType = 'schedule'; // schedule | attendance | manual_attendance
  List<Map<String, dynamic>> _employees = [];
  bool _filterExpanded = true;

  // Manual form
  int? _manualUserId;
  int? _manualOutletId;
  String _manualDate = '';
  String _manualTime = '';
  int _manualInoutmode = 1;
  final TextEditingController _manualReasonController = TextEditingController();
  final TextEditingController _manualDateController = TextEditingController();
  Map<String, dynamic>? _manualLimit;
  bool _checkingLimit = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 26);
    final end = DateTime(now.year, now.month, 25);
    _startDate = _formatDate(start);
    _endDate = _formatDate(end);
    _loadInitialFilters();
  }

  /// Load outlets & divisions only (backend will set outlet for non-HO when we send start/end).
  Future<void> _loadInitialFilters() async {
    try {
      final result = await _service.getIndexData(
        startDate: _startDate,
        endDate: _endDate,
        correctionType: 'schedule',
      );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _outlets = _parseListMap(result['outlets']);
          _divisions = _parseListMap(result['divisions']);
          final f = result['filters'];
          if (f is Map && f['outlet_id'] != null) _outletId = f['outlet_id']?.toString();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualReasonController.dispose();
    _manualDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _parseListMap(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    return list.map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{}).toList();
  }

  List<dynamic> _parseList(dynamic list) {
    if (list == null) return [];
    if (list is! List) return list;
    return List.from(list);
  }

  Future<void> _loadData() async {
    if ((_outletId == null || _outletId!.isEmpty) || _startDate == null || _endDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lengkapi Outlet, Tanggal Mulai, dan Tanggal Akhir'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasLoaded = true;
    });

    try {
      final result = await _service.getIndexData(
        outletId: _outletId,
        divisionId: _divisionId,
        startDate: _startDate,
        endDate: _endDate,
        userId: _selectedUserId,
        correctionType: _correctionType,
      );

      if (!mounted) return;
      if (result != null) {
        setState(() {
          _outlets = _parseListMap(result['outlets']);
          _divisions = _parseListMap(result['divisions']);
          _users = _parseList(result['users']);
          _shifts = _parseList(result['shifts']);
          _scheduleData = _parseList(result['scheduleData']);
          _attendanceData = _parseList(result['attendanceData']);
          _filters = result['filters'] is Map ? Map<String, dynamic>.from(result['filters'] as Map) : {};
          if (_filters['outlet_id'] != null) _outletId = _filters['outlet_id']?.toString();
          _isLoading = false;
        });
        _loadEmployees();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmployees() async {
    if (_outletId == null) return;
    try {
      final list = await _service.getEmployees(outletId: _outletId, divisionId: _divisionId);
      if (mounted) setState(() => _employees = list);
    } catch (_) {}
  }

  List<dynamic> get _filteredScheduleData {
    if (_selectedUserId == null) return _scheduleData;
    return _scheduleData.where((e) => e['user_id'] == _selectedUserId).toList();
  }

  List<dynamic> get _filteredAttendanceData {
    if (_selectedUserId == null) return _attendanceData;
    return _attendanceData.where((e) => e['user_id'] == _selectedUserId).toList();
  }

  List<Map<String, dynamic>> _getShiftsForDivision(dynamic divisionId) {
    if (_shifts.isEmpty) return [];
    return _shifts.where((s) => s['division_id'] == divisionId).map((s) => Map<String, dynamic>.from(s is Map ? s as Map : {})).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Schedule/Attendance Correction',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Koreksi'),
              Tab(text: 'Persetujuan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKoreksiTab(),
                _buildPersetujuanTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKoreksiTab() {
    return Column(
      children: [
        _buildFilters(),
        if (_isLoading) const Expanded(child: Center(child: AppLoadingIndicator())),
        if (!_isLoading && _hasLoaded) Expanded(child: _buildContent()),
        if (!_isLoading && !_hasLoaded)
          const Expanded(
            child: Center(
              child: Text('Pilih filter lalu tap Tampilkan Data', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ExpansionTile(
        initiallyExpanded: _filterExpanded,
        title: const Text('Filter Data', style: TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dropdown('Outlet', _outletId, _outlets, (v) => setState(() => _outletId = v), 'id', 'name', 'Semua Outlet', valueAsString: true),
                const SizedBox(height: 12),
                _dropdown('Divisi', _divisionId, _divisions, (v) => setState(() => _divisionId = v), 'id', 'name', 'Semua Divisi', valueAsString: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateField('Tanggal Mulai', _startDate, (v) => setState(() => _startDate = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _dateField('Tanggal Akhir', _endDate, (v) => setState(() => _endDate = v))),
                  ],
                ),
                const SizedBox(height: 12),
                _dropdown<String>(
                  'Tipe Koreksi',
                  _correctionType,
                  [
                    {'id': 'schedule', 'name': 'Schedule Correction'},
                    {'id': 'attendance', 'name': 'Attendance Correction'},
                    {'id': 'manual_attendance', 'name': 'Manual Attendance Entry'},
                  ],
                  (v) => setState(() => _correctionType = v ?? 'schedule'),
                  'id',
                  'name',
                  'Schedule',
                ),
                if (_correctionType != 'manual_attendance') ...[
                  const SizedBox(height: 12),
                  _employeeDropdown(),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _loadData,
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text('Tampilkan Data'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [valueAsString] true: use id.toString() for value (API often returns int for id).
  Widget _dropdown<T>(String label, T? value, List<Map<String, dynamic>> items, ValueChanged<T?> onChanged, String idKey, String nameKey, String hint, {bool valueAsString = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder()),
          hint: Text(hint),
          items: [
            DropdownMenuItem<T>(value: null, child: Text(hint)),
            ...items.map((e) {
              final id = e[idKey];
              final name = e[nameKey]?.toString() ?? id?.toString() ?? '';
              T? itemValue;
              if (id == null) {
                itemValue = null;
              } else if (valueAsString) {
                itemValue = id.toString() as T;
              } else {
                itemValue = (id is int ? id : (id is num ? (id as num).toInt() : id)) as T;
              }
              return DropdownMenuItem<T>(value: itemValue, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1));
            }),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dateField(String label, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder()),
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
            if (date != null) onChanged(_formatDate(date));
          },
        ),
      ],
    );
  }

  Widget _employeeDropdown() {
    final options = _employees.isEmpty ? _users.map((u) => {'id': u['id'], 'name': u['nama_lengkap']?.toString() ?? ''}).toList() : _employees;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nama Karyawan', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: _selectedUserId,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder()),
          hint: const Text('Semua Karyawan'),
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('Semua Karyawan')),
            ...options.map((e) {
              final id = e['id'];
              final name = e['name']?.toString() ?? '';
              final intId = id is int ? id : (id is num ? id.toInt() : null);
              if (intId == null) return null;
              return DropdownMenuItem<int>(value: intId, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1));
            }).whereType<DropdownMenuItem<int>>(),
          ],
          onChanged: (v) => setState(() => _selectedUserId = v),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_correctionType == 'schedule') {
      if (_filteredScheduleData.isEmpty) {
        return const Center(child: Text('Tidak ada data schedule. Ubah filter atau periode.'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredScheduleData.length,
        itemBuilder: (context, index) {
          final s = _filteredScheduleData[index];
          final map = s is Map ? Map<String, dynamic>.from(s as Map) : <String, dynamic>{};
          return _scheduleCard(map);
        },
      );
    }
    if (_correctionType == 'attendance') {
      if (_filteredAttendanceData.isEmpty) {
        return const Center(child: Text('Tidak ada data attendance. Ubah filter atau periode.'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredAttendanceData.length,
        itemBuilder: (context, index) {
          final a = _filteredAttendanceData[index];
          final map = a is Map ? Map<String, dynamic>.from(a as Map) : <String, dynamic>{};
          return _attendanceCard(map);
        },
      );
    }
    return _buildManualForm();
  }

  Widget _scheduleCard(Map<String, dynamic> s) {
    final tanggal = s['tanggal']?.toString() ?? '-';
    final nama = s['nama_lengkap']?.toString() ?? '-';
    final shiftName = s['shift_name']?.toString() ?? 'OFF';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(nama, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$tanggal · $shiftName'),
        trailing: TextButton.icon(
          onPressed: () => _openScheduleCorrectionSheet(s),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Koreksi'),
        ),
      ),
    );
  }

  Widget _attendanceCard(Map<String, dynamic> a) {
    final nama = a['nama_lengkap']?.toString() ?? '-';
    final scanDate = a['scan_date']?.toString() ?? '-';
    final inout = a['inoutmode'] == 1 ? 'IN' : 'OUT';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(nama, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$scanDate · $inout'),
        trailing: TextButton.icon(
          onPressed: () => _openAttendanceCorrectionSheet(a),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Koreksi'),
        ),
      ),
    );
  }

  void _openScheduleCorrectionSheet(Map<String, dynamic> schedule) {
    final scheduleId = schedule['id'];
    final divId = schedule['schedule_division_id'] ?? schedule['user_division_id'];
    final shifts = _getShiftsForDivision(divId);
    final currentShiftId = schedule['shift_id'];
    int? selectedShiftId = currentShiftId is int ? currentShiftId : (currentShiftId is num ? currentShiftId.toInt() : null);
    final reasonController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Koreksi Schedule', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${schedule['nama_lengkap']} · ${schedule['tanggal']}', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  const Text('Shift baru', style: TextStyle(fontWeight: FontWeight.w500)),
                  DropdownButtonFormField<int>(
                    value: selectedShiftId,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('OFF')),
                      ...shifts.map((e) {
                        final id = e['id'] is int ? e['id'] as int : (e['id'] is num ? (e['id'] as num).toInt() : null);
                        if (id == null) return null;
                        final name = '${e['shift_name']} (${e['time_start']} - ${e['time_end']})';
                        return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                      }).whereType<DropdownMenuItem<int>>(),
                    ],
                    onChanged: (v) => setModalState(() => selectedShiftId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alasan harus diisi')));
                            return;
                          }
                          final res = await _service.updateSchedule(
                            scheduleId: scheduleId is int ? scheduleId : (scheduleId as num).toInt(),
                            shiftId: selectedShiftId,
                            reason: reasonController.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          if (res['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
                            _loadData();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Kirim'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAttendanceCorrectionSheet(Map<String, dynamic> att) {
    final oldScan = att['scan_date']?.toString() ?? '';
    String newDate = oldScan.length >= 10 ? oldScan.substring(0, 10) : _formatDate(DateTime.now());
    String newTime = oldScan.length >= 16 ? oldScan.substring(11, 16) : '08:00';
    final reasonController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Koreksi Attendance', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${att['nama_lengkap']} · $oldScan', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey(newDate),
                    initialValue: newDate,
                    decoration: const InputDecoration(labelText: 'Tanggal baru', border: OutlineInputBorder()),
                    readOnly: true,
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setModalState(() => newDate = _formatDate(d));
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey(newTime),
                    initialValue: newTime,
                    decoration: const InputDecoration(labelText: 'Waktu (HH:MM)', border: OutlineInputBorder()),
                    onChanged: (v) => setModalState(() => newTime = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alasan harus diisi')));
                            return;
                          }
                          final newScanDate = '$newDate ${newTime.length == 5 ? newTime : '08:00'}:00';
                          final res = await _service.updateAttendance(
                            sn: att['sn']?.toString() ?? '',
                            pin: att['pin']?.toString() ?? '',
                            scanDate: newScanDate,
                            inoutmode: att['inoutmode'] is int ? att['inoutmode'] as int : 1,
                            oldScanDate: oldScan,
                            reason: reasonController.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          if (res['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
                            _loadData();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Kirim'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Manual Attendance Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Input absen manual untuk karyawan yang lupa absen', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          _dropdown<int>('Pilih Karyawan', _manualUserId, _employees.isEmpty ? _users.map((u) => {'id': u['id'], 'name': u['nama_lengkap']}).toList() : _employees,
              (v) => setState(() {
                _manualUserId = v;
                _manualLimit = null;
              }), 'id', 'name', 'Pilih karyawan...'),
          const SizedBox(height: 12),
          _dropdown<int>('Outlet Absen', _manualOutletId, _outlets, (v) => setState(() => _manualOutletId = v), 'id', 'name', 'Pilih outlet...'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tanggal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _manualDateController,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder()),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (date != null) {
                                setState(() {
                                  _manualDate = _formatDate(date);
                                  _manualDateController.text = _manualDate;
                                  _manualLimit = null;
                                });
                                if (_manualUserId != null && _manualDate.isNotEmpty) _checkManualLimit();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Waktu (HH:MM)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: _manualTime,
                      decoration: const InputDecoration(hintText: '09:00', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      onChanged: (v) => setState(() => _manualTime = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _manualInoutmode,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Check In')),
              DropdownMenuItem(value: 2, child: Text('Check Out')),
            ],
            onChanged: (v) => setState(() => _manualInoutmode = v ?? 1),
          ),
          if (_manualLimit != null) ...[
            const SizedBox(height: 12),
            Card(
              color: (_manualLimit!['can_submit'] == true) ? Colors.blue.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Limit: Digunakan ${_manualLimit!['used']}/5 · Sisa ${_manualLimit!['remaining']}',
                        style: TextStyle(fontWeight: FontWeight.w500, color: (_manualLimit!['can_submit'] == true) ? Colors.blue.shade800 : Colors.red.shade800)),
                    if (_manualLimit!['period'] != null)
                      Text('Periode: ${_manualLimit!['period']['start_formatted']} - ${_manualLimit!['period']['end_formatted']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _manualReasonController,
            decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _manualUserId != null && _manualOutletId != null && _manualDate.isNotEmpty && _manualTime.isNotEmpty && _manualReasonController.text.trim().isNotEmpty && (_manualLimit == null || _manualLimit!['can_submit'] == true)
                ? () async {
                    final scanDateTime = '$_manualDate ${_manualTime.length == 5 ? _manualTime : '09:00'}:00';
                    final res = await _service.submitManualAttendance(
                      userId: _manualUserId!,
                      outletId: _manualOutletId!,
                      scanDate: scanDateTime,
                      inoutmode: _manualInoutmode,
                      reason: _manualReasonController.text.trim(),
                    );
                    if (!mounted) return;
                    if (res['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
                      _manualReasonController.clear();
                      setState(() {
                        _manualUserId = null;
                        _manualOutletId = null;
                        _manualDate = '';
                        _manualTime = '';
                        _manualDateController.clear();
                        _manualLimit = null;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
                    }
                  }
                : null,
            child: const Text('Kirim Permohonan'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkManualLimit() async {
    if (_manualUserId == null || _manualDate.isEmpty) return;
    setState(() => _checkingLimit = true);
    try {
      final r = await _service.checkManualLimit(userId: _manualUserId!, scanDate: _manualDate);
      if (mounted) setState(() {
        _manualLimit = r;
        _checkingLimit = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingLimit = false);
    }
  }

  Widget _buildPersetujuanTab() {
    return FutureBuilder<List<dynamic>>(
      future: _approvalService.getPendingCorrectionApprovals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('Tidak ada persetujuan pending'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            int id;
            String type;
            String employeeName;
            String tanggalStr;
            if (item is Map) {
              id = item['id'] is int ? item['id'] as int : (item['id'] as num).toInt();
              type = item['type']?.toString() ?? '';
              employeeName = item['employee_name']?.toString() ?? 'Karyawan';
              tanggalStr = item['tanggal']?.toString() ?? '';
            } else {
              final a = item as dynamic;
              id = a.id as int;
              type = a.type?.toString() ?? '';
              employeeName = a.employeeName ?? 'Karyawan';
              tanggalStr = a.tanggal != null ? (a.tanggal is DateTime ? (a.tanggal as DateTime).toIso8601String().substring(0, 10) : a.tanggal.toString()) : '';
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(employeeName),
                subtitle: Text('$type · $tanggalStr'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CorrectionApprovalDetailScreen(correctionId: id),
                  ),
                ).then((_) => setState(() {})),
              ),
            );
          },
        );
      },
    );
  }
}
