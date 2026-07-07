import 'package:flutter/material.dart';
import '../../services/asset_inventory_adjustment_service.dart';
import '../../models/asset_inventory_adjustment_models.dart';
import 'asset_inventory_adjustment_form_screen.dart';
import 'asset_inventory_adjustment_detail_screen.dart';

class AssetInventoryAdjustmentIndexScreen extends StatefulWidget {
  const AssetInventoryAdjustmentIndexScreen({super.key});

  @override
  State<AssetInventoryAdjustmentIndexScreen> createState() =>
      _AssetInventoryAdjustmentIndexScreenState();
}

class _AssetInventoryAdjustmentIndexScreenState
    extends State<AssetInventoryAdjustmentIndexScreen> {
  final _service = AssetInventoryAdjustmentService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<AssetInventoryAdjustment> _adjustments = [];
  List<Map<String, dynamic>> _outlets = [];
  int? _userOutletId;
  bool _isLoading = false;
  bool _isPreparing = true;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _dateFrom;
  String? _dateTo;
  String _typeFilter = '';
  String _statusFilter = '';
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
      _userOutletId = int.tryParse(createData?['user']?['id_outlet']?.toString() ?? '');
      _isPreparing = false;
    });
    _loadAdjustments();
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

  Future<void> _loadAdjustments({bool reset = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (reset) {
      _currentPage = 1;
      _adjustments = [];
      _hasMore = true;
    }

    final result = await _service.getAdjustments(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      type: _typeFilter.isNotEmpty ? _typeFilter : null,
      status: _statusFilter.isNotEmpty ? _statusFilter : null,
      outletId: _outletIdFilter,
      page: _currentPage,
      perPage: 15,
    );

    if (result != null && mounted) {
      final data = (result['data'] as List<dynamic>?)
              ?.map((e) => AssetInventoryAdjustment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      setState(() {
        if (reset) {
          _adjustments = data;
        } else {
          _adjustments.addAll(data);
        }
        _hasMore = result['next_page_url'] != null;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadAdjustments(reset: false);
  }

  Future<void> _refresh() async {
    await _loadAdjustments();
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
    switch (status.toLowerCase()) {
      case 'waiting_approval':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'waiting_approval':
        return 'WAITING APPROVAL';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  Color _typeColor(String type) {
    return type.toLowerCase() == 'in' ? Colors.green : Colors.red;
  }

  String _typeLabel(String type) {
    return type.toLowerCase() == 'in' ? 'STOCK IN' : 'STOCK OUT';
  }

  void _clearFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _typeFilter = '';
      _statusFilter = '';
      _outletIdFilter = null;
      _searchController.clear();
    });
    _loadAdjustments();
  }

  Future<void> _deleteFromIndex(AssetInventoryAdjustment adjustment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Adjustment?'),
        content: const Text('Data adjustment akan dihapus permanen.'),
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
    final result = await _service.deleteAdjustment(adjustment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) {
      _loadAdjustments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Stock Adjustment'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari no. adjustment...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadAdjustments();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (_) => _loadAdjustments(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _dateFrom ?? 'Dari Tanggal',
                            style: TextStyle(
                              fontSize: 13,
                              color: _dateFrom != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _dateTo ?? 'Sampai Tanggal',
                            style: TextStyle(
                              fontSize: 13,
                              color: _dateTo != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Semua Status')),
                          DropdownMenuItem(value: 'waiting_approval', child: Text('Waiting Approval')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_userOutletId == 1)
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _outletIdFilter,
                          decoration: InputDecoration(
                            labelText: 'Outlet',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Semua Outlet')),
                            ..._outlets.map((o) => DropdownMenuItem<int>(
                                  value: int.tryParse(o['id_outlet']?.toString() ?? ''),
                                  child: Text(o['nama_outlet']?.toString() ?? '-'),
                                )),
                          ],
                          onChanged: (v) => setState(() => _outletIdFilter = v),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTypeChip('', 'Semua'),
                    const SizedBox(width: 6),
                    _buildTypeChip('in', 'Stock In'),
                    const SizedBox(width: 6),
                    _buildTypeChip('out', 'Stock Out'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _loadAdjustments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Filter', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 4),
                    if (_dateFrom != null ||
                        _dateTo != null ||
                        _typeFilter.isNotEmpty ||
                        _statusFilter.isNotEmpty ||
                        _outletIdFilter != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: _clearFilters,
                      ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _adjustments.isEmpty && !_isLoading
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text('Tidak ada data adjustment.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Nomor')),
                              DataColumn(label: Text('Tanggal')),
                              DataColumn(label: Text('Pemilik')),
                              DataColumn(label: Text('Lokasi')),
                              DataColumn(label: Text('Warehouse')),
                              DataColumn(label: Text('Tipe')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Dibuat Oleh')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: _adjustments.map((a) {
                              return DataRow(cells: [
                                DataCell(Text(a.number)),
                                DataCell(Text(a.date)),
                                DataCell(Text(a.ownerOutletName ?? '-')),
                                DataCell(Text(a.outletName ?? '-')),
                                DataCell(Text(a.warehouseOutletName ?? '-')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _typeColor(a.type).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _typeLabel(a.type),
                                      style: TextStyle(
                                        color: _typeColor(a.type),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(a.status).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(a.status),
                                      style: TextStyle(
                                        color: _statusColor(a.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(a.creatorName ?? '-')),
                                DataCell(
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AssetInventoryAdjustmentDetailScreen(
                                                adjustmentId: a.id,
                                              ),
                                            ),
                                          );
                                          _loadAdjustments();
                                        },
                                        child: const Text('Lihat'),
                                      ),
                                      if (a.status.toLowerCase() == 'waiting_approval')
                                        TextButton(
                                          onPressed: () => _deleteFromIndex(a),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AssetInventoryAdjustmentFormScreen(),
            ),
          );
          if (result == true) _loadAdjustments();
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Adjustment'),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label) {
    final selected = _typeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.white,
          border: Border.all(color: selected ? Colors.teal : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
