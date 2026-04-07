import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/outlet_food_good_receive_service.dart';
import '../../models/outlet_food_good_receive_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'outlet_food_good_receive_detail_screen.dart';
import 'outlet_food_good_receive_scan_screen.dart';

class OutletFoodGoodReceiveIndexScreen extends StatefulWidget {
  const OutletFoodGoodReceiveIndexScreen({super.key});

  @override
  State<OutletFoodGoodReceiveIndexScreen> createState() => _OutletFoodGoodReceiveIndexScreenState();
}

class _OutletFoodGoodReceiveIndexScreenState extends State<OutletFoodGoodReceiveIndexScreen> {
  final OutletFoodGoodReceiveService _service = OutletFoodGoodReceiveService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<OutletFoodGoodReceiveListItem> _goodReceives = [];
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
    _loadGoodReceives();
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

  Future<void> _loadGoodReceives({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _goodReceives = [];
        _hasMore = true;
        _errorMessage = null;
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getOutletGoodReceives(
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
            .map((item) => OutletFoodGoodReceiveListItem.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          if (isRefresh) {
            _goodReceives = newItems;
          } else {
            _goodReceives.addAll(newItems);
          }
          _hasMore = newItems.length >= 20;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
            _errorMessage = 'Gagal memuat data';
          });
        }
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
    await _loadGoodReceives();
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text;
      _dateFrom = _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo = _dateToController.text.isNotEmpty ? _dateToController.text : null;
    });
    _loadGoodReceives(isRefresh: true);
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
    _loadGoodReceives(isRefresh: true);
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

  void _navigateToDetail(OutletFoodGoodReceiveListItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletFoodGoodReceiveDetailScreen(goodReceiveId: item.id),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutletFoodGoodReceiveScanScreen(),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  String _getCreatorName(OutletFoodGoodReceiveListItem item) {
    return item.creatorName?.toString() ?? '-';
  }

  String? _getCreatorAvatar(OutletFoodGoodReceiveListItem item) {
    final raw = item.creatorAvatar;
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Outlet Good Receive',
      actions: [
        IconButton(
          onPressed: _navigateToCreate,
          icon: const Icon(Icons.add, color: Color(0xFF1A1A1A)),
          tooltip: 'Tambah GR',
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF1D4ED8),
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
            onRefresh: () => _loadGoodReceives(isRefresh: true),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _goodReceives.length + (_hasMore ? 1 : 0) + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _buildFilterSection(),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                final dataIndex = index - 1;
                if (_errorMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (_isLoading && _goodReceives.isEmpty) {
                  return const Center(child: AppLoadingIndicator());
                }

                if (!_isLoading && _goodReceives.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Belum ada data',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                if (dataIndex >= _goodReceives.length) {
                  if (_hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: AppLoadingIndicator(size: 22)),
                    );
                  }
                  return const SizedBox.shrink();
                }

                final item = _goodReceives[dataIndex];
                return _buildCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor GR, DO, outlet...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dateFromController,
                  decoration: InputDecoration(
                    labelText: 'Dari Tanggal',
                    prefixIcon: const Icon(Icons.calendar_today, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context, _dateFromController),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _dateToController,
                  decoration: InputDecoration(
                    labelText: 'Sampai Tanggal',
                    prefixIcon: const Icon(Icons.calendar_today, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context, _dateToController),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Terapkan'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(OutletFoodGoodReceiveListItem item) {
    final creatorName = _getCreatorName(item);
    final creatorAvatar = _getCreatorAvatar(item);
    final initials = _getInitials(creatorName);

    return InkWell(
      onTap: () => _navigateToDetail(item),
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
                      _buildStatusBadge(item.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.number,
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
                          item.outletName ?? '-',
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
                          item.warehouseOutletName ?? '-',
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
                        item.receiveDate.isNotEmpty ? item.receiveDate : '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Text(
                        item.deliveryOrderNumber ?? '-',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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

  Widget _buildStatusBadge(String? status) {
    final normalized = (status ?? '').toLowerCase();
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade700;

    if (normalized == 'completed') {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade700;
    } else if (normalized == 'stocked') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade700;
    } else if (normalized == 'draft') {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
