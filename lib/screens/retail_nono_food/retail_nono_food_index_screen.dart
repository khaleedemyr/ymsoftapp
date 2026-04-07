import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/retail_nono_food_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'retail_nono_food_detail_screen.dart';
import 'retail_nono_food_form_screen.dart';

class RetailNonoFoodIndexScreen extends StatefulWidget {
  const RetailNonoFoodIndexScreen({super.key});

  @override
  State<RetailNonoFoodIndexScreen> createState() => _RetailNonoFoodIndexScreenState();
}

class _RetailNonoFoodIndexScreenState extends State<RetailNonoFoodIndexScreen> {
  final RetailNonFoodService _service = RetailNonFoodService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;
  int? _outletId;
  int? _userOutletId;
  bool _filterExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && _hasMore) _loadMore();
    }
  }

  Future<void> _loadOutlets() async {
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _outlets = result['outlets'] != null
            ? List<Map<String, dynamic>>.from(result['outlets'] as List)
            : [];
        _userOutletId = result['user_outlet_id'] is int
            ? result['user_outlet_id'] as int
            : int.tryParse(result['user_outlet_id']?.toString() ?? '');
      });
      _loadList(isRefresh: true);
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? result) {
    if (result == null) return [];
    final data = result['data'];
    if (data == null) return [];
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
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
      final effectiveOutletId = (_userOutletId != null && _userOutletId != 1)
          ? _userOutletId
          : _outletId;
      final result = await _service.getList(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        outletId: effectiveOutletId,
        page: _currentPage,
        perPage: 20,
      );
      final newList = _extractList(result);
      if (mounted) {
        setState(() {
          if (isRefresh) _list = newList;
          else _list.addAll(newList);
          _hasMore = newList.length >= 20;
          _isLoading = false;
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
      _outletId = null;
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
      return v;
    }
  }

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailNonoFoodDetailScreen(retailNonFoodId: id),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RetailNonoFoodFormScreen(),
      ),
    );
    if (result == true) _loadList(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Retail Non Food',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFF16A34A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Retail Non Food', style: TextStyle(color: Colors.white)),
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
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF16A34A))),
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
              hintText: 'Cari no. transaksi, outlet, supplier...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF16A34A)),
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
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _filterExpanded ? 'Sembunyikan filter' : 'Tampilkan filter',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
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
                if (_userOutletId == 1 || _userOutletId == null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _outletId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Outlet',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Semua outlet')),
                      ..._outlets.map((o) {
                        final id = o['id_outlet'] ?? o['id'];
                        final rawId = id is int ? id : int.tryParse(id?.toString() ?? '0');
                        final outletId = rawId ?? 0;
                        final name = o['nama_outlet']?.toString() ?? o['name']?.toString() ?? '-';
                        return DropdownMenuItem<int>(
                          value: outletId,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _outletId = v),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
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
          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada data retail non food',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _navigateToForm,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah Retail Non Food'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final retailNumber = (item['retail_number'] ?? '-').toString();
    final dateText = _formatDate(item['transaction_date']?.toString());
    final outletName = item['outlet']?['nama_outlet']?.toString();
    final categoryName = item['category_budget']?['name']?.toString() ?? '-';
    final supplierName = item['supplier']?['name']?.toString() ?? '-';
    final totalAmount = item['total_amount'];
    final creator = item['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['nama_lengkap']?.toString() ?? creator?['name']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '0') ?? 0;

    return InkWell(
      onTap: id > 0 ? () => _navigateToDetail(id) : null,
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
                          retailNumber,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  if (outletName != null && outletName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.store_rounded, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(outletName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('Kategori: $categoryName', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (supplierName.isNotEmpty && supplierName != '-')
                    Text('Supplier: $supplierName', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(_formatMoney(totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
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
}
