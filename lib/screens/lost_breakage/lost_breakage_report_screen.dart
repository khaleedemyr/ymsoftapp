import 'package:flutter/material.dart';
import '../../services/lost_breakage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';

class LostBreakageReportScreen extends StatefulWidget {
  const LostBreakageReportScreen({super.key});

  @override
  State<LostBreakageReportScreen> createState() => _LostBreakageReportScreenState();
}

class _LostBreakageReportScreenState extends State<LostBreakageReportScreen> {
  final LostBreakageService _service = LostBreakageService();
  List<Map<String, dynamic>> _data = [];
  bool _loading = false;
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _outlets = [];
  int? _filterOutletId;
  String _filterStatus = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final Map<int, List<Map<String, dynamic>>> _expandedDetails = {};
  final Map<int, bool> _loadingDetails = {};
  final Set<int> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = AuthService();
    _userData = await auth.getUserData();
    if (_userData?['id_outlet']?.toString() == '1') {
      _outlets = await _service.getOutlets();
    }
    _load();
  }

  String? _fmtDateParam(DateTime? d) => d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _service.getReport(
        outletId: _filterOutletId,
        status: _filterStatus.isNotEmpty ? _filterStatus : null,
        dateFrom: _fmtDateParam(_dateFrom),
        dateTo: _fmtDateParam(_dateTo),
        page: _page,
      );
      if (!mounted) return;
      if (res != null) {
        final d = res['data'];
        if (d is Map) {
          final list = d['data'];
          setState(() {
            _data = list is List ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
            _total = _pi(d['total']);
            _lastPage = _pi(d['last_page'], f: 1);
            _page = _pi(d['current_page'], f: _page);
          });
        }
      }
    } catch (e) { print('Report load error: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  int _pi(dynamic v, {int f = 0}) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? f;

  Future<void> _toggleExpand(int headerId) async {
    if (_expandedIds.contains(headerId)) {
      setState(() => _expandedIds.remove(headerId));
      return;
    }
    setState(() => _expandedIds.add(headerId));
    if (_expandedDetails.containsKey(headerId)) return;
    setState(() => _loadingDetails[headerId] = true);
    try {
      final details = await _service.getReportDetails(headerId);
      if (mounted) setState(() => _expandedDetails[headerId] = details);
    } catch (e) { print('Detail error: $e'); }
    if (mounted) setState(() => _loadingDetails[headerId] = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Report Lost & Breakage',
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: Colors.orange)) : _buildList()),
          if (_lastPage > 1) _buildPagination(),
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> get _outletDropdownItems {
    final seen = <int>{};
    final items = <DropdownMenuItem<int>>[const DropdownMenuItem<int>(value: null, child: Text('Semua Outlet'))];
    for (final o in _outlets) {
      final id = int.tryParse(o['id']?.toString() ?? o['id_outlet']?.toString() ?? '');
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      items.add(DropdownMenuItem<int>(value: id, child: Text(o['name']?.toString() ?? o['nama_outlet']?.toString() ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))));
    }
    return items;
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(context: context, initialDate: _dateFrom ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) { setState(() => _dateFrom = picked); _page = 1; _load(); }
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(context: context, initialDate: _dateTo ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) { setState(() => _dateTo = picked); _page = 1; _load(); }
  }

  Widget _buildFilters() {
    final isAdmin = _userData?['id_outlet']?.toString() == '1';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          if (isAdmin) ...[
            DropdownButtonFormField<int>(
              initialValue: _outletDropdownItems.any((d) => d.value == _filterOutletId) ? _filterOutletId : null,
              decoration: InputDecoration(labelText: 'Outlet', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
              items: _outletDropdownItems,
              onChanged: (v) { setState(() { _filterOutletId = v; _page = 1; }); _load(); },
              isExpanded: true,
            ),
            const SizedBox(height: 10),
          ],
          DropdownButtonFormField<String>(
            initialValue: _filterStatus.isEmpty ? null : _filterStatus,
            decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua')),
              DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
              DropdownMenuItem(value: 'SUBMITTED', child: Text('Menunggu Approval')),
              DropdownMenuItem(value: 'APPROVED', child: Text('Disetujui')),
              DropdownMenuItem(value: 'REJECTED', child: Text('Ditolak')),
            ],
            onChanged: (v) { setState(() { _filterStatus = v ?? ''; _page = 1; }); _load(); },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDateFrom,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Dari',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      suffixIcon: _dateFrom != null ? GestureDetector(onTap: () { setState(() => _dateFrom = null); _page = 1; _load(); }, child: const Icon(Icons.clear, size: 16)) : const Icon(Icons.calendar_today, size: 16),
                    ),
                    child: Text(_dateFrom != null ? _fmtDate(_dateFrom.toString()) : '-', style: TextStyle(fontSize: 13, color: _dateFrom != null ? Colors.black : Colors.grey)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _pickDateTo,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Sampai',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      suffixIcon: _dateTo != null ? GestureDetector(onTap: () { setState(() => _dateTo = null); _page = 1; _load(); }, child: const Icon(Icons.clear, size: 16)) : const Icon(Icons.calendar_today, size: 16),
                    ),
                    child: Text(_dateTo != null ? _fmtDate(_dateTo.toString()) : '-', style: TextStyle(fontSize: 13, color: _dateTo != null ? Colors.black : Colors.grey)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { setState(() { _filterOutletId = null; _filterStatus = ''; _dateFrom = null; _dateTo = null; }); _page = 1; _load(); },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Tidak ada data', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _data.length,
        itemBuilder: (ctx, i) => _buildReportCard(_data[i]),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> row) {
    final id = int.tryParse(row['id']?.toString() ?? '0') ?? 0;
    final expanded = _expandedIds.contains(id);
    final status = row['status']?.toString() ?? '';
    final typeSummary = row['type_summary'] is Map ? Map<String, dynamic>.from(row['type_summary']) : {};
    final lost = _pi(typeSummary['lost']);
    final breakage = _pi(typeSummary['breakage']);
    final itemCount = _pi(row['item_count']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleExpand(id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row['number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E40AF))),
                            Text(_fmtDate(row['date']?.toString()), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.store, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(child: Text(row['outlet_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      _chip('Items: $itemCount', Colors.blue),
                      if (lost > 0) _chip('Lost: $lost', Colors.yellow.shade800),
                      if (breakage > 0) _chip('Breakage: $breakage', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _buildExpandedDetail(id),
        ],
      ),
    );
  }

  Widget _buildExpandedDetail(int headerId) {
    if (_loadingDetails[headerId] == true) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)));
    }
    final details = _expandedDetails[headerId] ?? [];
    if (details.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: Text('Tidak ada item', style: TextStyle(color: Colors.grey.shade400)));
    }
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14))),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text('Detail Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          ...details.asMap().entries.map((e) {
            final d = e.value;
            final type = d['type']?.toString() ?? 'lost';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  CircleAvatar(radius: 12, backgroundColor: Colors.orange.shade100, child: Text('${e.key + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade800))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['item_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${d['qty']} ${d['unit_name'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (d['note'] != null && d['note'].toString().isNotEmpty) Text(d['note'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: type == 'breakage' ? Colors.red.shade100 : Colors.yellow.shade100, borderRadius: BorderRadius.circular(10)),
                    child: Text(type == 'breakage' ? 'Breakage' : 'Lost', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: type == 'breakage' ? Colors.red.shade800 : Colors.yellow.shade800)),
                  ),
                  if (d['photo'] != null && d['photo'].toString().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showPhoto(d['photo'].toString()),
                      child: Icon(Icons.photo, size: 18, color: Colors.blue.shade600),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showPhoto(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: const Text('Foto Bukti'), automaticallyImplyLeading: false, actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
            Image.network('${AuthService.storageUrl}/storage/$path', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(32), child: Icon(Icons.broken_image, size: 48, color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }

  Widget _statusBadge(String status) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'DRAFT': bg = Colors.grey.shade100; fg = Colors.grey.shade700; label = 'Draft'; break;
      case 'SUBMITTED': bg = Colors.yellow.shade100; fg = Colors.yellow.shade800; label = 'Menunggu'; break;
      case 'APPROVED': bg = Colors.green.shade100; fg = Colors.green.shade800; label = 'Disetujui'; break;
      case 'REJECTED': bg = Colors.red.shade100; fg = Colors.red.shade800; label = 'Ditolak'; break;
      default: bg = Colors.grey.shade100; fg = Colors.grey.shade600; label = status;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)));
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total: $_total', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _page > 1 ? () { _page--; _load(); } : null, iconSize: 20),
              Text('$_page / $_lastPage', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _page < _lastPage ? () { _page++; _load(); } : null, iconSize: 20),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '-';
    try { final dt = DateTime.parse(d); return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'; } catch (_) { return d; }
  }
}
