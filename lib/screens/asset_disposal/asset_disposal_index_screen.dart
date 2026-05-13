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
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _dateFrom;
  String? _dateTo;
  String _statusFilter = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _loadDisposals();
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

  Widget _statusBadge(String status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'waiting_approval':
        bg = Colors.amber.shade100; fg = Colors.amber.shade800; label = 'Waiting';
        break;
      case 'approved':
        bg = Colors.green.shade100; fg = Colors.green.shade800; label = 'Approved';
        break;
      case 'rejected':
        bg = Colors.red.shade100; fg = Colors.red.shade800; label = 'Rejected';
        break;
      default:
        bg = Colors.grey.shade100; fg = Colors.grey.shade800; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
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
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _disposals.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _disposals.length) {
                          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                        }
                        final d = _disposals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDisposalDetailScreen(disposalId: d.id)));
                              if (result == true) _loadDisposals();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(d.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal))),
                                      _typeBadge(d.type),
                                      const SizedBox(width: 6),
                                      _statusBadge(d.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(d.date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 4),
                                  Text('${d.outletName ?? '-'} • ${d.creatorName ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  if (d.type == 'sold' && d.buyerName != null && d.buyerName!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Pembeli: ${d.buyerName}', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                                  ],
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
    );
  }

  Widget _filterChip(String label, String? value, VoidCallback onTap, VoidCallback onClear) {
    final hasValue = value != null && value.isNotEmpty;
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
            Text(hasValue ? value! : label, style: TextStyle(fontSize: 12, color: hasValue ? Colors.teal.shade700 : Colors.grey.shade600)),
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
