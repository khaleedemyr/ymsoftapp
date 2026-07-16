import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/qa2_audit_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../qa2_audit/qa2_audit_create_screen.dart';
import '../qa2_audit/qa2_audit_form_screen.dart';
import '../qa2_audit/qa2_audit_summary_screen.dart';
import 'qa2_audit_ui.dart';

class Qa2AuditIndexScreen extends StatefulWidget {
  const Qa2AuditIndexScreen({super.key});

  @override
  State<Qa2AuditIndexScreen> createState() => _Qa2AuditIndexScreenState();
}

class _Qa2AuditIndexScreenState extends State<Qa2AuditIndexScreen> {
  final _service = Qa2AuditService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  Map<String, dynamic> _stats = {'total': 0, 'draft': 0, 'submitted': 0};
  Map<String, dynamic> _permissions = {};
  List<Map<String, dynamic>> _audits = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _canActionAdmin = false;

  String _filterStatus = '';
  int? _filterOutletId;
  int _page = 1;
  int _lastPage = 1;
  bool _loadingMore = false;
  bool _filterExpanded = false;

  @override
  void initState() {
    super.initState();
    _initUser();
    _load();
  }

  Future<void> _initUser() async {
    final user = await AuthService().getUserData();
    if (!mounted) return;
    setState(() {
      _canActionAdmin = _resolveCanActionAdmin(user, _permissions);
    });
  }

  bool _isTruthy(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

  bool _resolveCanActionAdmin(Map<String, dynamic>? user, Map<String, dynamic> perms) {
    if (perms.containsKey('can_action_admin')) {
      return _isTruthy(perms['can_action_admin']);
    }
    final role = user?['id_role']?.toString() ?? '';
    final divisionId = _parseInt(user?['division_id']) ?? 0;
    return divisionId == 32 || role == '5af56935b011a';
  }

  bool _canFillCapForAudit(Map<String, dynamic> audit) {
    if (audit['status']?.toString() != 'submitted') return false;
    final pendingCap = _parseInt(audit['count_nc_pending_cap']) ?? 0;
    final countNc = _parseInt(audit['count_nc']) ?? 0;
    if (countNc <= 0 || pendingCap <= 0) return false;
    // Index: tampilkan Isi CAP jika masih ada NC pending (selaras web).
    return true;
  }

  bool _showRowActions(Map<String, dynamic> audit) {
    final status = audit['status']?.toString() ?? 'draft';
    if (status == 'draft') return _canActionAdmin;
    return true;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _dateText(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return raw;
    }
  }

  bool get _hasActiveFilters =>
      _filterStatus.isNotEmpty || _filterOutletId != null || _searchCtrl.text.trim().isNotEmpty;

  String _compactPeopleNames(dynamic raw) {
    if (raw is! List) return '-';
    final names = <String>[];
    for (final p in raw) {
      if (p is Map) {
        final name = p['name']?.toString() ?? p['nama_lengkap']?.toString();
        if (name != null && name.isNotEmpty) names.add(name);
      }
    }
    if (names.isEmpty) return '-';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  String? _outletFilterLabel() {
    if (_filterOutletId == null) return null;
    for (final o in _outlets) {
      if (Qa2AuditUi.outletId(o) == _filterOutletId) {
        return Qa2AuditUi.outletName(o);
      }
    }
    return 'Outlet';
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _page = 1;
      if (!_loading) setState(() => _refreshing = true);
    } else {
      if (_loadingMore || _page >= _lastPage) return;
      setState(() => _loadingMore = true);
      _page++;
    }

    final res = await _service.fetchIndex(
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      status: _filterStatus.isEmpty ? null : _filterStatus,
      outletId: _filterOutletId?.toString(),
      page: _page,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _error = res['message']?.toString() ?? 'Gagal memuat data.';
        if (reset) _audits = [];
        if (reset) _stats = {'total': 0, 'draft': 0, 'submitted': 0};
        _refreshing = false;
        _loading = false;
        _loadingMore = false;
      });
      return;
    }

