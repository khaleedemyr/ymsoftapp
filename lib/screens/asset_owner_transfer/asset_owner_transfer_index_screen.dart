import 'package:flutter/material.dart';
import '../../services/asset_owner_transfer_service.dart';
import '../../models/asset_owner_transfer_models.dart';
import 'asset_owner_transfer_form_screen.dart';
import 'asset_owner_transfer_detail_screen.dart';

class AssetOwnerTransferIndexScreen extends StatefulWidget {
  const AssetOwnerTransferIndexScreen({super.key});

  @override
  State<AssetOwnerTransferIndexScreen> createState() =>
      _AssetOwnerTransferIndexScreenState();
}

class _AssetOwnerTransferIndexScreenState extends State<AssetOwnerTransferIndexScreen> {
  static const Color _violet = Color(0xFF7C3AED);

  final _service = AssetOwnerTransferService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<AssetOwnerTransfer> _transfers = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  int? _ownerOutletId;
  int? _userOutletId;

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
      status: _statusFilter.isNotEmpty ? _statusFilter : null,
      ownerOutletId: _ownerOutletId,
      page: _currentPage,
      perPage: 15,
    );

    if (result != null && mounted) {
      final data = (result['data'] as List<dynamic>?)
              ?.map((e) => AssetOwnerTransfer.fromJson(e as Map<String, dynamic>))
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
      if (_outlets.isEmpty) {
        final createData = await _service.getCreateData();
        final outlets = (createData?['outlets'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            await _service.getOutlets();
        if (mounted) {
          setState(() {
            _outlets = outlets;
            _userOutletId ??= int.tryParse(
                  createData?['user']?['id_outlet']?.toString() ?? '',
                ) ??
                0;
          });
        }
      }
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

  Future<void> _deleteTransfer(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transfer?'),
        content: const Text('Data transfer draft akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final result = await _service.deleteTransfer(id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Gagal menghapus transfer.'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) {
      _loadTransfers();
    }
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
        title: const Text('Transfer Kepemilikan Aset'),
        backgroundColor: _violet,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                        backgroundColor: _violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Filter', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Semua')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (v) {
                        setState(() => _statusFilter = v ?? '');
                        _loadTransfers();
                      },
                    ),
                    const SizedBox(width: 4),
                    if ((_userOutletId ?? 0) == 1)
                      DropdownButton<int?>(
                        value: _ownerOutletId,
                        hint: const Text('Pemilik'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Semua Pemilik')),
                          ..._outlets.map((o) => DropdownMenuItem<int?>(
                                value: int.tryParse(
                                    o['id']?.toString() ??
                                        o['id_outlet']?.toString() ??
                                        ''),
                                child: Text(o['name']?.toString() ??
                                    o['nama_outlet']?.toString() ??
                                    '-'),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _ownerOutletId = v);
                          _loadTransfers();
                        },
                      ),
                    if ((_userOutletId ?? 0) == 1) const SizedBox(width: 4),
                    if (_dateFrom != null || _dateTo != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                            _statusFilter = '';
                            _ownerOutletId = null;
                          });
                          _loadTransfers();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
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
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('No.')),
                              DataColumn(label: Text('Pemilik Asal')),
                              DataColumn(label: Text('Pemilik Tujuan')),
                              DataColumn(label: Text('Lokasi / Gudang')),
                              DataColumn(label: Text('Tanggal')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: _transfers.map((t) {
                              return DataRow(cells: [
                                DataCell(Text(t.transferNumber)),
                                DataCell(Text(t.ownerFromName ?? '-')),
                                DataCell(Text(t.ownerToName ?? '-')),
                                DataCell(Text(
                                    '${t.locationOutletName ?? '-'}\n${t.warehouseOutletName ?? '-'}')),
                                DataCell(Text(t.transferDate)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(t.status)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      t.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(t.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AssetOwnerTransferDetailScreen(
                                                      transferId: t.id),
                                            ),
                                          );
                                          _loadTransfers();
                                        },
                                        child: const Text('Lihat'),
                                      ),
                                      if (t.status.toLowerCase() == 'draft')
                                        TextButton(
                                          onPressed: () => _deleteTransfer(t.id),
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.red),
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
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
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
              builder: (_) => const AssetOwnerTransferFormScreen(),
            ),
          );
          if (result == true) _loadTransfers();
        },
        backgroundColor: _violet,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Transfer'),
      ),
    );
  }
}
