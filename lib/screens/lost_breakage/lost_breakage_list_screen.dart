import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/lost_breakage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'lost_breakage_form_screen.dart';
import 'lost_breakage_detail_screen.dart';
import 'lost_breakage_report_screen.dart';

class LostBreakageListScreen extends StatefulWidget {
  const LostBreakageListScreen({super.key});

  @override
  State<LostBreakageListScreen> createState() => _LostBreakageListScreenState();
}

class _LostBreakageListScreenState extends State<LostBreakageListScreen> {
  final LostBreakageService _service = LostBreakageService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _filterExpanded = false;

  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  int? _outletFilter;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _outlets = [];

  bool get _isAdmin => _userData?['id_outlet']?.toString() == '1';

  bool get _canForceDelete {
    if (_userData == null) return false;
    return _userData!['division_id']?.toString() == '13' ||
        _userData!['id_role']?.toString() == '5af56935b011a';
  }

  bool _canDelete(Map<String, dynamic> item) {
    if (_canForceDelete) return true;
    final status = item['status']?.toString() ?? '';
    return status == 'DRAFT' || status == 'REJECTED';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _init() async {
    final auth = AuthService();
    _userData = await auth.getUserData();
    if (_isAdmin) {
      _outlets = await _service.getOutlets();
    }
    if (mounted) setState(() {});
    _loadItems(isRefresh: true);
  }

  Future<void> _loadItems({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _items = [];
        _hasMore = true;
      });
    }

    setState(() => _isLoading = true);

    try {
      final res = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        outletId: _outletFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );

      final newItems = _extractList(res);

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _items = newItems;
          } else {
            _items.addAll(newItems);
          }
          _hasMore = newItems.length >= 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    final data = result['data'];
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> _loadMore() async {
    setState(() => _currentPage++);
    await _loadItems();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadItems(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _searchQuery = '';
      _dateFrom = null;
      _dateTo = null;
      _statusFilter = '';
      _outletFilter = null;
    });
    _loadItems(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await _service.deleteHeader(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message'] ?? 'Gagal menghapus')),
      );
      if (res?['success'] == true) _loadItems(isRefresh: true);
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LostBreakageDetailScreen(headerId: id),
      ),
    );
    if (result == true) _loadItems(isRefresh: true);
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LostBreakageFormScreen(),
      ),
    );
    if (result == true) _loadItems(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Lost & Breakage',
      showDrawer: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFFE65100)),
          tooltip: 'Report',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LostBreakageReportScreen()),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFFE65100),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Lost & Breakage', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadItems(isRefresh: true),
              child: _items.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length + (_hasMore && _isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFFE65100))),
                          );
                        }
                        return _buildItemCard(_items[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_dateFrom != null) count++;
    if (_dateTo != null) count++;
    if (_statusFilter.isNotEmpty) count++;
    if (_outletFilter != null) count++;
    return count;
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 20, color: Color(0xFFE65100)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ),
                  if (_activeFilterCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$_activeFilterCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  AnimatedRotation(
                    turns: _filterExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nomor, outlet, creator...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFE65100)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, _dateFromController),
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _dateFromController,
                              decoration: InputDecoration(
                                hintText: 'Dari tanggal',
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, _dateToController),
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _dateToController,
                              decoration: InputDecoration(
                                hintText: 'Sampai tanggal',
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isAdmin) ...[
                    InputDecorator(
                      decoration: InputDecoration(
                        hintText: 'Semua Outlet',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButton<int?>(
                        value: _outletFilter,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('Semua Outlet'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Semua Outlet')),
                          ..._outlets.map((o) {
                            final id = int.tryParse(o['id_outlet']?.toString() ?? '');
                            return DropdownMenuItem<int?>(
                              value: id,
                              child: Text(o['nama_outlet']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _outletFilter = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  InputDecorator(
                    decoration: InputDecoration(
                      hintText: 'Semua Status',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButton<String>(
                      value: _statusFilter.isEmpty ? null : _statusFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: const Text('Semua Status'),
                      items: const [
                        DropdownMenuItem<String>(value: null, child: Text('Semua Status')),
                        DropdownMenuItem<String>(value: 'DRAFT', child: Text('Draft')),
                        DropdownMenuItem<String>(value: 'SUBMITTED', child: Text('Menunggu Approval')),
                        DropdownMenuItem<String>(value: 'APPROVED', child: Text('Disetujui')),
                        DropdownMenuItem<String>(value: 'REJECTED', child: Text('Ditolak')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.filter_alt_rounded, size: 18),
                          label: const Text('Terapkan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          label: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _filterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final number = (item['number'] ?? '-').toString();
    final dateText = _formatDate(item['date']?.toString());
    final outletName = item['outlet_name']?.toString() ?? '-';
    final creatorName = item['creator_name']?.toString() ?? '-';
    final creatorAvatar = item['creator_avatar']?.toString();
    final notes = item['notes']?.toString();
    final status = (item['status'] ?? 'DRAFT').toString();
    final itemId = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final flows = (item['approval_flows'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return InkWell(
      onTap: itemId > 0 ? () => _navigateToDetail(itemId) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreatorBlock(creatorName, creatorAvatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          number,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  if (status == 'APPROVED') ...[
                    const SizedBox(height: 6),
                    _buildReplacementSummaryChip(item['replacement_summary']),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.store_rounded, size: 16, color: Color(0xFFE65100)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          outletName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.notes_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoPill(Icons.store_outlined, outletName),
                    ],
                  ),
                  if (flows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Approver',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    ...flows.map((f) => _buildApproverFlowRow(f)),
                  ],
                  if (_canDelete(item)) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => _delete(itemId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, size: 14, color: Color(0xFFB91C1C)),
                              SizedBox(width: 4),
                              Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C))),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildCreatorBlock(String name, String? avatarPath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCreatorAvatar(name, avatarPath),
        const SizedBox(height: 6),
        SizedBox(
          width: 52 * 2,
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorAvatar(String name, String? avatarPath) {
    final initials = _getInitials(name);
    final avatarUrl = _getAvatarUrl(avatarPath);
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
            )
          : null,
    );
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) {
      return '${AuthService.storageUrl}/$normalized';
    }
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildApproverFlowRow(Map<String, dynamic> flow) {
    final name = flow['approver_name']?.toString() ?? '-';
    final flowStatus = (flow['status'] ?? '').toString().toUpperCase();
    String statusLabel;
    Color statusColor;
    switch (flowStatus) {
      case 'APPROVED':
        statusLabel = 'Disetujui';
        statusColor = const Color(0xFF16A34A);
        break;
      case 'REJECTED':
        statusLabel = 'Ditolak';
        statusColor = const Color(0xFFDC2626);
        break;
      default:
        statusLabel = 'Menunggu';
        statusColor = const Color(0xFFB45309);
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacementSummaryChip(dynamic raw) {
    final s = raw?.toString() ?? 'none';
    String label;
    Color bg;
    Color fg;
    switch (s) {
      case 'complete':
        label = 'Pengganti: lengkap';
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        break;
      case 'partial':
        label = 'Pengganti: parsial';
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      default:
        label = 'Pengganti: belum';
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'DRAFT':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'Draft';
        break;
      case 'SUBMITTED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Menunggu Approval';
        break;
      case 'APPROVED':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        label = 'Disetujui';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Ditolak';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.broken_image_outlined, size: 42, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data Lost & Breakage',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Buat Lost & Breakage" untuk mulai',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
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
