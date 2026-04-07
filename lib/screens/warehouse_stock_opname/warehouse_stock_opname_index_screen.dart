import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_stock_opname_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'warehouse_stock_opname_detail_screen.dart';
import 'warehouse_stock_opname_form_screen.dart';

class WarehouseStockOpnameIndexScreen extends StatefulWidget {
  const WarehouseStockOpnameIndexScreen({super.key});

  @override
  State<WarehouseStockOpnameIndexScreen> createState() => _WarehouseStockOpnameIndexScreenState();
}

class _WarehouseStockOpnameIndexScreenState extends State<WarehouseStockOpnameIndexScreen> {
  final WarehouseStockOpnameService _service = WarehouseStockOpnameService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  String _status = 'all';
  int? _warehouseIdFilter;
  String? _dateFrom;
  String? _dateTo;
  bool _filterExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCreateData();
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
      if (!_isLoading && _hasMore) _loadMore();
    }
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _warehouses = result['warehouses'] != null && result['warehouses'] is List
            ? List<Map<String, dynamic>>.from((result['warehouses'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
            : [];
      });
    }
    _loadList(isRefresh: true);
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    var data = result['data'];
    if (data is List) {
      return data.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
    }
    return [];
  }

  Future<void> _loadList({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _list = [];
        _hasMore = true;
      });
    }
    setState(() => _isLoading = true);
    try {
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: _status != 'all' ? _status : null,
        warehouseId: _warehouseIdFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );
      final newList = _extractList(result);
      if (result != null && _warehouses.isEmpty && result['warehouses'] is List) {
        _warehouses = List<Map<String, dynamic>>.from((result['warehouses'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}));
      }
      if (mounted) {
        setState(() {
          if (isRefresh) _list = newList;
          else _list.addAll(newList);
          _hasMore = newList.length >= 20;
          _isLoading = false;
        });
        if (result != null && result['success'] != true && result['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'].toString()), backgroundColor: Colors.orange));
        } else if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat data. Cek koneksi atau login.'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _currentPage++);
    await _loadList();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadList(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _status = 'all';
      _warehouseIdFilter = null;
      _searchQuery = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadList(isRefresh: true);
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  Color _statusColor(String? s) {
    if (s == null) return Colors.grey;
    switch (s) {
      case 'DRAFT': return const Color(0xFF94A3B8);
      case 'SUBMITTED': return const Color(0xFFF59E0B);
      case 'APPROVED': return const Color(0xFF059669);
      case 'REJECTED': return const Color(0xFFDC2626);
      case 'COMPLETED': return const Color(0xFF2563EB);
      default: return Colors.grey;
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WarehouseStockOpnameDetailScreen(opnameId: id)),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  void _navigateToForm({int? editId}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WarehouseStockOpnameFormScreen(editId: editId)),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: c.text.isNotEmpty ? DateTime.tryParse(c.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => c.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Warehouse Stock Opname',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Stock Opname', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadList(isRefresh: true),
              child: _list.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _list.length + (_hasMore && _isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _list.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF2563EB))),
                          );
                        }
                        return _buildCard(_list[index]);
                      },
                    ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari no. opname, catatan...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _filterExpanded = !_filterExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_filterExpanded ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, size: 20, color: const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(_filterExpanded ? 'Sembunyikan filter' : 'Tampilkan filter', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    const Spacer(),
                    Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    DropdownMenuItem(value: 'SUBMITTED', child: Text('Submitted')),
                    DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: _warehouseIdFilter,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: [const DropdownMenuItem<int?>(value: null, child: Text('Semua Gudang'))]
                      ..addAll(_warehouses.map((w) {
                        final id = w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '');
                        return DropdownMenuItem<int?>(value: id, child: Text(w['name']?.toString() ?? '-'));
                      })),
                  onChanged: (v) => setState(() => _warehouseIdFilter = v),
                ),
                const SizedBox(height: 8),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
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
                      child: OutlinedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Terapkan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            crossFadeState: _filterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Belum ada data warehouse stock opname', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => _navigateToForm(), icon: const Icon(Icons.add), label: const Text('Buat Stock Opname')),
        ],
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
          child: Text(name, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
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
      child: avatarUrl == null ? Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))) : null,
    );
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) return '${AuthService.storageUrl}/$normalized';
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    final opnameNumber = (item['opname_number'] ?? '-').toString();
    final opnameDate = item['opname_date']?.toString();
    final warehouse = item['warehouse'] as Map<String, dynamic>?;
    final division = item['warehouse_division'] as Map<String, dynamic>?;
    final warehouseName = warehouse?['name']?.toString() ?? '-';
    final divisionName = division?['name']?.toString();
    final status = item['status']?.toString();
    final creator = item['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: id != null && id != 0 ? () => _navigateToDetail(id!) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Expanded(child: Text(opnameNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(status ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Gudang: $warehouseName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    if (divisionName != null && divisionName.isNotEmpty) Text('Divisi: $divisionName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('Tanggal: ${_formatDate(opnameDate)}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
