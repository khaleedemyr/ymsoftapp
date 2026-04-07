import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_sale_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'warehouse_sale_detail_screen.dart';
import 'warehouse_sale_create_screen.dart';

class WarehouseSaleIndexScreen extends StatefulWidget {
  const WarehouseSaleIndexScreen({super.key});

  @override
  State<WarehouseSaleIndexScreen> createState() => _WarehouseSaleIndexScreenState();
}

class _WarehouseSaleIndexScreenState extends State<WarehouseSaleIndexScreen> {
  final WarehouseSaleService _service = WarehouseSaleService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  bool _canDelete = false;
  String? _errorMessage;
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
    final from = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
    final to = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    final search = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null;
    final result = await _service.getList(
      page: _currentPage,
      from: from,
      to: to,
      search: search,
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
    final from = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
    final to = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    final search = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null;
    final result = await _service.getList(
      page: _currentPage,
      from: from,
      to: to,
      search: search,
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

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
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

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WarehouseSaleDetailScreen(saleId: id),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WarehouseSaleCreateScreen(),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  Future<void> _confirmDelete(Map<String, dynamic> sale) async {
    final id = int.tryParse(sale['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final number = sale['number']?.toString() ?? '-';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus penjualan antar gudang?'),
        content: Text('Stok akan dikembalikan. Lanjutkan hapus $number?'),
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

  Widget _buildEmptyState() {
    String message;
    if (_errorMessage != null && _errorMessage!.isNotEmpty) {
      message = _errorMessage!;
    } else if (_list.isEmpty) {
      message = 'Belum ada penjualan antar gudang.\n\nGunakan tombol "Buat Penjualan" untuk membuat transaksi baru.';
    } else {
      message = 'Tidak ada hasil pencarian';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorMessage != null ? Icons.error_outline : Icons.warehouse_rounded,
              size: 72,
              color: _errorMessage != null ? Colors.orange : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: _errorMessage != null ? Colors.red.shade700 : Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> sale) {
    final id = int.tryParse(sale['id']?.toString() ?? '') ?? 0;
    final number = sale['number']?.toString() ?? '-';
    final date = sale['date']?.toString();
    final sourceName = sale['source_warehouse'] is Map
        ? (sale['source_warehouse'] as Map)['name']?.toString() ?? '-'
        : '-';
    final targetName = sale['target_warehouse'] is Map
        ? (sale['target_warehouse'] as Map)['name']?.toString() ?? '-'
        : '-';
    final totalItems = sale['total_items'] is int ? sale['total_items'] as int : int.tryParse(sale['total_items']?.toString() ?? '0') ?? 0;
    final creator = sale['creator'] is Map ? sale['creator'] as Map<String, dynamic>? : null;
    final creatorName = creator?['nama_lengkap']?.toString() ?? creator?['name']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();

    return GestureDetector(
      onTap: () => _navigateToDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE5E7EB),
                  backgroundImage: _getAvatarUrl(creatorAvatar) != null
                      ? CachedNetworkImageProvider(_getAvatarUrl(creatorAvatar)!)
                      : null,
                  child: _getAvatarUrl(creatorAvatar) == null
                      ? Text(
                          _getInitials(creatorName),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(_formatDate(date), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.warehouse_rounded, size: 14, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$sourceName → $targetName',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$totalItems item',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      if (_canDelete) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _confirmDelete(sale),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
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
      title: 'Penjualan Antar Gudang',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Penjualan', style: TextStyle(color: Colors.white)),
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
                    hintText: 'Cari nomor / gudang...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0EA5E9)),
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
          Expanded(
            child: _isLoading && _list.isEmpty
                ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9)))
                : RefreshIndicator(
                    onRefresh: () => _load(isRefresh: true),
                    child: _list.isEmpty
                        ? ListView(children: [_buildEmptyState()])
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
