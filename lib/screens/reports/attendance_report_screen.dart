import 'package:flutter/material.dart';
import '../../services/attendance_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final AttendanceService _service = AttendanceService();

  List<dynamic> _data = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _divisions = [];
  Map<String, dynamic> _summary = {'total_telat': 0, 'total_lembur': 0};
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  String? _outletId;
  String? _divisionId;
  /// Nama lengkap karyawan terpilih (dikirim sebagai param search ke API)
  String? _selectedEmployeeName;
  int? _bulan;
  int? _tahun;
  bool _filterExpanded = true;

  static final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _bulan = now.month;
    _tahun = now.year;
    _loadFilters();
  }

  /// Load outlet & divisi untuk dropdown (tanpa load data report).
  Future<void> _loadFilters() async {
    try {
      final result = await _service.getAttendanceReportFilters();
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _outlets = _parseListMap(result['outlets']);
          _divisions = _parseListMap(result['divisions']);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    final hasFilter = _outletId != null && _outletId!.isNotEmpty ||
        _divisionId != null && _divisionId!.isNotEmpty ||
        (_selectedEmployeeName != null && _selectedEmployeeName!.trim().isNotEmpty) ||
        _bulan != null ||
        _tahun != null;

    if (!hasFilter) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih minimal satu filter (Outlet, Divisi, Nama, Bulan, atau Tahun)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getAttendanceReport(
        outletId: _outletId,
        divisionId: _divisionId,
        search: _selectedEmployeeName != null && _selectedEmployeeName!.trim().isNotEmpty ? _selectedEmployeeName!.trim() : null,
        bulan: _bulan,
        tahun: _tahun,
      );

      if (!mounted) return;
      if (result != null) {
        setState(() {
          _data = result['data'] is List ? List.from(result['data']) : [];
          _outlets = _parseListMap(result['outlets']);
          _divisions = _parseListMap(result['divisions']);
          final sum = result['summary'];
          if (sum is Map) {
            _summary = {
              'total_telat': sum['total_telat'] ?? 0,
              'total_lembur': sum['total_lembur'] ?? 0,
            };
          }
          _hasSearched = true;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseListMap(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    return list.map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{}).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Report Attendance',
      body: Column(
        children: [
          _buildFilters(),
          if (_errorMessage != null) _buildError(),
          if (_hasSearched && _summary['total_telat'] != null && _summary['total_lembur'] != null) _buildSummary(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator())
                : _hasSearched
                    ? _buildList()
                    : _buildEmptyHint(),
          ),
        ],
      ),
    );
  }

  void _openEmployeePicker() {
    final future = _service.getAttendanceReportEmployees(
      outletId: _outletId,
      divisionId: _divisionId,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _EmployeePickerSheet(
        employeesFuture: future,
        selectedName: _selectedEmployeeName,
        onSelect: (name) {
          setState(() => _selectedEmployeeName = name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ExpansionTile(
        initiallyExpanded: _filterExpanded,
        title: const Text('Filter', style: TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Outlet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _outletId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Semua Outlet'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Outlet')),
                    ..._outlets.map((e) {
                      final id = e['id']?.toString();
                      final name = e['name']?.toString() ?? id ?? '';
                      return DropdownMenuItem(
                        value: id,
                        child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _outletId = v),
                ),
                const SizedBox(height: 12),
                const Text('Divisi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _divisionId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Semua Divisi'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Divisi')),
                    ..._divisions.map((e) {
                      final id = e['id']?.toString();
                      final name = e['name']?.toString() ?? id ?? '';
                      return DropdownMenuItem(
                        value: id,
                        child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _divisionId = v),
                ),
                const SizedBox(height: 12),
                const Text('Nama Karyawan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _openEmployeePicker,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Pilih atau cari karyawan...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _selectedEmployeeName ?? 'Pilih atau cari karyawan...',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedEmployeeName != null ? null : Theme.of(context).hintColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                if (_selectedEmployeeName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _selectedEmployeeName = null),
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Hapus pilihan'),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _bulan,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Bulan'),
                        items: List.generate(12, (i) => i + 1).map((m) {
                          return DropdownMenuItem(value: m, child: Text(_monthNames[m - 1]));
                        }).toList(),
                        onChanged: (v) => setState(() => _bulan = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _tahun,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Tahun'),
                        items: List.generate(5, (i) => DateTime.now().year - i).map((y) {
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }).toList(),
                        onChanged: (v) => setState(() => _tahun = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _loadReport,
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text('Tampilkan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final telat = _summary['total_telat'] is int
        ? _summary['total_telat'] as int
        : (_summary['total_telat'] is num ? (_summary['total_telat'] as num).toInt() : 0);
    final lembur = _summary['total_lembur'] is num
        ? (_summary['total_lembur'] as num).floor()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Telat', style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                    Text('$telat menit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Lembur', style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                    Text('$lembur jam', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Pilih filter lalu tap "Tampilkan" untuk melihat report.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_data.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data untuk filter yang dipilih.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _data.length,
      itemBuilder: (context, index) {
        final row = _data[index];
        final map = row is Map ? Map<String, dynamic>.from(row as Map) : <String, dynamic>{};
        return _buildRowCard(map, index);
      },
    );
  }

  Widget _buildRowCard(Map<String, dynamic> row, int index) {
    final tanggal = row['tanggal']?.toString() ?? '-';
    final nama = row['nama_lengkap']?.toString() ?? '-';
    final jabatan = row['jabatan']?.toString() ?? '-';
    final jamMasuk = row['jam_masuk']?.toString();
    final jamKeluar = row['jam_keluar']?.toString();
    final telat = row['telat'];
    final totalLembur = row['total_lembur'];
    final isOff = row['is_off'] == true;
    final isHoliday = row['is_holiday'] == true;
    final holidayName = row['holiday_name']?.toString();
    final isApprovedAbsent = row['is_approved_absent'] == true;
    final approvedAbsentName = row['approved_absent_name']?.toString();
    final hasNoCheckout = row['has_no_checkout'] == true;

    String jamMasukStr = '-';
    if (jamMasuk != null && jamMasuk.isNotEmpty) {
      jamMasukStr = jamMasuk.length > 8 ? jamMasuk.substring(0, 8) : jamMasuk;
    } else if (isOff) {
      jamMasukStr = 'OFF';
    } else if (isApprovedAbsent && approvedAbsentName != null) {
      jamMasukStr = approvedAbsentName;
    }

    String jamKeluarStr = '-';
    if (jamKeluar != null && jamKeluar.isNotEmpty) {
      jamKeluarStr = jamKeluar.length > 8 ? jamKeluar.substring(0, 8) : jamKeluar;
    } else if (isOff) {
      jamKeluarStr = 'OFF';
    } else if (isApprovedAbsent && approvedAbsentName != null) {
      jamKeluarStr = approvedAbsentName;
    } else if (hasNoCheckout) {
      jamKeluarStr = 'TIDAK CHECKOUT';
    }

    final telatInt = telat is int ? telat : (telat is num ? telat.toInt() : 0);
    final lemburNum = totalLembur is num ? totalLembur : (row['lembur'] is num ? row['lembur'] : 0);
    final lemburStr = lemburNum is int ? '$lemburNum' : (lemburNum is double ? lemburNum.toStringAsFixed(1) : '0');

    Color bgColor = index.isEven ? Colors.blue.shade50 : Colors.white;
    if (isHoliday) bgColor = Colors.red.shade50;
    if (isApprovedAbsent) bgColor = Colors.green.shade50;
    if (isOff) bgColor = Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tanggal,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (holidayName != null && holidayName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Chip(
                            label: Text(holidayName, style: const TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red.shade100,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (hasNoCheckout)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Chip(
                            label: const Text('TIDAK CHECKOUT', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red.shade200,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (jabatan.isNotEmpty && jabatan != '-')
                        Text(
                          jabatan,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _pairLabel('Masuk', jamMasukStr),
                _pairLabel('Keluar', jamKeluarStr),
                _pairLabel('Telat', '$telatInt m'),
                _pairLabel('Lembur', '${lemburStr} j'),
              ],
            ),
            if (!isOff) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openDetailSheet(row, nama),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Detail'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _openShiftSheet(row, nama),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Shift'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetailSheet(Map<String, dynamic> row, String nama) {
    final userId = row['user_id'];
    final tanggal = row['tanggal']?.toString() ?? '';
    if (userId == null || tanggal.isEmpty) return;
    final id = userId is int ? userId : (userId is num ? userId.toInt() : null);
    if (id == null) return;
    final future = _service.getAttendanceReportDetail(userId: id, tanggal: tanggal);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _DetailSheet(
          title: 'Detail Absensi',
          subtitle: '$nama | $tanggal',
          detailFuture: future,
          scrollController: scrollController,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _openShiftSheet(Map<String, dynamic> row, String nama) {
    final userId = row['user_id'];
    final tanggal = row['tanggal']?.toString() ?? '';
    if (userId == null || tanggal.isEmpty) return;
    final id = userId is int ? userId : (userId is num ? userId.toInt() : null);
    if (id == null) return;
    final future = _service.getAttendanceReportShiftInfo(userId: id, tanggal: tanggal);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ShiftSheet(
        title: 'Info Shift',
        subtitle: '$nama | $tanggal',
        shiftFuture: future,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  Widget _pairLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmployeePickerSheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> employeesFuture;
  final String? selectedName;
  final ValueChanged<String?> onSelect;

  const _EmployeePickerSheet({
    required this.employeesFuture,
    required this.selectedName,
    required this.onSelect,
  });

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> employees) {
    if (_query.trim().isEmpty) return employees;
    final q = _query.trim().toLowerCase();
    return employees.where((e) {
      final name = (e['name'] as String? ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari nama karyawan...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            ListTile(
              title: const Text('Semua Karyawan'),
              leading: const Icon(Icons.person_off),
              onTap: () => widget.onSelect(null),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.employeesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'Gagal memuat daftar karyawan',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final employees = snapshot.data ?? [];
                  final filtered = _filter(employees);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        employees.isEmpty
                            ? 'Tidak ada karyawan'
                            : 'Tidak ada hasil untuk "$_query"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final e = filtered[index];
                      final name = e['name']?.toString() ?? '';
                      final id = e['id']?.toString();
                      return ListTile(
                        title: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: id != null ? Text('ID: $id') : null,
                        selected: widget.selectedName == name,
                        onTap: () => widget.onSelect(name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<List<Map<String, dynamic>>> detailFuture;
  final ScrollController scrollController;
  final VoidCallback onClose;

  const _DetailSheet({
    required this.title,
    required this.subtitle,
    required this.detailFuture,
    required this.scrollController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.list_alt, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Gagal memuat: ${snapshot.error}'));
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(child: Text('Tidak ada data'));
              }
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final d = rows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['nama_outlet']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _detailRow('Jam In', d['jam_in']?.toString() ?? '-'),
                          _detailRow('Jam Out', d['jam_out']?.toString() ?? '-'),
                          _detailRow('Total IN', (d['total_in'] ?? '-').toString()),
                          _detailRow('Total OUT', (d['total_out'] ?? '-').toString()),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ShiftSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<Map<String, dynamic>?> shiftFuture;
  final VoidCallback onClose;

  const _ShiftSheet({
    required this.title,
    required this.subtitle,
    required this.shiftFuture,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>?>(
            future: shiftFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final info = snapshot.data;
              final name = info?['shift_name']?.toString();
              final start = info?['time_start']?.toString();
              final end = info?['time_end']?.toString();
              if (name == null || name.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Tidak ada data shift untuk hari ini.', style: TextStyle(color: Colors.grey.shade600)),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shiftRow('Shift', name),
                  _shiftRow('Jam Masuk', start ?? '-'),
                  _shiftRow('Jam Keluar', end ?? '-'),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClose,
              child: const Text('Tutup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
