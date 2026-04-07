import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/outlet_stock_adjustment_models.dart';
import '../../services/outlet_stock_adjustment_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../services/auth_service.dart';
import 'outlet_stock_adjustment_create_screen.dart';
import 'outlet_stock_adjustment_detail_screen.dart';

class OutletStockAdjustmentIndexScreen extends StatefulWidget {
  const OutletStockAdjustmentIndexScreen({super.key});

  @override
  State<OutletStockAdjustmentIndexScreen> createState() => _OutletStockAdjustmentIndexScreenState();
}

class _OutletStockAdjustmentIndexScreenState extends State<OutletStockAdjustmentIndexScreen> {
  final OutletStockAdjustmentService _service = OutletStockAdjustmentService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<OutletStockAdjustmentListItem> _adjustments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _errorMessage;

  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadAdjustments();
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
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadAdjustments({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _adjustments = [];
        _hasMore = true;
        _errorMessage = null;
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getAdjustments(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        perPage: 20,
      );

      if (result != null && mounted) {
        final data = result['data'] ?? result;
        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map && data['data'] is List) {
          rawList = data['data'] as List;
        }

        final newItems = rawList
            .map((item) => OutletStockAdjustmentListItem.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          if (isRefresh) {
            _adjustments = newItems;
          } else {
            _adjustments.addAll(newItems);
          }
          _hasMore = newItems.length >= 20;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _currentPage++;
    });
    await _loadAdjustments();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text;
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadAdjustments(isRefresh: true);
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
    _loadAdjustments(isRefresh: true);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.parse(controller.text) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _navigateToDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletStockAdjustmentDetailScreen(adjustmentId: id),
      ),
    );
    if (result == true) {
      _loadAdjustments(isRefresh: true);
    }
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutletStockAdjustmentCreateScreen(),
      ),
    );
    if (result == true) {
      _loadAdjustments(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Outlet Stock Adjustment',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Adjustment', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadAdjustments(isRefresh: true),
              child: _adjustments.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _adjustments.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _adjustments.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)),
                            ),
                          );
                        }
                        return _buildAdjustmentCard(_adjustments[index]);
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
              hintText: 'Cari nomor / outlet / pembuat...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
                  onPressed: _applyFilters,
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

  Widget _buildAdjustmentCard(OutletStockAdjustmentListItem item) {
    final number = item.number;
    final dateText = _formatDate(item.date);
    final outlet = item.outletName ?? '-';
    final warehouse = item.warehouseOutletName ?? '-';
    final creator = item.creatorName ?? '-';

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
                          number,
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
                      Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Outlet', outlet),
                  _buildInfoRow('Warehouse', warehouse),
                  _buildInfoRow('Dibuat', creator),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(OutletStockAdjustmentListItem item) {
    final name = item.creatorName ?? '-';
    final avatarUrl = _getAvatarUrl(item.creatorAvatar);
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

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
      case 'waiting_cost_control':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
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

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_approval':
        return 'Waiting Approval';
      case 'waiting_cost_control':
        return 'Waiting Cost Control';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isNotEmpty ? status : '-';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  Widget _buildEmptyState() {
    final message = _errorMessage ?? 'Belum ada outlet stock adjustment';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