    final listRaw = res['audits'] ?? res['data'];
    final outletsRaw = res['outlets'];
    final statsRaw = res['stats'] ?? res['summary'] ?? res['statistics'];
    final permsRaw = res['permissions'];
    final paginationRaw = res['pagination'];

    final newAudits = (listRaw is List)
        ? listRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _error = null;
      if (reset) {
        _audits = newAudits;
      } else {
        _audits = [..._audits, ...newAudits];
      }
      if (paginationRaw is Map) {
        _lastPage = _parseInt(paginationRaw['last_page']) ?? 1;
        _page = _parseInt(paginationRaw['current_page']) ?? _page;
      } else {
        _lastPage = 1;
      }
      _outlets = (outletsRaw is List)
          ? outletsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : _outlets;
      if (statsRaw is Map<String, dynamic>) {
        _stats = {
          'total': statsRaw['total'] ?? statsRaw['count_total'] ?? 0,
          'draft': statsRaw['draft'] ?? statsRaw['count_draft'] ?? 0,
          'submitted': statsRaw['submitted'] ?? statsRaw['count_submitted'] ?? 0,
        };
      }
      _permissions = (permsRaw is Map<String, dynamic>) ? permsRaw : _permissions;
      if (_permissions.containsKey('can_action_admin')) {
        _canActionAdmin = _isTruthy(_permissions['can_action_admin']);
      }
      _refreshing = false;
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() => _load(reset: false);

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _filterStatus = '';
      _filterOutletId = null;
    });
    _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> audit) async {
    final id = _parseInt(audit['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus QA Audit?'),
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
    final res = await _service.deleteAudit(id);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QA Audit dihapus.'), behavior: SnackBarBehavior.floating),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menghapus.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Qa2AuditCreateScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _openSummary() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Qa2AuditSummaryScreen()),
    );
  }

  Future<void> _openForm(int auditId, {bool capOnly = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Qa2AuditFormScreen(auditId: auditId, capOnly: capOnly)),
    );
    if (mounted) _load();
  }

  Future<void> _shareToWhatsApp(Map<String, dynamic> audit) async {
    final id = _parseInt(audit['id']);
    if (id == null) return;
    final res = await _service.generateShareLink(id);
    if (!mounted) return;
    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal membuat link share'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final url = res['url']?.toString();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link share tidak tersedia'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final number = audit['audit_number']?.toString() ?? '';
    final message = res['message']?.toString() ?? 'QA Audit $number\n$url';
    final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(waUri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka WhatsApp'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _isTruthy(_permissions['can_manage']);
    return AppScaffold(
      title: 'QA Audit',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Report Summary',
          onPressed: _openSummary,
          icon: const Icon(Icons.insights_rounded),
        ),
      ],
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: Qa2AuditUi.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Buat QA Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
        children: [
          _buildStats(),
          _buildFilters(),
          Expanded(
            child: _loading && _audits.isEmpty
                ? const Center(child: AppLoadingIndicator(size: 36, color: Qa2AuditUi.primary))
                : RefreshIndicator(
                    color: Qa2AuditUi.primary,
                    onRefresh: _load,
                    child: _audits.isEmpty && !_loading
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _audits.length + (_page < _lastPage ? 1 : 0),
                            itemBuilder: (ctx, idx) {
                              if (idx >= _audits.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: _loadingMore
                                        ? const AppLoadingIndicator(size: 28, color: Qa2AuditUi.primary)
                                        : OutlinedButton.icon(
                                            onPressed: _loadMore,
                                            icon: const Icon(Icons.expand_more_rounded),
                                            label: const Text('Muat lebih banyak'),
                                          ),
                                  ),
                                );
                              }
                              return _buildAuditCard(_audits[idx]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final total = _stats['total'] ?? 0;
    final draft = _stats['draft'] ?? 0;
    final submitted = _stats['submitted'] ?? 0;
    Widget statCard(String label, dynamic value, Color color, Color bg, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(color: Qa2AuditUi.slate500, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          statCard('Total', total, Qa2AuditUi.slate900, const Color(0xFFEFF6FF), Icons.fact_check_rounded),
          const SizedBox(width: 12),
          statCard('Draft', draft, const Color(0xFFB45309), const Color(0xFFFEF3C7), Icons.edit_note_rounded),
          const SizedBox(width: 12),
          statCard('Submitted', submitted, const Color(0xFF047857), const Color(0xFFD1FAE5), Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final outletLabel = _outletFilterLabel();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: Qa2AuditUi.slate500),
              hintText: 'Cari nomor audit, outlet, template...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              suffixIcon: _searchCtrl.text.trim().isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                        _load();
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _load(),
          ),
          if (_hasActiveFilters && !_filterExpanded) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_filterStatus.isNotEmpty)
                  _activeFilterChip(
                    _filterStatus == 'draft' ? 'Draft' : 'Submitted',
                    () => setState(() => _filterStatus = ''),
                  ),
                if (outletLabel != null)
                  _activeFilterChip(outletLabel, () => setState(() => _filterOutletId = null)),
                if (_searchCtrl.text.trim().isNotEmpty)
                  _activeFilterChip('“${_searchCtrl.text.trim()}”', () {
                    _searchCtrl.clear();
                    setState(() {});
                  }),
              ],
            ),
          ],
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _filterExpanded ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                    size: 20,
                    color: Qa2AuditUi.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filterExpanded ? 'Sembunyikan filter' : 'Filter lanjutan',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Qa2AuditUi.primary),
                    ),
                  ),
                  if (_hasActiveFilters && !_filterExpanded)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Qa2AuditUi.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Aktif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Qa2AuditUi.primary)),
                    ),
                  Icon(
                    _filterExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Qa2AuditUi.slate500,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _filterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _filterStatus.isEmpty ? null : _filterStatus,
                            hint: const Text('Semua status', style: TextStyle(color: Qa2AuditUi.slate500)),
                            icon: const Icon(Icons.expand_more_rounded, color: Qa2AuditUi.primary),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Semua status')),
                              DropdownMenuItem(value: 'draft', child: Text('Draft')),
                              DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                            ],
                            onChanged: (v) => setState(() => _filterStatus = v ?? ''),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _filterOutletId,
                            hint: const Text('Semua outlet', style: TextStyle(color: Qa2AuditUi.slate500)),
                            icon: const Icon(Icons.expand_more_rounded, color: Qa2AuditUi.primary),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Semua outlet')),
                              ..._outlets.expand((o) sync* {
                                final id = Qa2AuditUi.outletId(o);
                                if (id == null) return;
                                yield DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text(Qa2AuditUi.outletName(o), overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (v) => setState(() => _filterOutletId = v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading || _refreshing ? null : _load,
                        style: FilledButton.styleFrom(
                          backgroundColor: Qa2AuditUi.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Terapkan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading || _refreshing ? null : _resetFilters,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Qa2AuditUi.slate600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade900))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activeFilterChip(String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: () {
        onRemove();
        _load();
      },
      backgroundColor: Qa2AuditUi.primary.withValues(alpha: 0.08),
      side: BorderSide(color: Qa2AuditUi.primary.withValues(alpha: 0.2)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> audit) {
    final id = _parseInt(audit['id']) ?? 0;
    final status = audit['status']?.toString() ?? 'draft';
    final isSubmitted = status == 'submitted';
    final outlet = audit['outlet_name']?.toString() ?? '-';
    final template = audit['template_name']?.toString() ?? '-';
    final number = audit['audit_number']?.toString() ?? '#$id';
    final dateText = _dateText(audit['audit_datetime']?.toString() ?? audit['created_at']?.toString());
    final auditors = _compactPeopleNames(audit['auditors']);
    final auditees = _compactPeopleNames(audit['auditees']);
    final countC = _parseInt(audit['count_c']) ?? 0;
    final countNc = _parseInt(audit['count_nc']) ?? 0;
    final countNa = _parseInt(audit['count_na']) ?? 0;
    final score = audit['score'] is num ? (audit['score'] as num).toDouble() : Qa2AuditUi.auditScore(audit);
    final badge = Qa2AuditUi.resultBadge(score);
    final pendingCap = _parseInt(audit['count_nc_pending_cap']) ?? 0;
    final canFillCap = _canFillCapForAudit(audit);
    final showActions = _showRowActions(audit);
    final capBadge = Qa2AuditUi.capStatusBadge(audit);
    final accentColor = isSubmitted ? const Color(0xFF059669) : const Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (id > 0 && showActions) ? () => _openForm(id) : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: accentColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
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
                                        number,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Qa2AuditUi.slate900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        dateText,
                                        style: const TextStyle(color: Qa2AuditUi.slate500, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                Qa2AuditUi.statusChip(status),
                                if (capBadge != null) ...[
                                  const SizedBox(width: 6),
                                  Qa2AuditUi.capStatusChip(audit),
                                ],
                                if (showActions)
                                  PopupMenuButton<String>(
                                    tooltip: 'Aksi',
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600, size: 22),
                                    onSelected: (v) async {
                                      if (id <= 0) return;
                                      if (v == 'view') await _openForm(id);
                                      if (v == 'share') await _shareToWhatsApp(audit);
                                      if (v == 'edit') await _openForm(id);
                                      if (v == 'cap') await _openForm(id, capOnly: true);
                                      if (v == 'delete') await _confirmDelete(audit);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'view', child: _MenuRow(Icons.fact_check_outlined, 'Lihat Detail')),
                                      const PopupMenuItem(value: 'share', child: _MenuRow(Icons.share_rounded, 'Share WA')),
                                      if (_canActionAdmin)
                                        const PopupMenuItem(value: 'edit', child: _MenuRow(Icons.edit_rounded, 'Edit')),
                                      if (canFillCap && isSubmitted && pendingCap > 0)
                                        PopupMenuItem(
                                          value: 'cap',
                                          child: _MenuRow(Icons.assignment_turned_in_outlined, 'Isi CAP ($pendingCap)'),
                                        ),
                                      if (_canActionAdmin)
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: _MenuRow(Icons.delete_outline_rounded, 'Hapus', color: Color(0xFFDC2626)),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              outlet,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Qa2AuditUi.slate900, height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.description_outlined, size: 14, color: Qa2AuditUi.slate500),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    template,
                                    style: const TextStyle(fontSize: 12, color: Qa2AuditUi.slate500, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _resultMini('C', countC, const Color(0xFF059669), const Color(0xFFECFDF5)),
                                const SizedBox(width: 6),
                                _resultMini('NC', countNc, const Color(0xFFE11D48), const Color(0xFFFFF1F2)),
                                const SizedBox(width: 6),
                                _resultMini('NA', countNa, Qa2AuditUi.slate600, const Color(0xFFF1F5F9)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: badge.bg, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${badge.label} ${Qa2AuditUi.formatScore(score)}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badge.fg),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 10),
                            _peopleLine(Icons.verified_user_outlined, 'Auditor', auditors),
                            const SizedBox(height: 4),
                            _peopleLine(Icons.groups_2_outlined, 'Auditee', auditees),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultMini(String label, int count, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          children: [
            TextSpan(text: '$label ', style: TextStyle(color: fg.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
            TextSpan(text: '$count'),
          ],
        ),
      ),
    );
  }

  Widget _peopleLine(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Qa2AuditUi.slate500),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: Qa2AuditUi.slate500, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Qa2AuditUi.slate600, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Column(
          children: const [
            CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFEEF2FF),
              child: Icon(Icons.fact_check_rounded, size: 36, color: Qa2AuditUi.primary),
            ),
            SizedBox(height: 12),
            Text('Belum ada QA Audit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Qa2AuditUi.slate900)),
            SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Buat audit baru atau tarik untuk memuat ulang.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Qa2AuditUi.slate500, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Qa2AuditUi.slate900;
    return Row(
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
