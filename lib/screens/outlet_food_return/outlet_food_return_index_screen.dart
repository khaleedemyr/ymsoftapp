import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/outlet_food_return_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'outlet_food_return_detail_screen.dart';
import 'outlet_food_return_form_screen.dart';

class OutletFoodReturnIndexScreen extends StatefulWidget {
  const OutletFoodReturnIndexScreen({super.key});

  @override
  State<OutletFoodReturnIndexScreen> createState() => _OutletFoodReturnIndexScreenState();
}

class _OutletFoodReturnIndexScreenState extends State<OutletFoodReturnIndexScreen> {
  final OutletFoodReturnService _service = OutletFoodReturnService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _total = 0;
  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;
  bool _filterExpanded = false;
  bool _canDelete = false;
  int? _deletingId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadList(isRefresh: true);
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

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    final data = result['data'];
    if (data == null) return [];
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
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
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );
      final newList = _extractList(result);
      final canDelete = result != null && result['can_delete'] == true;
      final total = result != null && result['total'] is int ? result['total'] as int : 0;
      if (mounted) {
        setState(() {
          if (isRefresh) _list = newList;
          else _list.addAll(newList);
          _hasMore = newList.length >= 20;
          _isLoading = false;
          _canDelete = canDelete;
          if (total > 0) _total = total;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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
      _searchQuery = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadList(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
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
      return v ?? '-';
    }
  }

  String _statusLabel(String? s) {
    if (s == null) return '-';
    if (s == 'pending') return 'Pending';
    if (s == 'approved') return 'Disetujui';
    return s;
  }

  Color _statusColor(String? s) {
    if (s == 'approved') return const Color(0xFF059669);
    return const Color(0xFFF59E0B);
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletFoodReturnDetailScreen(returnId: id),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutletFoodReturnFormScreen(),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id'] is int ? row['id'] as int : int.tryParse(row['id']?.toString() ?? '');
    final number = (row['return_number'] ?? '-').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Return?'),
        content: Text('Yakin ingin menghapus return $number?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || id == null || id == 0) return;
    final idToDelete = id!;
    setState(() => _deletingId = idToDelete);
    final result = await _service.delete(idToDelete);
    if (mounted) {
      setState(() => _deletingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true ? (result['message']?.toString() ?? 'Berhasil dihapus') : (result['message']?.toString() ?? 'Gagal menghapus')),
          backgroundColor: result['success'] == true ? null : Colors.red,
        ),
      );
      if (result['success'] == true) _loadList(isRefresh: true);
    }
  }

  static const _orange = Color(0xFFEA580C);
  static const _orangeLight = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Outlet Food Return',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: _orange,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Return', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          if (_list.isNotEmpty || _total > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _orangeLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: _orange),
                  const SizedBox(width: 8),
                  Text(
                    'Menampilkan ${_list.length} dari $_total return',
                    style: TextStyle(fontSize: 13, color: _orange.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
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
                            child: Center(child: AppLoadingIndicator(size: 24, color: _orange)),
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
              hintText: 'Cari no. return, no. GR, outlet...',
              prefixIcon: const Icon(Icons.search, color: _orange),
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
                    Icon(
                      _filterExpanded ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                      size: 20,
                      color: _orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _filterExpanded ? 'Sembunyikan filter' : 'Tampilkan filter',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _orange),
                    ),
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
                const SizedBox(height: 4),
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
                          foregroundColor: _orange,
                          side: const BorderSide(color: _orange),
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Belum ada data return', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _navigateToForm,
            icon: const Icon(Icons.add),
            label: const Text('Buat Return'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    final returnNumber = (item['return_number'] ?? '-').toString();
    final returnDate = item['return_date']?.toString();
    final grNumber = (item['gr_number'] ?? '-').toString();
    final outletName = (item['nama_outlet'] ?? '-').toString();
    final warehouseName = (item['warehouse_outlet_name'] ?? '-').toString();
    final status = item['status']?.toString();
    final createdByName = (item['created_by_name'] ?? '-').toString();
    final createdByAvatar = item['created_by_avatar']?.toString();
    final isDeleting = _deletingId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: id != null && !isDeleting ? () => _navigateToDetail(id) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCreatorBlock(createdByName, createdByAvatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            returnNumber,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('GR: $grNumber', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('Outlet: $outletName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    if (warehouseName.isNotEmpty) Text('Gudang: $warehouseName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('Tanggal: ${_formatDate(returnDate)}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    if (_canDelete) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: isDeleting ? null : () => _confirmDelete(item),
                          icon: isDeleting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          label: Text(isDeleting ? 'Menghapus...' : 'Hapus', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
}
