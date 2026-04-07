import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/retail_warehouse_food_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'retail_warehouse_food_detail_screen.dart';
import 'retail_warehouse_food_create_screen.dart';

class RetailWarehouseFoodIndexScreen extends StatefulWidget {
  const RetailWarehouseFoodIndexScreen({super.key});

  @override
  State<RetailWarehouseFoodIndexScreen> createState() =>
      _RetailWarehouseFoodIndexScreenState();
}

class _RetailWarehouseFoodIndexScreenState extends State<RetailWarehouseFoodIndexScreen> {
  final RetailWarehouseFoodService _service = RetailWarehouseFoodService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _paymentMethodFilter; // null = all, cash, contra_bon
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
    final dateFrom = _dateFromController.text.trim().isNotEmpty ? _dateFromController.text : null;
    final dateTo = _dateToController.text.trim().isNotEmpty ? _dateToController.text : null;
    final search = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null;
    final result = await _service.getList(
      page: _currentPage,
      dateFrom: dateFrom,
      dateTo: dateTo,
      search: search,
      paymentMethod: _paymentMethodFilter,
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
    final dateFrom = _dateFromController.text.trim().isNotEmpty ? _dateFromController.text : null;
    final dateTo = _dateToController.text.trim().isNotEmpty ? _dateToController.text : null;
    final search = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null;
    final result = await _service.getList(
      page: _currentPage,
      dateFrom: dateFrom,
      dateTo: dateTo,
      search: search,
      paymentMethod: _paymentMethodFilter,
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

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _paymentMethodFilter = null;
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
    if (picked != null && mounted) {
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

  Widget _buildCreatorAvatar(Map<String, dynamic> row) {
    final name = row['created_by_name']?.toString() ?? '-';
    final avatarRaw = row['created_by_avatar']?.toString();
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

  String _paymentMethodLabel(String? v) {
    if (v == null || v.isEmpty) return '-';
    if (v == 'cash') return 'Cash';
    if (v == 'contra_bon') return 'Contra Bon';
    return v;
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailWarehouseFoodDetailScreen(id: id),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RetailWarehouseFoodCreateScreen(),
      ),
    );
    if (result == true && mounted) _load(isRefresh: true);
  }

  Widget _buildEmptyState() {
    String message;
    if (_errorMessage != null && _errorMessage!.isNotEmpty) {
      message = _errorMessage!;
    } else if (_list.isEmpty) {
      message =
          'Belum ada data Warehouse Retail Food.\n\nGunakan tombol "Buat Transaksi" untuk menambah transaksi baru.';
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
              _errorMessage != null ? Icons.error_outline : Icons.warehouse_outlined,
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

  Widget _buildCard(Map<String, dynamic> row) {
    final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
    final retailNumber = row['retail_number']?.toString() ?? '-';
    final warehouseName = row['warehouse_name']?.toString() ?? '-';
    final divisionName = row['warehouse_division_name']?.toString();
    final supplierName = row['supplier_name']?.toString();
    final totalAmount = row['total_amount'];
    final paymentMethod = row['payment_method']?.toString();
    final transactionDate = row['transaction_date']?.toString();
    final createdAt = row['created_at']?.toString();
    final creatorName = row['created_by_name']?.toString() ?? '-';

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
            _buildCreatorAvatar(row),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          retailNumber,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: paymentMethod == 'contra_bon'
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _paymentMethodLabel(paymentMethod),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: paymentMethod == 'contra_bon'
                                ? const Color(0xFFB45309)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(transactionDate ?? createdAt),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Gudang', warehouseName, sub: divisionName),
                  if (supplierName != null && supplierName.isNotEmpty)
                    _buildInfoRow('Supplier', supplierName),
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
              hintText: 'Cari nomor, gudang, supplier...',
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
                child: DropdownButtonFormField<String?>(
                  value: _paymentMethodFilter,
                  decoration: InputDecoration(
                    labelText: 'Pembayaran',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Semua')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'contra_bon', child: Text('Contra Bon')),
                  ],
                  onChanged: (v) {
                    setState(() => _paymentMethodFilter = v);
                  },
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
      title: 'Warehouse Retail Food',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Transaksi', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(isRefresh: true),
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF2563EB)))
                  : _list.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _list.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _list.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: AppLoadingIndicator(size: 24, color: Color(0xFF2563EB))),
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
