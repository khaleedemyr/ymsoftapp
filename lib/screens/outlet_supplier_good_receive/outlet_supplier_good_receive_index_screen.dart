import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/outlet_supplier_good_receive_models.dart';
import '../../services/outlet_supplier_good_receive_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../services/auth_service.dart';
import 'outlet_supplier_good_receive_create_screen.dart';
import 'outlet_supplier_good_receive_detail_screen.dart';

class OutletSupplierGoodReceiveIndexScreen extends StatefulWidget {
  const OutletSupplierGoodReceiveIndexScreen({super.key});

  @override
  State<OutletSupplierGoodReceiveIndexScreen> createState() => _OutletSupplierGoodReceiveIndexScreenState();
}

class _OutletSupplierGoodReceiveIndexScreenState extends State<OutletSupplierGoodReceiveIndexScreen> {
  final OutletSupplierGoodReceiveService _service = OutletSupplierGoodReceiveService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<OutletSupplierGoodReceiveListItem> _goodReceives = [];
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
      final result = await _service.getOutletSupplierGoodReceives(
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
            .map((item) => OutletSupplierGoodReceiveListItem.fromJson(item as Map<String, dynamic>))
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

  void _navigateToDetail(OutletSupplierGoodReceiveListItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutletSupplierGoodReceiveDetailScreen(goodReceiveId: item.id),
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
        builder: (context) => const OutletSupplierGoodReceiveCreateScreen(),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Outlet Supplier GR',
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

                final itemIndex = index - 1;

                if (itemIndex == _goodReceives.length) {
                  if (_isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const SizedBox.shrink();
                }

                if (itemIndex >= _goodReceives.length) {
                  return const SizedBox.shrink();
                }

                final item = _goodReceives[itemIndex];
                return _buildGoodReceiveCard(item);
              },
            ),
          ),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadGoodReceives(isRefresh: true),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari GR / RO / DO / Outlet',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateFromController,
                    readOnly: true,
                    onTap: () => _selectDate(context, _dateFromController),
                    decoration: InputDecoration(
                      hintText: 'Dari tanggal',
                      prefixIcon: const Icon(Icons.date_range),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _dateToController,
                    readOnly: true,
                    onTap: () => _selectDate(context, _dateToController),
                    decoration: InputDecoration(
                      hintText: 'Sampai tanggal',
                      prefixIcon: const Icon(Icons.date_range),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoodReceiveCard(OutletSupplierGoodReceiveListItem item) {
    return InkWell(
      onTap: () => _navigateToDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          _buildStatusChip(item.status ?? '-'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoLine('Tanggal', item.receiveDate),
                      _buildInfoLine('RO/DO', _buildRoDoText(item)),
                      _buildInfoLine('Outlet', item.outletName ?? '-'),
                      if (item.supplierName != null) _buildInfoLine('Supplier', item.supplierName ?? '-'),
                      _buildInfoLine('Petugas', item.receivedByName ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(OutletSupplierGoodReceiveListItem item) {
    final name = item.receivedByName ?? '-';
    final avatarUrl = _getAvatarUrl(item);
    final initials = _getInitials(name);

    return CircleAvatar(
      radius: 24,
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

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _buildRoDoText(OutletSupplierGoodReceiveListItem item) {
    final ro = item.roNumber;
    final doNumber = item.doNumber;
    if (ro != null && ro.isNotEmpty) return ro;
    if (doNumber != null && doNumber.isNotEmpty) return doNumber;
    return '-';
  }

  String? _getAvatarUrl(OutletSupplierGoodReceiveListItem item) {
    final raw = item.receivedByAvatar;
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

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('complete') || normalized.contains('selesai')) {
      return const Color(0xFF16A34A);
    }
    if (normalized.contains('draft') || normalized.contains('pending')) {
      return const Color(0xFFF59E0B);
    }
    if (normalized.contains('cancel') || normalized.contains('batal')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF4B5563);
  }
}
