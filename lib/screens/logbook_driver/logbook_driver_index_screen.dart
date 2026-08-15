import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/logbook_driver_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'logbook_driver_form_screen.dart';
import 'logbook_driver_show_screen.dart';

class LogbookDriverIndexScreen extends StatefulWidget {
  const LogbookDriverIndexScreen({super.key});

  @override
  State<LogbookDriverIndexScreen> createState() => _LogbookDriverIndexScreenState();
}

class _LogbookDriverIndexScreenState extends State<LogbookDriverIndexScreen> {
  static const Color _primary = Color(0xFF0891B2);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);

  final _service = LogbookDriverService();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _outlets = [];
  int? _filterOutletId;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  String _displayDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (s.length >= 10) {
      try {
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(s.substring(0, 10)));
      } catch (_) {}
    }
    return s;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await _service.fetchIndex(
      search: _searchCtrl.text.trim(),
      outletId: _filterOutletId?.toString(),
      dateFrom: _fmtDate(_filterDateFrom),
      dateTo: _fmtDate(_filterDateTo),
    );
    if (!mounted) return;
    if (data['success'] != true) {
      setState(() {
        _loading = false;
        _error = data['message']?.toString() ?? 'Gagal memuat data.';
        _rows = [];
      });
      return;
    }
    final paginated = data['data'];
    List list = [];
    if (paginated is Map && paginated['data'] is List) {
      list = paginated['data'] as List;
    } else if (paginated is List) {
      list = paginated;
    }
    final outletsRaw = data['outlets'];
    setState(() {
      _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _outlets = (outletsRaw is List)
          ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      _loading = false;
      _error = null;
    });
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final initial = from ? (_filterDateFrom ?? now) : (_filterDateTo ?? now);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (d == null) return;
    setState(() {
      if (from) {
        _filterDateFrom = d;
      } else {
        _filterDateTo = d;
      }
    });
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus logbook?'),
        content: Text('Hapus ${row['number'] ?? 'logbook'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _service.delete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['success'] == true
            ? 'Logbook dihapus.'
            : (res['message']?.toString() ?? 'Gagal menghapus')),
        backgroundColor: res['success'] == true ? null : const Color(0xFFDC2626),
      ),
    );
    if (res['success'] == true) _load();
  }

  Future<void> _openForm({int? id}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LogbookDriverFormScreen(recordId: id)),
    );
    if (changed == true && mounted) _load();
  }

  void _openShow(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LogbookDriverShowScreen(recordId: id)),
    ).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Logbook Driver',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor / outlet / driver',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _filterOutletId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Outlet',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Semua')),
                          ..._outlets.map((o) {
                            final id = int.tryParse('${o['id_outlet']}');
                            return DropdownMenuItem<int?>(
                              value: id,
                              child: Text(o['nama_outlet']?.toString() ?? '-', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _filterOutletId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                      onPressed: _load,
                      child: const Text('Filter'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterDateFrom == null
                            ? 'Dari'
                            : DateFormat('dd/MM/yy').format(_filterDateFrom!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterDateTo == null
                            ? 'Sampai'
                            : DateFormat('dd/MM/yy').format(_filterDateTo!)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reset filter',
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _filterOutletId = null;
                          _filterDateFrom = null;
                          _filterDateTo = null;
                        });
                        _load();
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _slate600)),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                            ],
                          ),
                        ),
                      )
                    : _rows.isEmpty
                        ? const Center(child: Text('Belum ada logbook.', style: TextStyle(color: _slate500)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final row = _rows[i];
                                final id = int.tryParse('${row['id']}');
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  elevation: 0.5,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: id == null ? null : () => _openShow(id),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  row['number']?.toString() ?? '-',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: _primary,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _displayDate(row['log_date']),
                                                style: const TextStyle(color: _slate500, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(row['outlet_name']?.toString() ?? '-',
                                              style: const TextStyle(color: _slate900, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${row['driver_name'] ?? '-'} · ${row['items_count'] ?? 0} log',
                                            style: const TextStyle(color: _slate600, fontSize: 13),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton.icon(
                                                onPressed: id == null ? null : () => _openForm(id: id),
                                                icon: const Icon(Icons.edit, size: 16),
                                                label: const Text('Edit'),
                                              ),
                                              TextButton.icon(
                                                onPressed: () => _confirmDelete(row),
                                                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                                icon: const Icon(Icons.delete_outline, size: 16),
                                                label: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Buat Logbook'),
      ),
    );
  }
}
