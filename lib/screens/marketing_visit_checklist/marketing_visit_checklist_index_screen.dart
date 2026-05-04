import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/marketing_visit_checklist_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'marketing_visit_checklist_detail_screen.dart';
import 'marketing_visit_checklist_form_screen.dart';

/// Daftar checklist — pola kartu & filter mengikuti `OutletTransferIndexScreen`.
class MarketingVisitChecklistIndexScreen extends StatefulWidget {
  const MarketingVisitChecklistIndexScreen({super.key});

  @override
  State<MarketingVisitChecklistIndexScreen> createState() => _MarketingVisitChecklistIndexScreenState();
}

class _MarketingVisitChecklistIndexScreenState extends State<MarketingVisitChecklistIndexScreen> {
  static const Color _primary = Color(0xFF6366F1);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);

  final _service = MarketingVisitChecklistService();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _outlets = [];

  int? _filterOutletId;
  DateTime? _filterDate;

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final outletStr = _filterOutletId?.toString();
    final dateStr = _filterDate != null
        ? '${_filterDate!.year}-${_filterDate!.month.toString().padLeft(2, '0')}-${_filterDate!.day.toString().padLeft(2, '0')}'
        : null;
    final data = await _service.fetchIndex(outletId: outletStr, visitDate: dateStr);
    if (!mounted) return;
    if (data['success'] != true) {
      setState(() {
        _loading = false;
        _error = data['message']?.toString() ?? 'Gagal memuat data.';
        _rows = [];
      });
      return;
    }
    final list = data['checklists'];
    final outletsRaw = data['outlets'];
    setState(() {
      _error = null;
      _rows = (list is List) ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      _outlets =
          (outletsRaw is List) ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      _loading = false;
    });
  }

  void _applyFilters() => _load();

  void _clearFilters() {
    setState(() {
      _filterOutletId = null;
      _filterDate = null;
    });
    _load();
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _filterDate = d);
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = _parseInt(row['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus checklist?'),
        content: const Text('Data yang dihapus tidak dapat dikembalikan.'),
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
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Checklist dihapus.'),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          content: Text(res['message']?.toString() ?? 'Gagal menghapus'),
        ),
      );
    }
  }

  void _openDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MarketingVisitChecklistDetailScreen(checklistId: id)),
    );
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MarketingVisitChecklistFormScreen()),
    );
    _load();
  }

  Future<void> _openEdit(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MarketingVisitChecklistFormScreen(checklistId: id)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Marketing Visit Checklist',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _primary,
        elevation: 2,
        highlightElevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Material(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFFEF2F2),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _loading && _rows.isEmpty
                      ? const Center(child: AppLoadingIndicator(size: 36, color: _primary))
                      : RefreshIndicator(
                          color: _primary,
                          onRefresh: _load,
                          child: _rows.isEmpty && !_loading
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) => _buildChecklistCard(_rows[index]),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.filter_alt_rounded, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _slate900)),
                    Text('Outlet & tanggal kunjungan', style: TextStyle(fontSize: 12, color: _slate500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                hint: const Text('Semua outlet', style: TextStyle(color: _slate400)),
                value: _filterOutletId,
                icon: const Icon(Icons.expand_more_rounded, color: _primary),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Semua outlet'),
                  ),
                  ..._outlets.expand((o) {
                    final oid = _parseInt(o['id']);
                    if (oid == null) return const Iterable<DropdownMenuItem<int?>>.empty();
                    return [
                      DropdownMenuItem<int?>(
                        value: oid,
                        child: Text(o['name']?.toString() ?? '-'),
                      ),
                    ];
                  }),
                ],
                onChanged: (v) => setState(() => _filterOutletId = v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _pickFilterDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: _primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _filterDate == null
                            ? 'Semua tanggal'
                            : DateFormat('dd MMM yyyy', 'id_ID').format(_filterDate!),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _filterDate == null ? _slate400 : _slate900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _applyFilters,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text('Terapkan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _slate600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(Map<String, dynamic> row) {
    final id = _parseInt(row['id']) ?? 0;
    final outletName = row['outlet_name']?.toString() ?? '-';
    final userName = row['user_name']?.toString() ?? '-';
    final dateRaw = row['visit_date']?.toString();
    final dateText = _formatDate(dateRaw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: id > 0 ? () => _openDetail(id) : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: _primary.withValues(alpha: 0.08),
          highlightColor: _primary.withValues(alpha: 0.04),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCreatorColumn(userName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                outletName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _slate900, height: 1.25),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Aksi',
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              offset: const Offset(0, 8),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
                              ),
                              onSelected: (v) async {
                                if (id <= 0) return;
                                if (v == 'edit') await _openEdit(id);
                                if (v == 'delete') await _confirmDelete(row);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: ListTileLeadingIcon(Icons.edit_rounded, 'Edit')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTileLeadingIcon(Icons.delete_outline_rounded, 'Hapus', color: Color(0xFFDC2626)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chipPill(
                              icon: Icons.tag_rounded,
                              label: id > 0 ? '#$id' : '-',
                              fg: _primary,
                              bg: _primary.withValues(alpha: 0.12),
                            ),
                            _chipPill(
                              icon: Icons.event_rounded,
                              label: dateText,
                              fg: _slate600,
                              bg: const Color(0xFFF1F5F9),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 16, color: _slate400),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                userName,
                                style: const TextStyle(fontSize: 12, color: _slate500, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _infoPill(Icons.fact_check_outlined, 'Marketing visit'),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded, size: 18, color: _slate400),
                            const SizedBox(width: 4),
                            Text(
                              'Detail',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorColumn(String name) {
    final initials = _initials(name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFEEF2FF),
          child: Text(
            initials,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _primary),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 72,
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w500, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _chipPill({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _slate500),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.fact_check_rounded, size: 44, color: _primary.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada Marketing Visit Checklist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _slate900),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Catat kunjungan marketing dengan checklist standar. Tap tombol di bawah untuk mulai.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.45, color: _slate500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty || t == '-') return '?';
    final p = t.split(RegExp(r'\s+'));
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return '${p.first[0]}${p.last[0]}'.toUpperCase();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

/// Helper untuk popup menu dengan ikon — hindari duplikasi Row manual.
class ListTileLeadingIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const ListTileLeadingIcon(this.icon, this.label, {super.key, this.color = const Color(0xFF334155)});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
