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
  List<Map<String, dynamic>> _outlets = [];
  int? _userOutletId;
  bool _isLoading = false;
  bool _isPreparing = true;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  String _serviceTypeFilter = '';
  int? _outletIdFilter;

  @override
  void initState() {
    super.initState();
    _loadCreateData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCreateData() async {
    final createData = await _service.getCreateData();
    if (!mounted) return;
    setState(() {
      _outlets = (createData?['outlets'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _userOutletId =
          int.tryParse(createData?['user']?['id_outlet']?.toString() ?? '');
      _isPreparing = false;
    });
    _loadOrders();
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
      search: _searchController.text.trim().isNotEmpty
          ? _searchController.text.trim()
          : null,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter.isEmpty ? null : _statusFilter,
      serviceType: _serviceTypeFilter.isEmpty ? null : _serviceTypeFilter,
      outletId: _outletIdFilter,
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

  Future<void> _deleteFromIndex(AssetServiceOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Service Order?'),
        content: const Text('Data service order akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _service.deleteOrder(order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) {
      _loadOrders();
    }
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
      _outletIdFilter = null;
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
        return 'WAITING APPROVAL';
      case 'in_service':
        return 'IN SERVICE';
      case 'partially_returned':
        return 'PARTIALLY RETURNED';
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
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _orders.isEmpty && !_isLoading
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('Tidak ada data service order.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Tipe')),
                              DataColumn(label: Text('Nomor')),
                              DataColumn(label: Text('Tanggal')),
                              DataColumn(label: Text('Pemilik')),
                              DataColumn(label: Text('Lokasi')),
                              DataColumn(label: Text('Warehouse')),
                              DataColumn(label: Text('Supplier')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Dibuat Oleh')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: _orders.map((order) {
                              return DataRow(cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: order.serviceType == 'internal'
                                          ? Colors.blueGrey.shade100
                                          : Colors.deepPurple.shade50,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      order.serviceType == 'internal'
                                          ? 'Internal'
                                          : 'External',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: order.serviceType == 'internal'
                                            ? Colors.blueGrey.shade800
                                            : Colors.deepPurple.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(order.number)),
                                DataCell(Text(order.date)),
                                DataCell(Text(order.ownerOutletName ?? '-')),
                                DataCell(Text(order.outletName ?? '-')),
                                DataCell(Text(order.warehouseOutletName ?? '-')),
                                DataCell(Text(order.supplierName ?? '—')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(order.status)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(order.status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _statusColor(order.status),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(order.creatorName ?? '-')),
                                DataCell(
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AssetServiceOrderDetailScreen(
                                                orderId: order.id,
                                              ),
                                            ),
                                          );
                                          if (result == true) _loadOrders();
                                        },
                                        child: const Text('Lihat'),
                                      ),
                                      if (order.status == 'waiting_approval')
                                        TextButton(
                                          onPressed: () => _deleteFromIndex(order),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Hapus'),
                                        ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                        if (_hasMore)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
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
                  initialValue: _statusFilter.isEmpty ? null : _statusFilter,
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
                    DropdownMenuItem(value: null, child: Text('Semua')),
                    DropdownMenuItem(
                        value: 'waiting_approval', child: Text('Waiting Approval')),
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
          if (_userOutletId == 1) ...[
            DropdownButtonFormField<int>(
              initialValue: _outletIdFilter,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              hint: const Text('Outlet', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Outlet')),
                ..._outlets.map((o) => DropdownMenuItem<int>(
                      value: int.tryParse(o['id_outlet']?.toString() ?? ''),
                      child: Text(
                        o['nama_outlet']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
              ],
              onChanged: (val) => setState(() => _outletIdFilter = val),
            ),
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<String>(
            initialValue: _serviceTypeFilter.isEmpty ? null : _serviceTypeFilter,
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
              DropdownMenuItem(value: null, child: Text('Semua')),
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
}
