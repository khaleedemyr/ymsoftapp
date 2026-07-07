import 'package:flutter/material.dart';
import '../../services/asset_disposal_service.dart';
import '../../models/asset_disposal_models.dart';
import 'asset_disposal_form_screen.dart';
import 'asset_disposal_detail_screen.dart';

class AssetDisposalIndexScreen extends StatefulWidget {
  const AssetDisposalIndexScreen({super.key});

  @override
  State<AssetDisposalIndexScreen> createState() => _AssetDisposalIndexScreenState();
}

class _AssetDisposalIndexScreenState extends State<AssetDisposalIndexScreen> {
  final _service = AssetDisposalService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<AssetDisposal> _disposals = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = false;
  bool _isPreparing = true;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _userOutletId;
  int? _outletIdFilter;
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _loadCreateData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadCreateData() async {
    final data = await _service.getCreateData();
    if (mounted) {
      setState(() {
        _outlets = (data?['outlets'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _userOutletId = int.tryParse(data?['user']?['id_outlet']?.toString() ?? '');
        if (_userOutletId != null && _userOutletId != 1) {
          _outletIdFilter = _userOutletId;
        }
        _isPreparing = false;
      });
    }
    await _loadDisposals();
  }

  Future<void> _loadDisposals({bool reset = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    if (reset) {
      _currentPage = 1;
      _disposals = [];
      _hasMore = true;
    }
    final data = await _service.getDisposals(
      search: _searchController.text,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter.isNotEmpty ? _statusFilter : null,
      type: _typeFilter.isNotEmpty ? _typeFilter : null,
      outletId: _outletIdFilter,
      page: _currentPage,
    );
    if (data != null) {
      final list = (data['data'] as List?)?.map((e) => AssetDisposal.fromJson(e)).toList() ?? [];
      setState(() {
        if (reset) _disposals = list;
        else _disposals.addAll(list);
        _hasMore = data['next_page_url'] != null;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadDisposals(reset: false);
  }

  Future<void> _deleteFromIndex(AssetDisposal disposal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Disposal?'),
        content: Text('Disposal ${disposal.number} akan dihapus permanen.'),
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
    final result = await _service.destroy(disposal.id);
    if (!mounted) return;
    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (ok ? 'Berhasil dihapus' : 'Gagal menghapus')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) {
      await _loadDisposals();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting_approval':
        return Colors.amber.shade800;
      case 'approved':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Widget _typeBadge(String type) {
    final isSold = type == 'sold';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSold ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSold ? 'Dijual' : 'Dibuang',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSold ? Colors.blue.shade700 : Colors.grey.shade700),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
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

  Future<void> _pickDate(bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      setState(() {
        if (isFrom) _dateFrom = formatted;
        else _dateTo = formatted;
      });
      _loadDisposals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Disposal'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetDisposalFormScreen()));
          if (result == true) _loadDisposals();
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          if (_isPreparing)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor / deskripsi...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); _loadDisposals(); })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadDisposals(),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Dari', _dateFrom, () => _pickDate(true), () { setState(() => _dateFrom = null); _loadDisposals(); }),
                      const SizedBox(width: 6),
                      _filterChip('Sampai', _dateTo, () => _pickDate(false), () { setState(() => _dateTo = null); _loadDisposals(); }),
                      const SizedBox(width: 6),
                      _dropdownChip('Status', _statusFilter, {'': 'Semua', 'waiting_approval': 'Waiting', 'approved': 'Approved', 'rejected': 'Rejected'}, (v) { setState(() => _statusFilter = v); _loadDisposals(); }),
                      const SizedBox(width: 6),
                      _dropdownChip('Tipe', _typeFilter, {'': 'Semua', 'discard': 'Dibuang', 'sold': 'Dijual'}, (v) { setState(() => _typeFilter = v); _loadDisposals(); }),
                      if (_userOutletId == 1) ...[
                        const SizedBox(width: 6),
                        _dropdownChip(
                          'Outlet',
                          _outletIdFilter?.toString() ?? '',
                          {
                            '': 'Semua Outlet',
                            ...{
                              for (final o in _outlets)
                                (o['id_outlet']?.toString() ?? ''): (o['nama_outlet']?.toString() ?? '-')
                            }
                          },
                          (v) {
                            setState(() => _outletIdFilter = v.isEmpty ? null : int.tryParse(v));
                            _loadDisposals();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDisposals,
              child: _disposals.isEmpty && !_isLoading
                  ? const Center(child: Text('Tidak ada data disposal', style: TextStyle(color: Colors.grey)))
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                            columns: const [
                              DataColumn(label: Text('Nomor')),
                              DataColumn(label: Text('Tanggal')),
                              DataColumn(label: Text('Pemilik')),
                              DataColumn(label: Text('Lokasi')),
                              DataColumn(label: Text('Tipe')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Pembeli')),
                              DataColumn(label: Text('Dibuat Oleh')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: _disposals.map((d) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(d.number)),
                                  DataCell(Text(d.date)),
                                  DataCell(Text(d.ownerOutletName ?? '-')),
                                  DataCell(Text(d.outletName ?? '-')),
                                  DataCell(_typeBadge(d.type)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(d.status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _statusLabel(d.status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _statusColor(d.status),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(d.type == 'sold' ? (d.buyerName ?? '-') : '-')),
                                  DataCell(Text(d.creatorName ?? '-')),
                                  DataCell(
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AssetDisposalDetailScreen(disposalId: d.id),
                                              ),
                                            );
                                            if (result == true) _loadDisposals();
                                          },
                                          child: const Text('Lihat'),
                                        ),
                                        if (d.status == 'waiting_approval')
                                          TextButton(
                                            onPressed: () => _deleteFromIndex(d),
                                            child: const Text(
                                              'Hapus',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value, VoidCallback onTap, VoidCallback onClear) {
    final hasValue = value != null && value.isNotEmpty;
    final String displayText = hasValue ? value.toString() : label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasValue ? Colors.teal.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hasValue ? Colors.teal.shade300 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayText, style: TextStyle(fontSize: 12, color: hasValue ? Colors.teal.shade700 : Colors.grey.shade600)),
            if (hasValue) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: Colors.teal.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdownChip(String label, String currentValue, Map<String, String> options, ValueChanged<String> onChanged) {
    final displayLabel = currentValue.isEmpty ? label : options[currentValue] ?? label;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => options.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: currentValue.isNotEmpty ? Colors.teal.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: currentValue.isNotEmpty ? Colors.teal.shade300 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayLabel, style: TextStyle(fontSize: 12, color: currentValue.isNotEmpty ? Colors.teal.shade700 : Colors.grey.shade600)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}
