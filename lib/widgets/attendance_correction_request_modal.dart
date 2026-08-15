import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import 'app_loading_indicator.dart';

class AttendanceCorrectionRequestModal extends StatefulWidget {
  final String tanggal;
  final VoidCallback onSubmitted;

  const AttendanceCorrectionRequestModal({
    super.key,
    required this.tanggal,
    required this.onSubmitted,
  });

  @override
  State<AttendanceCorrectionRequestModal> createState() =>
      _AttendanceCorrectionRequestModalState();
}

class _AttendanceCorrectionRequestModalState
    extends State<AttendanceCorrectionRequestModal> {
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _approverSearchController = TextEditingController();
  Timer? _approverSearchDebounce;

  bool _loadingForm = true;
  bool _submitting = false;
  bool _loadingApprovers = false;
  Map<String, dynamic> _form = {};
  String _type = 'schedule';
  int? _shiftId;
  Map<String, dynamic>? _selectedScan;
  DateTime? _newScanDate;
  int _inoutmode = 1;
  List<int> _selectedApprovers = [];
  List<Map<String, dynamic>> _availableApprovers = [];

  @override
  void initState() {
    super.initState();
    _loadForm();
    _loadApprovers();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _approverSearchController.dispose();
    _approverSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadForm() async {
    final data = await _attendanceService.getCorrectionForm(tanggal: widget.tanggal);
    if (!mounted) return;
    if (data['success'] != true || data['can_correct'] != true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message']?.toString() ??
              'Koreksi hanya dapat diajukan dalam 2×24 jam'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _form = data;
      _loadingForm = false;
      final schedule = data['schedule'];
      if (schedule is Map && schedule['shift_id'] != null) {
        _shiftId = int.tryParse(schedule['shift_id'].toString());
      }
      final shifts = (data['shifts'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['shifts'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : <Map<String, dynamic>>[];
      if (_shiftId != null && !shifts.any((s) => (s['id'] as num).toInt() == _shiftId)) {
        _shiftId = null;
      }
      _newScanDate = DateTime.parse('${widget.tanggal} 08:00:00');
    });
  }

  Future<void> _loadApprovers() async {
    setState(() => _loadingApprovers = true);
    final q = _approverSearchController.text.trim();
    final users = await _attendanceService.getApprovers(search: q.isEmpty ? null : q);
    if (!mounted) return;
    setState(() {
      _availableApprovers = users;
      _loadingApprovers = false;
    });
  }

  Future<void> _pickDateTime() async {
    final initial = _newScanDate ?? DateTime.parse('${widget.tanggal} 08:00:00');
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.parse(widget.tanggal),
      lastDate: DateTime.parse(widget.tanggal).add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _newScanDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatScanDate(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan / alasan wajib diisi'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedApprovers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 atasan'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_type == 'manual_attendance') {
      final remaining = int.tryParse('${_form['manual_remaining'] ?? 0}') ?? 0;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batas maksimal 5x No fingerprint in/out correction dalam periode ini sudah tercapai.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final result = await _attendanceService.submitCorrectionRequest(
        type: _type,
        tanggal: widget.tanggal,
        reason: reason,
        approvers: _selectedApprovers,
        shiftId: _type == 'schedule' ? _shiftId : null,
        sn: _type == 'attendance' ? (_selectedScan?['sn'] ?? _form['sn'])?.toString() : null,
        pin: _type == 'attendance' ? (_selectedScan?['pin'] ?? _form['pin'])?.toString() : null,
        oldScanDate: _type == 'attendance'
            ? (_selectedScan?['scan_date']?.toString())
            : null,
        scanDate: (_type == 'attendance' || _type == 'manual_attendance') && _newScanDate != null
            ? _formatScanDate(_newScanDate!)
            : null,
        inoutmode: (_type == 'attendance' || _type == 'manual_attendance') ? _inoutmode : null,
        outletId: _form['outlet_id'] is num ? (_form['outlet_id'] as num).toInt() : null,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Pengajuan koreksi terkirim'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Gagal mengirim pengajuan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shifts = (_form['shifts'] is List)
        ? List<Map<String, dynamic>>.from(
            (_form['shifts'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
    final scans = (_form['scans'] is List)
        ? List<Map<String, dynamic>>.from(
            (_form['scans'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: _loadingForm
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: AppLoadingIndicator()),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ajukan Koreksi · ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(widget.tanggal))}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  if (_form['remaining_hours'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sisa waktu pengajuan: ${num.tryParse('${_form['remaining_hours']}')?.round() ?? 0} jam (maks. 2×24 jam).',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Jenis Koreksi *'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _type,
                          items: const [
                            DropdownMenuItem(value: 'schedule', child: Text('Working schedule correction')),
                            DropdownMenuItem(value: 'attendance', child: Text('Working time correction')),
                            DropdownMenuItem(value: 'manual_attendance', child: Text('No fingerprint in/out correction')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'schedule'),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        if (_type == 'schedule') ...[
                          Text('Saat ini: ${_form['schedule']?['shift_name'] ?? 'OFF'}'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int?>(
                            value: _shiftId,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('OFF')),
                              ...shifts.map((s) {
                                final id = (s['id'] as num).toInt();
                                return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text('${s['shift_name']} (${s['time_start']} - ${s['time_end']})'),
                                );
                              }),
                            ],
                            onChanged: (v) => setState(() => _shiftId = v),
                            decoration: const InputDecoration(
                              labelText: 'Shift baru',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else if (_type == 'attendance') ...[
                          if (scans.isEmpty)
                            const Text(
                              'Tidak ada scan absensi pada tanggal ini. Gunakan No fingerprint in/out correction.',
                              style: TextStyle(color: Colors.red),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: _selectedScan?['scan_date']?.toString(),
                              items: scans
                                  .map((s) => DropdownMenuItem(
                                        value: s['scan_date'].toString(),
                                        child: Text('${s['inoutmode_label']} · ${s['scan_date']}'),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                final scan = scans.firstWhere((s) => s['scan_date'].toString() == v);
                                setState(() {
                                  _selectedScan = scan;
                                  _inoutmode = int.tryParse('${scan['inoutmode']}') ?? 1;
                                  _newScanDate = DateTime.tryParse(scan['scan_date'].toString());
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Pilih scan',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Waktu baru'),
                              subtitle: Text(_newScanDate == null
                                  ? 'Pilih waktu'
                                  : DateFormat('dd/MM/yyyy HH:mm').format(_newScanDate!)),
                              trailing: const Icon(Icons.access_time),
                              onTap: _pickDateTime,
                            ),
                            DropdownButtonFormField<int>(
                              value: _inoutmode,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('IN')),
                                DropdownMenuItem(value: 2, child: Text('OUT')),
                                DropdownMenuItem(value: 4, child: Text('KEMBALI')),
                              ],
                              onChanged: (v) => setState(() => _inoutmode = v ?? 1),
                              decoration: const InputDecoration(
                                labelText: 'Mode',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ] else ...[
                          Builder(builder: (context) {
                            final remaining = int.tryParse('${_form['manual_remaining'] ?? 0}') ?? 0;
                            final used = int.tryParse('${_form['manual_used'] ?? (5 - remaining)}') ?? 0;
                            final limit = int.tryParse('${_form['manual_limit'] ?? 5}') ?? 5;
                            final period = _form['period'] is Map ? Map<String, dynamic>.from(_form['period'] as Map) : {};
                            final ok = remaining > 0;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: ok ? Colors.blue.shade50 : Colors.red.shade50,
                                border: Border.all(color: ok ? Colors.blue.shade200 : Colors.red.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Limit No fingerprint in/out correction',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: ok ? Colors.blue.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Periode: ${period['start_formatted'] ?? '-'} - ${period['end_formatted'] ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ok ? Colors.blue.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Digunakan: $used/$limit  •  Sisa: $remaining',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: ok ? Colors.blue.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Waktu absen'),
                            subtitle: Text(_newScanDate == null
                                ? 'Pilih waktu'
                                : DateFormat('dd/MM/yyyy HH:mm').format(_newScanDate!)),
                            trailing: const Icon(Icons.access_time),
                            onTap: _pickDateTime,
                          ),
                          DropdownButtonFormField<int>(
                            value: _inoutmode,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('IN')),
                              DropdownMenuItem(value: 2, child: Text('OUT')),
                              DropdownMenuItem(value: 4, child: Text('KEMBALI')),
                            ],
                            onChanged: (v) => setState(() => _inoutmode = v ?? 1),
                            decoration: const InputDecoration(
                              labelText: 'Mode',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Catatan / Alasan *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Pilih Atasan *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _approverSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Cari atasan berdasarkan nama, email, atau jabatan...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) {
                            _approverSearchDebounce?.cancel();
                            _approverSearchDebounce = Timer(const Duration(milliseconds: 400), _loadApprovers);
                          },
                        ),
                        if (_loadingApprovers)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(child: AppLoadingIndicator()),
                          )
                        else
                          ..._availableApprovers.take(8).map((u) {
                            final id = (u['id'] as num).toInt();
                            final selected = _selectedApprovers.contains(id);
                            return CheckboxListTile(
                              dense: true,
                              value: selected,
                              title: Text(u['nama_lengkap']?.toString() ?? ''),
                              subtitle: Text(u['nama_jabatan']?.toString() ?? u['email']?.toString() ?? ''),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    if (!_selectedApprovers.contains(id)) _selectedApprovers.add(id);
                                  } else {
                                    _selectedApprovers.remove(id);
                                  }
                                });
                              },
                            );
                          }),
                        if (_selectedApprovers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              children: _selectedApprovers.asMap().entries.map((e) {
                                Map<String, dynamic>? user;
                                for (final u in _availableApprovers) {
                                  if ((u['id'] as num).toInt() == e.value) {
                                    user = u;
                                    break;
                                  }
                                }
                                return Chip(
                                  label: Text('L${e.key + 1} ${user?['nama_lengkap'] ?? e.value}'),
                                  onDeleted: () => setState(() => _selectedApprovers.remove(e.value)),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Setelah semua atasan approve, pengajuan otomatis masuk antrian HRD. Jangan pilih HRD hanya untuk melewati tahap atasan. Jika atasan langsung Anda dari HRD, tetap boleh dipilih.',
                          style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_submitting || (_type == 'manual_attendance' && (int.tryParse('${_form['manual_remaining'] ?? 0}') ?? 0) <= 0))
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Ajukan Koreksi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
