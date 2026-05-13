import 'package:flutter/material.dart';
import '../../services/asset_service_order_service.dart';
import '../../models/asset_service_order_models.dart';
import 'asset_service_order_form_screen.dart';
import 'asset_service_order_detail_screen.dart';

class AssetServiceOrderIndexScreen extends StatefulWidget {
  const AssetServiceOrderIndexScreen({super.key});

  @override
  State<AssetServiceOrderIndexScreen> createState() =>
      _AssetServiceOrderIndexScreenState();
}

class _AssetServiceOrderIndexScreenState
    extends State<AssetServiceOrderIndexScreen> {
  final _service = AssetServiceOrderService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<AssetServiceOrder> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  String _serviceTypeFilter = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadOrders({bool reset = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    if (reset) {
      _currentPage = 1;
      _orders = [];
      _hasMore = true;
    }

    final result = await _service.getOrders(
      search: _searchController.text,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter.isEmpty ? null : _statusFilter,
      serviceType: _serviceTypeFilter.isEmpty ? null : _serviceTypeFilter,
      page: _currentPage,
      perPage: 15,
    );

    if (result != null) {
      final list = (result['data'] as List<dynamic>?)
              ?.map((e) => AssetServiceOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      setState(() {
        if (reset) {
          _orders = list;
        } else {
          _orders.addAll(list);
        }
        _hasMore = (result['next_page_url'] ?? '').toString().isNotEmpty;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadOrders(reset: false);
  }

  Future<void> _refresh() async {
    await _loadOrders();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateFrom = null;
      _dateTo = null;
      _statusFilter = '';
      _serviceTypeFilter = '';
    });
    _loadOrders();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        if (isFrom) {
          _dateFrom = formatted;
        } else {
          _dateTo = formatted;
        }
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting_approval':
        return Colors.orange;
      case 'in_service':
        return Colors.blue;
      case 'partially_returned':
        return Colors.deepOrange;
      case 'returned':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_approval':
        return 'WAITING';
      case 'in_service':
        return 'IN SERVICE';
      case 'partially_returned':
        return 'PARTIAL RETURN';
      case 'returned':
        return 'RETURNED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Service'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AssetServiceOrderFormScreen(),
            ),
          );
          if (result == true) _loadOrders();
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Service Order',
            style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _orders.isEmpty && !_isLoading
                  ? const Center(
                      child: Text('Tidak ada data service order.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _orders.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _orders.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _buildCard(_orders[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor / supplier...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _loadOrders();
                      })
                  : null,
            ),
            onSubmitted: (_) => _loadOrders(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dateFrom ?? 'Dari Tgl',
                      style: TextStyle(
                          fontSize: 13,
                          color: _dateFrom != null
                              ? Colors.black87
                              : Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dateTo ?? 'Sampai Tgl',
                      style: TextStyle(
                          fontSize: 13,
                          color: _dateTo != null
                              ? Colors.black87
                              : Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter.isEmpty ? null : _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  hint: const Text('Status', style: TextStyle(fontSize: 13)),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua')),
                    DropdownMenuItem(
                        value: 'waiting_approval',
                        child: Text('Waiting')),
                    DropdownMenuItem(
                        value: 'in_service', child: Text('In Service')),
                    DropdownMenuItem(
                        value: 'partially_returned',
                        child: Text('Partial')),
                    DropdownMenuItem(
                        value: 'returned', child: Text('Returned')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (val) {
                    setState(() => _statusFilter = val ?? '');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _serviceTypeFilter.isEmpty ? null : _serviceTypeFilter,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            hint: const Text('Tipe', style: TextStyle(fontSize: 13)),
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua')),
              DropdownMenuItem(value: 'external', child: Text('External')),
              DropdownMenuItem(value: 'internal', child: Text('Internal')),
            ],
            onChanged: (val) {
              setState(() => _serviceTypeFilter = val ?? '');
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _loadOrders(),
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AssetServiceOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AssetServiceOrderDetailScreen(orderId: order.id),
            ),
          );
          if (result == true) _loadOrders();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.number,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.teal),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: order.serviceType == 'internal'
                              ? Colors.blueGrey.shade100
                              : Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order.serviceType == 'internal'
                              ? 'Internal'
                              : 'External',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.serviceType == 'internal'
                                ? Colors.blueGrey.shade800
                                : Colors.deepPurple.shade800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(order.status),
                          style: TextStyle(
                            color: _statusColor(order.status),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.business, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.serviceType == 'internal'
                          ? '—'
                          : (order.supplierName ?? '-'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.store, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.outletName ?? '-'} • ${order.warehouseOutletName ?? '-'}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(order.date,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  const Spacer(),
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(order.creatorName ?? '-',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
