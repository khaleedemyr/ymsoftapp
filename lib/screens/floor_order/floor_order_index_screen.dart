import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/floor_order_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'floor_order_form_screen.dart';
import 'floor_order_detail_screen.dart';
import '../../services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FloorOrderIndexScreen extends StatefulWidget {
  const FloorOrderIndexScreen({super.key});

  @override
  State<FloorOrderIndexScreen> createState() => _FloorOrderIndexScreenState();
}

class _FloorOrderIndexScreenState extends State<FloorOrderIndexScreen> {
  final FloorOrderService _service = FloorOrderService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  String _selectedStatus = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<dynamic> _orders = [];
  Map<String, dynamic> _pagination = {};
  int _currentPage = 1;
  int _perPage = 10;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dateFrom = today;
    _dateTo = today;
    _dateFromController.text = DateFormat('yyyy-MM-dd').format(today);
    _dateToController.text = DateFormat('yyyy-MM-dd').format(today);
    _loadData();
    _scrollController.addListener(_onScroll);
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (isRefresh) {
        _currentPage = 1;
        _orders = [];
        _hasMore = true;
      }
    });

    try {
      final result = await _service.getFloorOrders(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        startDate: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        endDate: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        page: _currentPage,
        perPage: _perPage,
      );

      if (!mounted) return;

      if (result != null) {
        if (result['data'] is List) {
          final data = List<dynamic>.from(result['data'] as List);
          final currentPage = result['current_page'] ?? _currentPage;
          final lastPage = result['last_page'] ?? currentPage;

          setState(() {
            if (currentPage == 1) {
              _orders = data;
            } else {
              _orders.addAll(data);
            }
            _pagination = {
              'current_page': currentPage,
              'last_page': lastPage,
              'per_page': result['per_page'] ?? _perPage,
              'total': result['total'] ?? 0,
            };
            _hasMore = currentPage < lastPage;
            _isLoading = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _orders = [];
            _pagination = {};
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = 'Format data tidak dikenali';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage += 1;
    });
    await _loadData();
  }

  Future<void> _selectDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked;
        _dateFromController.text = DateFormat('yyyy-MM-dd').format(picked);
        _currentPage = 1;
      });
      _loadData(isRefresh: true);
    }
  }

  Future<void> _selectDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateTo = picked;
        _dateToController.text = DateFormat('yyyy-MM-dd').format(picked);
        _currentPage = 1;
      });
      _loadData(isRefresh: true);
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = '';
      final today = DateTime.now();
      _dateFrom = today;
      _dateTo = today;
      _dateFromController.text = DateFormat('yyyy-MM-dd').format(today);
      _dateToController.text = DateFormat('yyyy-MM-dd').format(today);
      _currentPage = 1;
      _hasMore = true;
    });
    _loadData(isRefresh: true);
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final numValue = amount is String
        ? (double.tryParse(amount) ?? 0.0)
        : (amount is num ? amount.toDouble() : 0.0);
    return 'Rp ${NumberFormat('#,###').format(numValue)}';
  }

  String _getCreatorName(Map<String, dynamic> order) {
    final requester = order['requester'] as Map<String, dynamic>?;
    final creator = order['creator'] as Map<String, dynamic>?;
    final createdBy = order['created_by'] as Map<String, dynamic>?;
    final user = order['user'] as Map<String, dynamic>?;
    return requester?['nama_lengkap']?.toString() ??
        requester?['name']?.toString() ??
        requester?['nama']?.toString() ??
        creator?['name']?.toString() ??
        creator?['nama']?.toString() ??
        createdBy?['name']?.toString() ??
        createdBy?['nama']?.toString() ??
        order['created_by_name']?.toString() ??
        user?['name']?.toString() ??
        user?['nama']?.toString() ??
        order['requested_by']?.toString() ??
        '-';
  }

  String? _getCreatorAvatar(Map<String, dynamic> order) {
    final requester = order['requester'] as Map<String, dynamic>?;
    final creator = order['creator'] as Map<String, dynamic>?;
    final createdBy = order['created_by'] as Map<String, dynamic>?;
    final user = order['user'] as Map<String, dynamic>?;
    final raw = requester?['avatar']?.toString() ??
        requester?['photo_url']?.toString() ??
        requester?['upload_latest_color_photo']?.toString() ??
        creator?['avatar']?.toString() ??
        creator?['photo_url']?.toString() ??
        createdBy?['avatar']?.toString() ??
        createdBy?['photo_url']?.toString() ??
        user?['avatar']?.toString() ??
        user?['photo_url']?.toString() ??
        order['avatar_url']?.toString();

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

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'draft':
        return Colors.grey.shade600;
      case 'submitted':
        return Colors.orange.shade700;
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'received':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FloorOrderFormScreen(),
      ),
    );
    if (result == true) {
      _loadData(isRefresh: true);
    }
  }

  void _openDetail(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FloorOrderDetailScreen(orderId: id),
      ),
    );
    if (result == true) {
      _loadData(isRefresh: true);
    }
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor RO / outlet',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadData(isRefresh: true);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            onSubmitted: (_) {
              _currentPage = 1;
              _loadData(isRefresh: true);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus.isEmpty ? null : _selectedStatus,
                  decoration: InputDecoration(
                    hintText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'received', child: Text('Received')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value ?? '';
                      _currentPage = 1;
                    });
                    _loadData(isRefresh: true);
                  },
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDateFrom,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Dari',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    child: Text(_dateFromController.text),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectDateTo,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Sampai',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    child: Text(_dateToController.text),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString();
    final orderNumber = order['order_number']?.toString() ?? 'RO';
    final foMode = order['fo_mode']?.toString() ?? 'RO';
    final outletName = order['outlet']?['nama_outlet']?.toString() ?? '-';
    final warehouseName = order['warehouse_outlet']?['name']?.toString() ?? '-';
    final date = order['tanggal']?.toString() ?? '-';
    final totalAmount = order['total_amount'];
    final creatorName = _getCreatorName(order);
    final creatorAvatar = _getCreatorAvatar(order);
    final initials = _getInitials(creatorName);

    return InkWell(
      onTap: () => _openDetail(order['id'] as int),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFEEF2FF),
              backgroundImage: creatorAvatar != null && creatorAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(creatorAvatar)
                  : null,
              child: creatorAvatar == null || creatorAvatar.isEmpty
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4338CA),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          creatorName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$orderNumber • $foMode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          outletName,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.warehouse, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          warehouseName,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Text(
                        _formatCurrency(totalAmount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Request Order (RO)',
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF6F7FB), Color(0xFFEFF3F8)],
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: () => _loadData(isRefresh: true),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _orders.length + (_hasMore || _isLoadingMore ? 1 : 0) + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _buildFilters(),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                final itemIndex = index - 1;

                if (_isLoading && _orders.isEmpty) {
                  return const Center(child: AppLoadingIndicator());
                }

                if (_errorMessage != null && _orders.isEmpty) {
                  return Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (_orders.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada RO',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                if (itemIndex == _orders.length) {
                  if (_isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const SizedBox.shrink();
                }

                if (itemIndex >= _orders.length) {
                  return const SizedBox.shrink();
                }

                return _buildOrderCard(_orders[itemIndex] as Map<String, dynamic>);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Buat RO',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
