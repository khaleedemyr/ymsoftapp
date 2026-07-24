import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/wfh_request_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'wfh_request_detail_screen.dart';
import 'wfh_request_form_screen.dart';

class WfhRequestIndexScreen extends StatefulWidget {
  const WfhRequestIndexScreen({super.key});

  @override
  State<WfhRequestIndexScreen> createState() => _WfhRequestIndexScreenState();
}

class _WfhRequestIndexScreenState extends State<WfhRequestIndexScreen> {
  static const Color _teal = Color(0xFF0D9488);
  static const Color _bg = Color(0xFFF1F5F9);

  final _service = WfhRequestService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _filterExpanded = false;
  bool _canDelete = false;
  int? _deletingId;
  String _search = '';

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _from = 0;
  int _to = 0;
  final int _perPage = 15;

  final _dateFmt = DateFormat('dd MMM yyyy', 'id_ID');
  final _dateTimeFmt = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadList({int page = 1}) async {
    setState(() => _loading = true);
    _page = page;

    final resp = await _service.getList(
      search: _search,
      page: _page,
      perPage: _perPage,
    );

    if (!mounted) return;

    if (resp != null && resp['success'] == true) {
      _canDelete = resp['can_delete'] == true;
      final dataSection = resp['data'];
      List<Map<String, dynamic>> rows = [];
      if (dataSection is Map) {
        final nested = dataSection['data'];
        if (nested is List) {
          rows = nested.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        _lastPage = int.tryParse('${dataSection['last_page'] ?? 1}') ?? 1;
        _total = int.tryParse('${dataSection['total'] ?? 0}') ?? 0;
        _from = int.tryParse('${dataSection['from'] ?? 0}') ?? 0;
        _to = int.tryParse('${dataSection['to'] ?? 0}') ?? 0;
      } else if (dataSection is List) {
        rows = dataSection.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _lastPage = 1;
        _total = rows.length;
        _from = rows.isEmpty ? 0 : 1;
        _to = rows.length;
      }
      _items = rows;
    } else {
      _items = [];
      _total = 0;
      _from = 0;
      _to = 0;
    }

    setState(() => _loading = false);
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WfhRequestFormScreen()),
    );
    if (ok == true) _loadList(page: 1);
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    if (id <= 0) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WfhRequestDetailScreen(requestId: id)),
    );
    _loadList(page: _page);
  }

  Future<void> _confirmDelete(int id, String number) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pengajuan?'),
        content: Text('Hapus $number? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingId = id);
    final res = await _service.destroy(id);
    if (!mounted) return;
    setState(() => _deletingId = null);

    final success = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message']?.toString() ?? (success ? 'Berhasil dihapus' : 'Gagal menghapus'),
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
    if (success) _loadList(page: _page);
  }

  String _userName(Map<String, dynamic> item) {
    return item['user'] is Map
        ? (item['user']['nama_lengkap']?.toString() ?? '-')
        : '-';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name == '-') return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    try {
      return _dateFmt.format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    try {
      return _dateTimeFmt.format(DateTime.parse(value.toString()).toLocal());
    } catch (_) {
      return value.toString();
    }
  }

  String _formatTime(dynamic value) {
    if (value == null) return '-';
    final s = value.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'SUBMITTED':
        return 'Waiting Approval';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 104,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.sync, color: Colors.green.shade200),
              onPressed: _loading ? null : () => _loadList(page: _page),
            ),
          ],
        ),
        title: const Text(
          'Pengajuan WFH',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
            child: FilledButton.icon(
              onPressed: _openCreate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                '+ Tambah',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: RefreshIndicator(
              color: _teal,
              onRefresh: () => _loadList(page: 1),
              child: _buildList(),
            ),
          ),
          if (!_loading) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: _teal),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Icon(
                    _filterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_filterExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nomor / nama / alasan...',
                      prefixIcon: const Icon(Icons.search, color: _teal),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) {
                      _search = _searchController.text.trim();
                      _loadList(page: 1);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _searchController.clear();
                            _search = '';
                            _loadList(page: 1);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            _search = _searchController.text.trim();
                            _loadList(page: 1);
                          },
                          style: FilledButton.styleFrom(backgroundColor: _teal),
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.home_work_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Belum ada pengajuan WFH',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildCard(_items[index]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    final number = item['number']?.toString() ?? '-';
    final status = item['status']?.toString() ?? '';
    final userName = _userName(item);
    final shiftName = item['shift_name']?.toString() ?? '-';
    final flows = List<Map<String, dynamic>>.from((item['approval_flows'] as List?) ?? []);
    flows.sort((a, b) => (a['approval_level'] ?? 0).compareTo(b['approval_level'] ?? 0));
    final deleting = _deletingId == id;
    final statusColor = _statusColor(status);

    return InkWell(
      onTap: () => _openDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFCCFBF1),
                  child: Text(
                    _initials(userName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 96,
                  child: Text(
                    userName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          number,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                        onSelected: (v) {
                          if (v == 'detail') _openDetail(item);
                          if (v == 'delete') _confirmDelete(id, number);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'detail', child: Text('Detail')),
                          if (_canDelete)
                            PopupMenuItem(
                              value: 'delete',
                              enabled: !deleting,
                              child: Text(
                                deleting ? 'Menghapus…' : 'Hapus',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(item['wfh_date']),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _pill(
                    Icons.schedule,
                    '$shiftName · ${_formatTime(item['time_start'])} – ${_formatTime(item['time_end'])}',
                  ),
                  if (flows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...flows.take(3).map((flow) {
                      final flowStatus = flow['status']?.toString() ?? 'PENDING';
                      final name = flow['approver']?['nama_lengkap']?.toString() ?? '-';
                      final level = flow['approval_level'] ?? '-';
                      String subtitle = 'Waiting';
                      if (flowStatus == 'APPROVED') {
                        subtitle = 'Approved · ${_formatDateTime(flow['approved_at'])}';
                      } else if (flowStatus == 'REJECTED') {
                        subtitle = 'Rejected · ${_formatDateTime(flow['rejected_at'])}';
                      }
                      final color =
                          _statusColor(flowStatus == 'PENDING' ? 'SUBMITTED' : flowStatus);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'L$level · $name · $subtitle',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (flows.length > 3)
                      Text(
                        '+${flows.length - 3} approver lainnya',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _teal),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: _bg,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _total == 0 ? '0 data' : 'Menampilkan $_from–$_to dari $_total',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          IconButton(
            onPressed: _page > 1 && !_loading ? () => _loadList(page: _page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$_page / $_lastPage', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: _page < _lastPage && !_loading ? () => _loadList(page: _page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
