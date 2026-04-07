import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/retail_warehouse_sale_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'retail_warehouse_sale_detail_screen.dart';
import 'retail_warehouse_sale_create_screen.dart';

class RetailWarehouseSaleIndexScreen extends StatefulWidget {
  const RetailWarehouseSaleIndexScreen({super.key});

  @override
  State<RetailWarehouseSaleIndexScreen> createState() =>
      _RetailWarehouseSaleIndexScreenState();
}

class _RetailWarehouseSaleIndexScreenState extends State<RetailWarehouseSaleIndexScreen> {
  final RetailWarehouseSaleService _service = RetailWarehouseSaleService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _filteredList = [];
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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
      _applyFilters();
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
        _applyFilters();
      });
    }
    setState(() => _loadingMore = false);
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredList = List.from(_list));
      return;
    }
    setState(() {
      _filteredList = _list.where((e) {
        final number = (e['number'] ?? '').toString().toLowerCase();
        final customer = (e['customer_name'] ?? '').toString().toLowerCase();
        final warehouse = (e['warehouse_name'] ?? '').toString().toLowerCase();
        return number.contains(q) || customer.contains(q) || warehouse.contains(q);
      }).toList();
    });
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
      initialDate: controller.text.isNotEmpty
          ? (DateTime.tryParse(controller.text) ?? DateTime.now())
          : DateTime.now(),
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

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
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

  Widget _buildCreatorAvatar(Map<String, dynamic> sale) {
    final name = sale['created_by_name']?.toString() ?? '-';
    final avatarRaw = sale['created_by_avatar']?.toString();
    final avatarUrl = _getAvatarUrl(avatarRaw);
    final initials = _getInitials(name);
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

  Widget _buildStatusChip(String? status) {
    final s = (status ?? '').toString();
    Color bg;
    Color fg;
    String label;
    if (s == 'completed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      label = 'Selesai';
    } else if (s == 'draft') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFCA8A04);
      label = 'Draft';
    } else if (s == 'cancelled') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Dibatalkan';
    } else {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade700;
      label = s.isEmpty ? '-' : s;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailWarehouseSaleDetailScreen(saleId: id),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RetailWarehouseSaleCreateScreen(),
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
        title: const Text('Hapus penjualan?'),
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
      message =
          'Belum ada data penjualan warehouse retail.\n\nGunakan tombol "Buat Penjualan" untuk membuat penjualan baru.';
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
              _errorMessage != null ? Icons.error_outline : Icons.shopping_cart_outlined,
              size: 72,
              color: _errorMessage != null ? Colors.orange : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: _errorMessage != null ? Colors.red.shade700 : Colors.grey.shade600,
              ),
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
    final customerName = sale['customer_name']?.toString() ?? '-';
    final customerCode = sale['customer_code']?.toString();
    final warehouseName = sale['warehouse_name']?.toString() ?? '-';
    final divisionName = sale['division_name']?.toString();
    final totalAmount = sale['total_amount'];
    final status = sale['status']?.toString();
    final createdAt = sale['created_at']?.toString();
    final creatorName = sale['created_by_name']?.toString() ?? '-';

    return GestureDetector(
      onTap: () => _navigateToDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreatorAvatar(sale),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Customer', customerName, sub: customerCode),
                  _buildInfoRow('Gudang', warehouseName, sub: divisionName),
                  _buildInfoRow('Dibuat', creatorName),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(
                        _formatMoney(totalAmount),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor, customer, gudang...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _load(isRefresh: true),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _load(isRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Terapkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Penjualan Warehouse Retail',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Penjualan', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(isRefresh: true),
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB)))
                  : _filteredList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filteredList.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _filteredList.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: AppLoadingIndicator(size: 24, color: Color(0xFF2563EB))),
                              );
                            }
                            return _buildCard(_filteredList[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
