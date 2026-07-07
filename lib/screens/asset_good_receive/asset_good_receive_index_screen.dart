import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/asset_good_receive_service.dart';
import '../../models/asset_good_receive_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'asset_good_receive_detail_screen.dart';
import 'asset_good_receive_form_screen.dart';

class AssetGoodReceiveIndexScreen extends StatefulWidget {
  const AssetGoodReceiveIndexScreen({super.key});

  @override
  State<AssetGoodReceiveIndexScreen> createState() =>
      _AssetGoodReceiveIndexScreenState();
}

class _AssetGoodReceiveIndexScreenState
    extends State<AssetGoodReceiveIndexScreen> {
  final AssetGoodReceiveService _service = AssetGoodReceiveService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<AssetGoodReceive> _goodReceives = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  int? _outletFilter;

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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
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
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.getGoodReceives(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        outletId: _outletFilter,
        page: _currentPage,
        perPage: 20,
      );

      if (result != null && mounted) {
        List<AssetGoodReceive> newItems = [];

        if (result['data'] != null) {
          final data = result['data'];
          if (data is List) {
            newItems = data
                .map((item) =>
                    AssetGoodReceive.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }

        setState(() {
          if (isRefresh) {
            _goodReceives = newItems;
          } else {
            _goodReceives.addAll(newItems);
          }
          _hasMore = newItems.length >= 20;
          _isLoading = false;
        });
        if (_outlets.isEmpty) {
          _outlets = await _service.getOutlets();
          if (mounted) setState(() {});
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      _dateFrom =
          _dateFromController.text.isNotEmpty ? _dateFromController.text : null;
      _dateTo =
          _dateToController.text.isNotEmpty ? _dateToController.text : null;
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
      _statusFilter = '';
      _outletFilter = null;
    });
    _loadGoodReceives(isRefresh: true);
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.parse(controller.text)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _navigateToDetail(AssetGoodReceive gr) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AssetGoodReceiveDetailScreen(goodReceiveId: gr.id),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssetGoodReceiveFormScreen(),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  void _navigateToEdit(AssetGoodReceive gr) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssetGoodReceiveFormScreen(goodReceiveId: gr.id),
      ),
    );
    if (result == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  Future<void> _deleteFromIndex(AssetGoodReceive gr) async {
    if (gr.status != 'draft') return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Good Receive?'),
        content: Text('Yakin hapus ${gr.grNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _service.deleteGoodReceive(gr.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Gagal menghapus data'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) {
      _loadGoodReceives(isRefresh: true);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Asset Good Receive',
      body: Column(
        children: [
          Container(
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
                    hintText: 'Cari GR Number, PO Number...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (value) => _applyFilters(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateFromController,
                        decoration: InputDecoration(
                          labelText: 'Dari Tanggal',
                          prefixIcon:
                              const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        readOnly: true,
                        onTap: () =>
                            _selectDate(context, _dateFromController),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _dateToController,
                        decoration: InputDecoration(
                          labelText: 'Sampai Tanggal',
                          prefixIcon:
                              const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value ?? '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _outletFilter,
                        decoration: InputDecoration(
                          labelText: 'Outlet',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Semua Outlet'),
                          ),
                          ..._outlets.map((outlet) => DropdownMenuItem<int?>(
                                value: int.tryParse(
                                    outlet['id']?.toString() ??
                                        outlet['id_outlet']?.toString() ??
                                        ''),
                                child: Text(
                                    outlet['name']?.toString() ??
                                        outlet['nama_outlet']?.toString() ??
                                        '-'),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _outletFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _goodReceives.isEmpty
                ? const AppLoadingIndicator()
                : RefreshIndicator(
                    onRefresh: () => _loadGoodReceives(isRefresh: true),
                    child: _goodReceives.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height *
                                          0.3),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 64,
                                        color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tidak ada Asset Good Receive',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('GR Number')),
                                    DataColumn(label: Text('PO Number')),
                                    DataColumn(label: Text('Pemilik')),
                                    DataColumn(label: Text('Lokasi')),
                                    DataColumn(label: Text('Warehouse')),
                                    DataColumn(label: Text('Tanggal')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(
                                        label: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('Total'),
                                    )),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: _goodReceives.map((gr) {
                                    final statusColor =
                                        gr.status == 'completed'
                                            ? Colors.green
                                            : Colors.orange;
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(gr.grNumber)),
                                        DataCell(Text(gr.poNumber ?? '-')),
                                        DataCell(
                                            Text(gr.ownerOutletName ?? '-')),
                                        DataCell(Text(gr.locationOutletName ??
                                            gr.outletName ??
                                            '-')),
                                        DataCell(
                                            Text(gr.warehouseOutletName ?? '-')),
                                        DataCell(Text(gr.receiveDate.isNotEmpty
                                            ? DateFormat('dd MMM yyyy').format(
                                                DateTime.parse(gr.receiveDate))
                                            : '-')),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              gr.status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatCurrency(gr.total),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _navigateToDetail(gr),
                                                child: const Text('View'),
                                              ),
                                              if (gr.status == 'draft')
                                                TextButton(
                                                  onPressed: () =>
                                                      _navigateToEdit(gr),
                                                  child: const Text('Edit'),
                                                ),
                                              if (gr.status == 'draft')
                                                TextButton(
                                                  onPressed: () =>
                                                      _deleteFromIndex(gr),
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red),
                                                  child: const Text('Delete'),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (_hasMore)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah GR'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

}
