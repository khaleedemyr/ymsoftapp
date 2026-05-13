import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_serial_receive_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'outlet_serial_receive_scan_screen.dart';
import 'outlet_serial_receive_detail_screen.dart';

class OutletSerialReceiveListScreen extends StatefulWidget {
  const OutletSerialReceiveListScreen({super.key});

  @override
  State<OutletSerialReceiveListScreen> createState() => _OutletSerialReceiveListScreenState();
}

class _OutletSerialReceiveListScreenState extends State<OutletSerialReceiveListScreen> {
  final OutletSerialReceiveService _service = OutletSerialReceiveService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _filterExpanded = false;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _outlets = [];
  bool _isHQ = false;
  bool _canDelete = false;
  String _outletName = '';
  String? _outletFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && _hasMore) _loadMore();
    }
  }

  Future<void> _init() async {
    final auth = AuthService();
    _userData = await auth.getUserData();
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
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        outletId: _outletFilter,
        dateFrom: _dateFromController.text.isNotEmpty ? _dateFromController.text : null,
        dateTo: _dateToController.text.isNotEmpty ? _dateToController.text : null,
        page: _currentPage,
        perPage: 20,
      );

      if (res != null) {
        _isHQ = res['is_hq'] == true;
        _canDelete = res['can_delete'] == true;
        _outletName = res['user_outlet']?['name'] ?? '';

        if (res['outlets'] is List) {
          _outlets = (res['outlets'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }

        final data = res['data'];
        List<Map<String, dynamic>> newItems = [];
        if (data is Map && data['data'] is List) {
          newItems = (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }

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
      } else {
        if (mounted) setState(() => _isLoading = false);
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
    await _loadItems();
  }

  void _applyFilters() {
    _loadItems(isRefresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _outletFilter = null;
    });
    _loadItems(isRefresh: true);
  }

  Future<void> _selectDate(TextEditingController controller) async {
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

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus GR Serial?'),
        content: Text('GR ${item['number']} akan dihapus dan inventory di-rollback.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await _service.delete(item['id']);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res?['message'] ?? 'Gagal menghapus'),
          backgroundColor: res?['success'] == true ? Colors.green : Colors.red,
        ),
      );
      if (res?['success'] == true) _loadItems(isRefresh: true);
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OutletSerialReceiveDetailScreen(headerId: id)),
    );
    if (result == true) _loadItems(isRefresh: true);
  }

  void _navigateToScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OutletSerialReceiveScanScreen()),
    );
    if (result == true) _loadItems(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'GR Nomor Seri',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToScan,
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text('Buat GR Serial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _items.length + (_hasMore && _isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF4F46E5))),
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
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_dateFromController.text.isNotEmpty) count++;
    if (_dateToController.text.isNotEmpty) count++;
    if (_outletFilter != null) count++;
    return count;
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
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
                  const Icon(Icons.filter_alt_rounded, size: 20, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ),
                  if (_activeFilterCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(999)),
                      child: Text('$_activeFilterCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_filterExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isHQ)
                    _buildDropdownFilter(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nomor GR...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateFromController,
                          readOnly: true,
                          onTap: () => _selectDate(_dateFromController),
                          decoration: InputDecoration(
                            hintText: 'Dari',
                            prefixIcon: const Icon(Icons.calendar_today, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dateToController,
                          readOnly: true,
                          onTap: () => _selectDate(_dateToController),
                          decoration: InputDecoration(
                            hintText: 'Sampai',
                            prefixIcon: const Icon(Icons.calendar_today, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _applyFilters,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Filter'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownFilter() {
    return DropdownButtonFormField<String>(
      value: _outletFilter,
      decoration: InputDecoration(
        hintText: 'Semua Outlet',
        prefixIcon: const Icon(Icons.store, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Semua Outlet')),
        ..._outlets.map((o) => DropdownMenuItem(
          value: o['id']?.toString(),
          child: Text(o['name'] ?? '', overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (v) => setState(() => _outletFilter = v),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Belum ada GR Serial', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Tap tombol di bawah untuk membuat', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final totalSerials = item['total_serials'] ?? 0;
    final receiveDate = item['receive_date'] ?? '';
    String formattedDate = '';
    if (receiveDate.isNotEmpty) {
      try {
        formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(receiveDate));
      } catch (_) {
        formattedDate = receiveDate;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _navigateToDetail(item['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['number'] ?? '-',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$totalSerials serial',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_isHQ && item['outlet_name'] != null) ...[
                      Icon(Icons.store_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(item['outlet_name'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(width: 16),
                    ],
                    Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item['created_by_name'] ?? '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_canDelete)
                      InkWell(
                        onTap: () => _deleteItem(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                              SizedBox(width: 4),
                              Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
