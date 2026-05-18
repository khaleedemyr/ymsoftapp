import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Filter',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(999)),
                            child: Text('$_activeFilterCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
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
      isExpanded: true,
      isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
      decoration: InputDecoration(
        hintText: 'Semua Outlet',
        prefixIcon: const Icon(Icons.store_outlined, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      selectedItemBuilder: (context) => [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Semua Outlet', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        ..._outlets.map(
          (o) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              o['name']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Semua Outlet', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        ..._outlets.map((o) => DropdownMenuItem(
              value: o['id']?.toString(),
              child: Text(
                o['name']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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

    final creatorName = (item['created_by_name'] ?? '-').toString();
    final avatarPath = item['created_by_avatar']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDetail(item['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCreatorBlock(creatorName, avatarPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['number'] ?? '-',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          if (_canDelete) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Color(0xFFDC2626)),
                              tooltip: 'Hapus',
                              onPressed: () => _deleteItem(item),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(formattedDate, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      if (_isHQ && item['outlet_name'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.store_rounded, size: 16, color: Color(0xFF6366F1)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['outlet_name'].toString(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
