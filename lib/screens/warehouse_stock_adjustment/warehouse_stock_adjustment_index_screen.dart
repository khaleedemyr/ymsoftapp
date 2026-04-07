import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/approval_models.dart';
import '../../services/approval_service.dart';
import '../../services/auth_service.dart';
import '../../services/warehouse_stock_adjustment_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'warehouse_stock_adjustment_detail_screen.dart';
import 'warehouse_stock_adjustment_create_screen.dart';

class WarehouseStockAdjustmentIndexScreen extends StatefulWidget {
  const WarehouseStockAdjustmentIndexScreen({super.key});

  @override
  State<WarehouseStockAdjustmentIndexScreen> createState() =>
      _WarehouseStockAdjustmentIndexScreenState();
}

class _WarehouseStockAdjustmentIndexScreenState
    extends State<WarehouseStockAdjustmentIndexScreen> {
  final ApprovalService _approvalService = ApprovalService();
  final WarehouseStockAdjustmentService _listService = WarehouseStockAdjustmentService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<WarehouseStockAdjustmentApproval> _list = [];
  List<WarehouseStockAdjustmentApproval> _filteredList = [];
  bool _isLoading = true;
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
    final result = await _listService.getAdjustmentsList(
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
    final newItems = rawList.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final items = map['items'];
      map['items_count'] = items is List ? items.length : 0;
      return WarehouseStockAdjustmentApproval.fromJson(map);
    }).toList();
    setState(() {
      if (isRefresh || _currentPage == 1) {
        _list = newItems;
      } else {
        _list.addAll(newItems);
      }
      _hasMore = newItems.length >= _perPage && (result['current_page'] as int? ?? 1) < (result['last_page'] as int? ?? 1);
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
    final result = await _listService.getAdjustmentsList(
      page: _currentPage,
      from: from,
      to: to,
      search: search,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (result != null) {
      final rawList = result['data'] as List<dynamic>? ?? [];
      final newItems = rawList.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final items = map['items'];
        map['items_count'] = items is List ? items.length : 0;
        return WarehouseStockAdjustmentApproval.fromJson(map);
      }).toList();
      setState(() {
        _list.addAll(newItems);
        _hasMore = newItems.length >= _perPage && (result['current_page'] as int? ?? 1) < (result['last_page'] as int? ?? 1);
      });
    }
    setState(() => _loadingMore = false);
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    final dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
    final dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;

    _filteredList = _list.where((e) {
      if (dateFrom != null && (e.date == null || e.date!.compareTo(dateFrom) < 0)) return false;
      if (dateTo != null && (e.date == null || e.date!.compareTo(dateTo) > 0)) return false;
      if (q.isEmpty) return true;
      final number = (e.number).toLowerCase();
      final warehouse = (e.warehouseName ?? '').toLowerCase();
      final creator = (e.creatorName ?? '').toLowerCase();
      final reason = (e.reason ?? '').toLowerCase();
      return number.contains(q) ||
          warehouse.contains(q) ||
          creator.contains(q) ||
          reason.contains(q);
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _applyFilters();
    });
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime.now() : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        _applyFilters();
      });
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  Widget _buildStatusChip(String? status) {
    final normalized = (status ?? '').toLowerCase();
    Color bg;
    Color fg;
    switch (normalized) {
      case 'waiting_approval':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFF92400E);
        break;
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(normalized),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_approval':
        return 'Waiting Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isNotEmpty ? status : '-';
    }
  }

  Widget _buildTypeChip(String? type) {
    final normalized = (type ?? '').toLowerCase();
    final isIn = normalized == 'in';
    final bg = isIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = isIn ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final label = isIn ? 'Stock In' : 'Stock Out';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WarehouseStockAdjustmentDetailScreen(adjustmentId: id),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WarehouseStockAdjustmentCreateScreen(),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Warehouse Stock Adjustment',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Adjustment', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(isRefresh: true),
              child: _isLoading
                  ? const Center(
                      child: AppLoadingIndicator(size: 26, color: Color(0xFF6366F1)),
                    )
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
                                  child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)),
                                ),
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
              hintText: 'Cari nomor / gudang / pembuat...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() => _applyFilters()),
            onSubmitted: (_) => setState(() => _applyFilters()),
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
                    backgroundColor: const Color(0xFF6366F1),
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

  Widget _buildEmptyState() {
    String message;
    if (_errorMessage != null && _errorMessage!.isNotEmpty) {
      message = _errorMessage!;
    } else if (_list.isEmpty) {
      message = 'Belum ada data stock adjustment.\n\nGunakan tombol "Buat Adjustment" untuk membuat penyesuaian stok gudang.';
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
              _errorMessage != null ? Icons.error_outline : Icons.inbox,
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

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
  }

  /// Avatar creator: foto dari URL bila ada (sama seperti outlet stock adjustment), else inisial
  Widget _buildAvatar(WarehouseStockAdjustmentApproval item) {
    final name = item.creatorName ?? '-';
    final avatarRaw = item.creator != null ? item.creator!['avatar']?.toString() : null;
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

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) {
      return '${AuthService.storageUrl}/$normalized';
    }
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  Widget _buildCard(WarehouseStockAdjustmentApproval item) {
    final creatorName = item.creatorName ?? '-';
    return GestureDetector(
      onTap: () => _navigateToDetail(item.id),
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
            _buildAvatar(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.number,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      _buildTypeChip(item.type),
                      const SizedBox(width: 6),
                      _buildStatusChip(item.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(_formatDate(item.date), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Gudang', item.warehouseName ?? '-'),
                  _buildInfoRow('Dibuat', creatorName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
