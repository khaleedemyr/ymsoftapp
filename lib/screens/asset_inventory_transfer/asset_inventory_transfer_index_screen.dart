import 'package:flutter/material.dart';
import '../../services/asset_inventory_transfer_service.dart';
import '../../models/asset_inventory_transfer_models.dart';
import 'asset_inventory_transfer_form_screen.dart';
import 'asset_inventory_transfer_detail_screen.dart';

class AssetInventoryTransferIndexScreen extends StatefulWidget {
  const AssetInventoryTransferIndexScreen({super.key});

  @override
  State<AssetInventoryTransferIndexScreen> createState() =>
      _AssetInventoryTransferIndexScreenState();
}

class _AssetInventoryTransferIndexScreenState
    extends State<AssetInventoryTransferIndexScreen> {
  final _service = AssetInventoryTransferService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<AssetInventoryTransfer> _transfers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _dateFrom;
  String? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
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

  Future<void> _loadTransfers({bool reset = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (reset) {
      _currentPage = 1;
      _transfers = [];
      _hasMore = true;
    }

    final result = await _service.getTransfers(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      page: _currentPage,
      perPage: 15,
    );

    if (result != null && mounted) {
      final data = (result['data'] as List<dynamic>?)
              ?.map((e) => AssetInventoryTransfer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      setState(() {
        if (reset) {
          _transfers = data;
        } else {
          _transfers.addAll(data);
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
    await _loadTransfers(reset: false);
  }

  Future<void> _refresh() async {
    await _loadTransfers();
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
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Inventory Transfer'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search + Date Filters
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari no. transfer...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadTransfers();
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
                  onSubmitted: (_) => _loadTransfers(),
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
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loadTransfers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Filter', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 4),
                    if (_dateFrom != null || _dateTo != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                          });
                          _loadTransfers();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _transfers.isEmpty && !_isLoading
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text('Tidak ada data transfer.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _transfers.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _transfers.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final t = _transfers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AssetInventoryTransferDetailScreen(transferId: t.id),
                                ),
                              );
                              _loadTransfers();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        t.transferNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusColor(t.status).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          t.status.toUpperCase(),
                                          style: TextStyle(
                                            color: _statusColor(t.status),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.arrow_forward,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${t.warehouseOutletFromName ?? '-'} → ${t.warehouseOutletToName ?? '-'}',
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        t.transferDate,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        t.creatorName ?? '-',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
              builder: (_) => const AssetInventoryTransferFormScreen(),
            ),
          );
          if (result == true) _loadTransfers();
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Transfer'),
      ),
    );
  }
}
