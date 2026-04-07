import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/outlet_rejection_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'outlet_rejection_detail_screen.dart';
import 'outlet_rejection_create_screen.dart';

class OutletRejectionIndexScreen extends StatefulWidget {
  const OutletRejectionIndexScreen({super.key});

  @override
  State<OutletRejectionIndexScreen> createState() => _OutletRejectionIndexScreenState();
}

class _OutletRejectionIndexScreenState extends State<OutletRejectionIndexScreen> {
  final OutletRejectionService _service = OutletRejectionService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = true;
  bool _canDelete = false;
  String? _errorMessage;
  int? _filterOutletId;
  int? _filterWarehouseId;
  String? _filterStatus;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _list = [];
        _hasMore = true;
        _errorMessage = null;
      });
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _service.getList(
      page: _currentPage,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      status: _filterStatus,
      outletId: _filterOutletId,
      warehouseId: _filterWarehouseId,
      dateFrom: _dateFromController.text.isNotEmpty ? _dateFromController.text : null,
      dateTo: _dateToController.text.isNotEmpty ? _dateToController.text : null,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _errorMessage = 'Gagal memuat data';
        _isLoading = false;
      });
      return;
    }
    final rawList = result['data'] as List<dynamic>? ?? [];
    final newItems = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() {
      if (isRefresh || _currentPage == 1) {
        _list = newItems;
      } else {
        _list.addAll(newItems);
      }
      _canDelete = result['can_delete'] == true;
      if (result['outlets'] is List) {
        _outlets = (result['outlets'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (result['warehouses'] is List) {
        _warehouses = (result['warehouses'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      _hasMore = newItems.length >= _perPage &&
          (result['current_page'] as int? ?? 1) < (result['last_page'] as int? ?? 1);
      _errorMessage = null;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _currentPage++;
    final result = await _service.getList(
      page: _currentPage,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      status: _filterStatus,
      outletId: _filterOutletId,
      warehouseId: _filterWarehouseId,
      dateFrom: _dateFromController.text.isNotEmpty ? _dateFromController.text : null,
      dateTo: _dateToController.text.isNotEmpty ? _dateToController.text : null,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (result != null) {
      final rawList = result['data'] as List<dynamic>? ?? [];
      final newItems = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _list.addAll(newItems);
        _hasMore = newItems.length >= _perPage &&
            (result['current_page'] as int? ?? 1) < (result['last_page'] as int? ?? 1);
      });
    }
    setState(() => _loadingMore = false);
  }

  void _applyFilters() {
    _load(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _filterStatus = null;
      _filterOutletId = null;
      _filterWarehouseId = null;
    });
    _load(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? (DateTime.tryParse(controller.text) ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'draft': return 'Draft';
      case 'submitted': return 'Submitted';
      case 'approved': return 'Approved';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Dibatalkan';
      case 'rejected': return 'Ditolak';
      default: return s ?? '-';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed': return const Color(0xFF16A34A);
      case 'draft': return const Color(0xFFCA8A04);
      case 'cancelled': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return const Color(0xFF0EA5E9);
    }
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Creator: support creator / created_by / createdBy (API may return camelCase or snake_case).
  Map<String, dynamic>? _getCreator(Map<String, dynamic> row) {
    final c = row['creator'] ?? row['created_by'] ?? row['createdBy'];
    if (c is Map) return Map<String, dynamic>.from(c);
    return null;
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

  /// Daftar approver yang belum approve (untuk status submitted).
  List<String> _pendingApprovers(Map<String, dynamic> row) {
    final status = row['status']?.toString();
    if (status != 'submitted') return [];
    final info = row['approval_info'];
    if (info is! Map) return [];
    final m = Map<String, dynamic>.from(info);
    final assistant = m['assistant_ssd_manager']?.toString().trim();
    final ssd = m['ssd_manager']?.toString().trim();
    final list = <String>[];
    if (assistant == null || assistant.isEmpty) list.add('Asisten SSD Manager');
    if (ssd == null || ssd.isEmpty) list.add('SSD Manager');
    return list;
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletRejectionDetailScreen(rejectionId: id),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutletRejectionCreateScreen(),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = _int(row['id']) ?? 0;
    if (id <= 0) return;
    final number = row['number']?.toString() ?? '-';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Outlet Rejection?'),
        content: Text('Lanjutkan hapus $number? Hanya status draft yang dapat dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _service.delete(id);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil dihapus'), backgroundColor: Colors.green),
      );
      _load(isRefresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal menghapus'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCard(Map<String, dynamic> row) {
    final id = _int(row['id']) ?? 0;
    final number = row['number']?.toString() ?? '-';
    final date = row['rejection_date']?.toString();
    final status = row['status']?.toString();
    final outlet = row['outlet'] is Map ? (row['outlet'] as Map)['nama_outlet']?.toString() ?? '-' : '-';
    final warehouse = row['warehouse'] is Map ? (row['warehouse'] as Map)['name']?.toString() ?? '-' : '-';
    final creator = _getCreator(row);
    final creatorName = creator?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();
    final pending = _pendingApprovers(row);

    return GestureDetector(
      onTap: () => _navigateToDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(_formatDate(date), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Outlet: $outlet', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('Gudang: $warehouse', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.pending_actions, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Menunggu: ${pending.join(', ')}',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_canDelete && status == 'draft') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _confirmDelete(row),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Outlet Rejection',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Rejection', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor, outlet, gudang...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0EA5E9)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Status')),
                    const DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    const DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                    const DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    const DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _dateFromController),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _dateFromController,
                            decoration: InputDecoration(
                              hintText: 'Dari',
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _dateToController),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _dateToController,
                            decoration: InputDecoration(
                              hintText: 'Sampai',
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.filter_alt_rounded, size: 18),
                        label: const Text('Terapkan'),
                      ),
                    ),
                    const SizedBox(width: 10),
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
          Expanded(
            child: _isLoading && _list.isEmpty
                ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9)))
                : RefreshIndicator(
                    onRefresh: () => _load(isRefresh: true),
                    child: _list.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 200,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.undo_rounded, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      Text(
                                        _errorMessage ?? 'Belum ada Outlet Rejection',
                                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _list.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _list.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF0EA5E9))),
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
}
