import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/kasbon_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../purchase_requisition_detail_screen.dart';

/// Report Kasbon — UI mengikuti pola [OutletTransferIndexScreen] (modern, lembut, tanpa overflow).
class KasbonReportScreen extends StatefulWidget {
  const KasbonReportScreen({super.key});

  @override
  State<KasbonReportScreen> createState() => _KasbonReportScreenState();
}

class _KasbonReportScreenState extends State<KasbonReportScreen> {
  static const Color _accent = Color(0xFF6366F1);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final KasbonReportService _service = KasbonReportService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String? _error;

  final Set<int> _expandedKasbonIds = {};

  bool _tableMissing = false;
  List<Map<String, dynamic>> _kasbons = [];
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _summary;
  Map<String, dynamic> _pagination = {};

  String _status = 'all';
  String? _divisionId;
  String? _outletId;
  String? _dateFrom;
  String? _dateTo;
  int _perPage = 15;
  int _page = 1;

  static final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _df = DateFormat.yMMMd('id_ID');
  static final _dtf = DateFormat('d MMM y, HH:mm', 'id_ID');

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.06), blurRadius: 20, offset: Offset(0, 6)),
      ],
    );
  }

  InputDecoration _softField({required String hint, IconData? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix != null ? Icon(prefix, size: 20, color: _accent) : null,
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _dateFrom = DateFormat('yyyy-MM-dd').format(DateTime(n.year, n.month, 1));
    _dateTo = DateFormat('yyyy-MM-dd').format(DateTime(n.year, n.month + 1, 0));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(page: 1));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
  }

  Future<void> _load({required int page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await _service.fetchReport(
      status: _status,
      divisionId: _divisionId,
      outletId: _outletId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      perPage: _perPage,
      page: page,
    );
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data (periksa jaringan atau hak akses).';
      });
      return;
    }
    final f = data['filters'];
    if (f is Map) {
      final fm = Map<String, dynamic>.from(f);
      _dateFrom = fm['date_from']?.toString() ?? _dateFrom;
      _dateTo = fm['date_to']?.toString() ?? _dateTo;
      _perPage = int.tryParse(fm['per_page']?.toString() ?? '') ?? _perPage;
      _page = int.tryParse(fm['page']?.toString() ?? '') ?? page;
    }
    setState(() {
      _loading = false;
      _tableMissing = data['tableMissing'] == true;
      _kasbons = _parseList(data['kasbons']);
      _divisions = _parseList(data['divisions']);
      _outlets = _parseList(data['outlets']);
      final s = data['summary'];
      _summary = s is Map ? Map<String, dynamic>.from(s) : null;
      final p = data['pagination'];
      _pagination = p is Map ? Map<String, dynamic>.from(p) : {};
      _page = int.tryParse(_pagination['current_page']?.toString() ?? '') ?? page;
      _expandedKasbonIds.removeWhere((id) => !_kasbons.any((k) => (int.tryParse(k['id']?.toString() ?? '') ?? -1) == id));
    });
  }

  String _statusLabel(String code) {
    switch (code) {
      case 'waiting_transfer':
        return 'Menunggu transfer';
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Selesai';
      default:
        return 'Semua';
    }
  }

  String _filterSummaryLine() {
    final d1 = _dateFrom ?? '';
    final d2 = _dateTo ?? '';
    return '${_statusLabel(_status)} · $d1 → $d2';
  }

  String _trackerLabel(String? code) {
    if (code == 'waiting_transfer') return 'menunggu transfer';
    if (code == 'completed') return 'selesai';
    return 'aktif';
  }

  Color _trackerFg(String? code) {
    if (code == 'completed') return const Color(0xFF166534);
    if (code == 'waiting_transfer') return const Color(0xFF334155);
    return const Color(0xFFC2410C);
  }

  Color _trackerBg(String? code) {
    if (code == 'completed') return const Color(0xFFDCFCE7);
    if (code == 'waiting_transfer') return const Color(0xFFE2E8F0);
    return const Color(0xFFFFEDD5);
  }

  bool _canRecord(Map<String, dynamic> row) {
    final termin = int.tryParse(row['termin_total']?.toString() ?? '') ?? 0;
    final paid = int.tryParse(row['paid_installments']?.toString() ?? '') ?? 0;
    return row['tracker_status']?.toString() == 'active' && paid < termin;
  }

  bool _canReverse(Map<String, dynamic> row) {
    return (int.tryParse(row['paid_installments']?.toString() ?? '') ?? 0) > 0;
  }

  String _fmtRp(dynamic v) {
    final n = num.tryParse(v?.toString() ?? '') ?? 0;
    return _rp.format(n);
  }

  String _fmtDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return '—';
    try {
      return _df.format(DateTime.parse(v.toString()));
    } catch (_) {
      return '—';
    }
  }

  String _fmtDateTime(dynamic v) {
    if (v == null || v.toString().isEmpty) return '—';
    try {
      return _dtf.format(DateTime.parse(v.toString()));
    } catch (_) {
      return '—';
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = DateTime.tryParse((isFrom ? _dateFrom : _dateTo) ?? '') ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (d == null) return;
    final s = DateFormat('yyyy-MM-dd').format(d);
    setState(() {
      if (isFrom) {
        _dateFrom = s;
      } else {
        _dateTo = s;
      }
    });
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    final bytes = await _service.downloadExport(
      status: _status,
      divisionId: _divisionId,
      outletId: _outletId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export gagal (kosong atau tidak diizinkan).'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/report_kasbon_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openPayDialogFixed(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String paidAt = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final notesCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Catat pembayaran cicilan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${row['pr_number']} — ${row['employee_name'] ?? 'Karyawan'}',
                      style: const TextStyle(color: _slate600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: _surface,
                      title: const Text('Tanggal pembayaran / potong', style: TextStyle(fontSize: 12, color: _slate500)),
                      subtitle: Text(paidAt, style: const TextStyle(fontWeight: FontWeight.w600, color: _slate900)),
                      trailing: const Icon(Icons.calendar_today_rounded, color: _accent),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(paidAt) ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (d != null) {
                          paidAt = DateFormat('yyyy-MM-dd').format(d);
                          setLocal(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: _softField(hint: 'Catatan (opsional)', prefix: Icons.notes_rounded),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () async {
                    final id = int.tryParse(row['id']?.toString() ?? '');
                    if (id == null) return;
                    Navigator.pop(ctx);
                    final res = await _service.postInstallment(
                      id,
                      paidAt: paidAt,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']?.toString() ?? ''),
                        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                      ),
                    );
                    if (res['success'] == true) await _load(page: _page);
                  },
                  child: const Text('Simpan 1x cicilan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmReverse(Map<String, dynamic> row) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan cicilan terakhir?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Angka Sudah bayar akan turun 1. Status mengikuti alur transfer.',
              style: TextStyle(fontSize: 13, color: _slate600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: _softField(hint: 'Alasan (opsional)', prefix: Icons.edit_note_rounded),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, batalkan 1x'),
          ),
        ],
      ),
    );
    final noteText = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    final id = int.tryParse(row['id']?.toString() ?? '');
    if (id == null) return;
    final res = await _service.postReverseInstallment(id, notes: noteText.isEmpty ? null : noteText);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? ''),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (res['success'] == true) await _load(page: _page);
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _surface,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: _accent, size: 22),
              SizedBox(width: 10),
              Text('Filter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _slate900)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text(
              _filterSummaryLine(),
              style: const TextStyle(fontSize: 12, color: _slate500, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _status,
              decoration: _dropdownDecoration('Status tracker'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Semua', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                  value: 'waiting_transfer',
                  child: Text('Menunggu transfer', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(value: 'active', child: Text('Aktif (transfer paid)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'completed', child: Text('Selesai', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'all'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              value: _divisionId,
              decoration: _dropdownDecoration('Divisi'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua divisi', overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
                ..._divisions.map((d) {
                  final id = d['id']?.toString();
                  final name = d['name']?.toString() ?? id ?? '';
                  return DropdownMenuItem<String?>(
                    value: id,
                    child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _divisionId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              value: _outletId,
              decoration: _dropdownDecoration('Outlet'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua outlet', overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
                ..._outlets.map((o) {
                  final id = o['id']?.toString();
                  final name = o['name']?.toString() ?? id ?? '';
                  return DropdownMenuItem<String?>(
                    value: id,
                    child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _outletId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              isExpanded: true,
              value: _perPage,
              decoration: _dropdownDecoration('Per halaman'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 25, child: Text('25', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 50, child: Text('50', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _perPage = v ?? 15),
            ),
            const SizedBox(height: 10),
            Material(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickDate(isFrom: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 20, color: _accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal approve dari', style: TextStyle(fontSize: 11, color: _slate500)),
                            Text(
                              _dateFrom ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: _slate900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _slate500),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickDate(isFrom: false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 20, color: _accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal approve s/d', style: TextStyle(fontSize: 11, color: _slate500)),
                            Text(
                              _dateTo ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: _slate900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _slate500),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: _softField(hint: 'Cari nomor PR / nama karyawan', prefix: Icons.search_rounded),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(page: 1),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _load(page: 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.filter_alt_rounded, size: 18),
                    label: Text(_loading ? 'Memuat…' : 'Terapkan'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            final n = DateTime.now();
                            setState(() {
                              _status = 'all';
                              _divisionId = null;
                              _outletId = null;
                              _searchController.clear();
                              _perPage = 15;
                              _dateFrom = DateFormat('yyyy-MM-dd').format(DateTime(n.year, n.month, 1));
                              _dateTo = DateFormat('yyyy-MM-dd').format(DateTime(n.year, n.month + 1, 0));
                            });
                            _load(page: 1);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _slate600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: _border),
                    ),
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_exporting || _tableMissing) ? null : _exportExcel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                  backgroundColor: const Color(0xFFF0FDF4),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                      )
                    : const Icon(Icons.table_chart_rounded, size: 18),
                label: Text(_exporting ? 'Mengekspor…' : 'Export Excel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'Pelacakan kasbon dari PR yang disetujui sampai pencatatan cicilan gaji.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35),
      ),
    );
  }

  Widget _buildTableMissing() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text(
        'Tabel pr_kasbons belum ada. Hubungi admin untuk menjalankan migrasi SQL.',
        style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
      ),
    );
  }

  Widget _buildSummary() {
    final s = _summary!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 8.0;
          final w = (c.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(width: w, child: _sumTile('Total baris', '${s['total_rows'] ?? 0}')),
              SizedBox(width: w, child: _sumTile('Menunggu transfer', '${s['waiting_transfer_count'] ?? 0}')),
              SizedBox(width: w, child: _sumTile('Aktif (NFP paid)', '${s['active_count'] ?? 0}')),
              SizedBox(width: w, child: _sumTile('Selesai', '${s['completed_count'] ?? 0}')),
              SizedBox(width: c.maxWidth, child: _sumTile('Jumlah nominal total', _fmtRp(s['sum_total_amount']))),
            ],
          );
        },
      ),
    );
  }

  Widget _sumTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _slate900),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _slate500, height: 1.3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _slate900, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKasbonCard(Map<String, dynamic> row) {
    final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
    final expanded = _expandedKasbonIds.contains(id);
    final prId = int.tryParse(row['purchase_requisition_id']?.toString() ?? '');
    final ts = row['tracker_status']?.toString();
    final nfpLine = (row['nfp_payment_number'] != null && row['nfp_payment_number'].toString().isNotEmpty)
        ? '${row['nfp_payment_number']} · ${row['nfp_payment_status'] ?? ''}'
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expandedKasbonIds.remove(id);
              } else {
                _expandedKasbonIds.add(id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['pr_number']?.toString() ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row['employee_name']?.toString() ?? '—',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _slate900),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row['outlet_name']?.toString() ?? '—',
                          style: const TextStyle(fontSize: 12, color: _slate500, height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _fmtRp(row['total_amount']),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _trackerBg(ts),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _trackerLabel(ts),
                          style: TextStyle(fontSize: 11, color: _trackerFg(ts), fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: _slate500,
                        size: 28,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 12),
                  _detailRow('Termin', '${row['termin_total'] ?? '—'}x'),
                  _detailRow('Sudah bayar', '${row['paid_installments'] ?? 0} / ${row['termin_total'] ?? '—'}'),
                  _detailRow('Per termin', _fmtRp(row['installment_amount'])),
                  _detailRow('Terakhir dicatat', _fmtDate(row['last_installment_at'])),
                  _detailRow('Approve PR', _fmtDate(row['approved_at'])),
                  _detailRow('Approve transfer', _fmtDateTime(row['nfp_transfer_approved_at'])),
                  if (nfpLine != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        nfpLine,
                        style: const TextStyle(fontSize: 11, color: _slate500, fontFamily: 'monospace', height: 1.35),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_canRecord(row))
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openPayDialogFixed(row),
                          child: const Text('Catat cicilan'),
                        ),
                      if (_canReverse(row))
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _confirmReverse(row),
                          child: const Text('Batalkan cicilan'),
                        ),
                      if (prId != null)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: _accent),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PurchaseRequisitionDetailScreen(id: prId)),
                            );
                          },
                          child: const Text('Lihat PR'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final last = int.tryParse(_pagination['last_page']?.toString() ?? '') ?? 1;
    final cur = int.tryParse(_pagination['current_page']?.toString() ?? '') ?? 1;
    if (last <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hal. $cur / $last', style: const TextStyle(color: _slate600, fontWeight: FontWeight.w500)),
            Row(
              children: [
                TextButton(
                  onPressed: cur <= 1 || _loading ? null : () => _load(page: cur - 1),
                  child: const Text('Sebelumnya'),
                ),
                TextButton(
                  onPressed: cur >= last || _loading ? null : () => _load(page: cur + 1),
                  child: const Text('Berikutnya'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Report Kasbon',
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              backgroundColor: Colors.red.shade50,
              leading: const Icon(Icons.error_outline, color: Colors.red),
              actions: [TextButton(onPressed: () => setState(() => _error = null), child: const Text('Tutup'))],
            ),
          Expanded(
            child: _loading && _kasbons.isEmpty
                ? const Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    color: _accent,
                    onRefresh: () => _load(page: _page),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildIntro()),
                        if (_tableMissing) SliverToBoxAdapter(child: _buildTableMissing()),
                        if (!_tableMissing) ...[
                          SliverToBoxAdapter(child: _buildFilters()),
                          if (_summary != null) SliverToBoxAdapter(child: _buildSummary()),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (c, i) => _buildKasbonCard(_kasbons[i]),
                              childCount: _kasbons.length,
                            ),
                          ),
                          if (_kasbons.isEmpty && !_loading)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'Tidak ada data untuk filter ini.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(child: _buildPagination()),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
