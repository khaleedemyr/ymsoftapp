import 'package:flutter/material.dart';
import '../../services/asset_inventory_report_service.dart';

class AssetInventoryReportScreen extends StatefulWidget {
  const AssetInventoryReportScreen({super.key});

  @override
  State<AssetInventoryReportScreen> createState() => _AssetInventoryReportScreenState();
}

class _AssetInventoryReportScreenState extends State<AssetInventoryReportScreen> {
  final _service = AssetInventoryReportService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _stocks = [];
  List<dynamic> _warehouseOutlets = [];
  List<dynamic> _outlets = [];
  int? _selectedOwnerOutletId;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _selectedWarehouseId;

  String? _dateFrom;
  String? _dateTo;

  final Map<String, bool> _expandedItems = {};
  final Map<String, List<dynamic>> _cardDetails = {};
  final Map<String, Map<String, dynamic>> _saldoAwals = {};
  final Map<String, bool> _loadingCards = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(now.year, now.month + 1, 0);
    _dateTo = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
    _loadStocks();
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

  Future<void> _loadStocks({bool reset = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    if (reset) {
      _currentPage = 1;
      _stocks = [];
      _hasMore = true;
      _expandedItems.clear();
      _cardDetails.clear();
      _saldoAwals.clear();
    }

    final data = await _service.getStockPosition(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      ownerOutletId: _selectedOwnerOutletId,
      warehouseOutletId: _selectedWarehouseId,
      page: _currentPage,
    );

    if (data != null && mounted) {
      final stocksData = data['stocks'];
      List<dynamic> list;
      if (stocksData is Map && stocksData['data'] != null) {
        list = stocksData['data'] as List<dynamic>;
        _hasMore = stocksData['next_page_url'] != null;
      } else if (stocksData is List) {
        list = stocksData;
        _hasMore = false;
      } else {
        list = [];
        _hasMore = false;
      }

      if (reset) {
        if (data['warehouseOutlets'] != null) {
          _warehouseOutlets = data['warehouseOutlets'] as List<dynamic>;
        }
        if (data['outlets'] != null) {
          _outlets = data['outlets'] as List<dynamic>;
        } else if (_outlets.isEmpty && list.isNotEmpty) {
          final seen = <int>{};
          _outlets = list
              .where((r) {
                final id = int.tryParse(r['owner_outlet_id']?.toString() ?? '') ?? 0;
                if (id == 0 || seen.contains(id)) return false;
                seen.add(id);
                return true;
              })
              .map((r) => {
                    'id_outlet': r['owner_outlet_id'],
                    'nama_outlet': r['owner_outlet_name'],
                  })
              .toList();
        }
      }

      setState(() {
        if (reset) _stocks = list;
        else _stocks.addAll(list);
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadStocks(reset: false);
  }

  String _itemKey(dynamic row) {
    return '${row['inventory_item_id']}-${row['owner_outlet_id']}-${row['warehouse_outlet_id']}';
  }

  Future<void> _toggleExpand(dynamic row) async {
    final key = _itemKey(row);
    setState(() {
      _expandedItems[key] = !(_expandedItems[key] ?? false);
    });

    if (_expandedItems[key] == true && !_cardDetails.containsKey(key)) {
      await _loadCardDetail(row);
    }
  }

  Future<void> _loadCardDetail(dynamic row) async {
    final key = _itemKey(row);
    setState(() => _loadingCards[key] = true);

    final data = await _service.getStockCardDetail(
      inventoryItemId: int.tryParse(row['inventory_item_id'].toString()) ?? 0,
      ownerOutletId: int.tryParse(row['owner_outlet_id'].toString()) ?? 0,
      warehouseOutletId: int.tryParse(row['warehouse_outlet_id'].toString()) ?? 0,
      from: _dateFrom,
      to: _dateTo,
    );

    if (data != null && mounted) {
      setState(() {
        _cardDetails[key] = (data['cards'] as List<dynamic>?) ?? [];
        if (data['saldo_awal'] != null) {
          _saldoAwals[key] = data['saldo_awal'] as Map<String, dynamic>;
        }
      });
    }
    setState(() => _loadingCards[key] = false);
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
        _expandedItems.clear();
        _cardDetails.clear();
        _saldoAwals.clear();
      });
    }
  }

  String _formatQty(dynamic val, String? unitName) {
    if (val == null) return '';
    final d = double.tryParse(val.toString()) ?? 0;
    if (d == 0) return '';
    final qStr = d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
    return '$qStr ${unitName ?? ''}';
  }

  String _stockSummary(dynamic row) {
    final parts = <String>[];
    final s = _formatQty(row['qty_small'], row['small_unit_name']);
    final m = _formatQty(row['qty_medium'], row['medium_unit_name']);
    final l = _formatQty(row['qty_large'], row['large_unit_name']);
    if (s.isNotEmpty) parts.add(s);
    if (m.isNotEmpty) parts.add(m);
    if (l.isNotEmpty) parts.add(l);
    return parts.isEmpty ? '0' : parts.join(' | ');
  }

  String _cardInQty(dynamic card) {
    final parts = <String>[];
    final s = _formatQty(card['in_qty_small'], card['small_unit_name']);
    final m = _formatQty(card['in_qty_medium'], card['medium_unit_name']);
    final l = _formatQty(card['in_qty_large'], card['large_unit_name']);
    if (s.isNotEmpty) parts.add(s);
    if (m.isNotEmpty) parts.add(m);
    if (l.isNotEmpty) parts.add(l);
    return parts.isEmpty ? '-' : parts.join(' | ');
  }

  String _cardOutQty(dynamic card) {
    final parts = <String>[];
    final s = _formatQty(card['out_qty_small'], card['small_unit_name']);
    final m = _formatQty(card['out_qty_medium'], card['medium_unit_name']);
    final l = _formatQty(card['out_qty_large'], card['large_unit_name']);
    if (s.isNotEmpty) parts.add(s);
    if (m.isNotEmpty) parts.add(m);
    if (l.isNotEmpty) parts.add(l);
    return parts.isEmpty ? '-' : parts.join(' | ');
  }

  String _cardSaldoQty(dynamic card) {
    final parts = <String>[];
    final s = _formatQty(card['saldo_qty_small'], card['small_unit_name']);
    final m = _formatQty(card['saldo_qty_medium'], card['medium_unit_name']);
    final l = _formatQty(card['saldo_qty_large'], card['large_unit_name']);
    if (s.isNotEmpty) parts.add(s);
    if (m.isNotEmpty) parts.add(m);
    if (l.isNotEmpty) parts.add(l);
    return parts.isEmpty ? '0' : parts.join(' | ');
  }

  String _saldoAwalQty(Map<String, dynamic> saldo) {
    final parts = <String>[];
    final s = _formatQty(saldo['small'], saldo['small_unit_name']);
    final m = _formatQty(saldo['medium'], saldo['medium_unit_name']);
    final l = _formatQty(saldo['large'], saldo['large_unit_name']);
    if (s.isNotEmpty) parts.add(s);
    if (m.isNotEmpty) parts.add(m);
    if (l.isNotEmpty) parts.add(l);
    return parts.isEmpty ? '0' : parts.join(' | ');
  }

  Color _refColor(String? refType) {
    switch (refType) {
      case 'asset_good_receive': return Colors.green;
      case 'asset_inventory_transfer': return Colors.blue;
      case 'asset_stock_adjustment': return Colors.orange;
      case 'asset_service_order': return Colors.purple;
      case 'asset_disposal': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Inventory Report'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadStocks,
              child: _stocks.isEmpty && !_isLoading
                  ? const Center(child: Text('Tidak ada data stok', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _stocks.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _stocks.length) {
                          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                        }
                        return _buildStockItem(_stocks[index]);
                      },
                    ),
            ),
          ),
        ],
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
              hintText: 'Cari nama barang...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); _loadStocks(); })
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onSubmitted: (_) => _loadStocks(),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Dari', _dateFrom, () => _pickDate(true), () { setState(() => _dateFrom = null); }),
                const SizedBox(width: 6),
                _filterChip('Sampai', _dateTo, () => _pickDate(false), () { setState(() => _dateTo = null); }),
                const SizedBox(width: 6),
                if (_outlets.isNotEmpty)
                  _dropdownChip(
                    'Pemilik',
                    _selectedOwnerOutletId?.toString() ?? '',
                    {'': 'Semua', ..._ownerMap()},
                    (v) {
                      setState(() => _selectedOwnerOutletId = v.isEmpty ? null : int.tryParse(v));
                      _loadStocks();
                    },
                  ),
                const SizedBox(width: 6),
                if (_warehouseOutlets.isNotEmpty)
                  _dropdownChip(
                    'Warehouse',
                    _selectedWarehouseId?.toString() ?? '',
                    {'': 'Semua', ..._warehouseMap()},
                    (v) {
                      setState(() => _selectedWarehouseId = v.isEmpty ? null : int.tryParse(v));
                      _loadStocks();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _ownerMap() {
    final map = <String, String>{};
    for (final o in _outlets) {
      final id = o['id_outlet']?.toString() ?? '';
      if (id.isNotEmpty) map[id] = o['nama_outlet']?.toString() ?? '';
    }
    return map;
  }

  Map<String, String> _warehouseMap() {
    final map = <String, String>{};
    for (final w in _warehouseOutlets) {
      map[w['id'].toString()] = w['name']?.toString() ?? '';
    }
    return map;
  }

  Widget _buildStockItem(dynamic row) {
    final key = _itemKey(row);
    final isExpanded = _expandedItems[key] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleExpand(row),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.teal, size: 20),
                      const SizedBox(width: 6),
                      Expanded(child: Text(row['item_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pemilik: ${row['owner_outlet_name'] ?? '-'} · ${row['location_outlet_name'] ?? row['outlet_name'] ?? '-'} · ${row['warehouse_name'] ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text('Stok: ${_stockSummary(row)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildCardDetail(key),
        ],
      ),
    );
  }

  Widget _buildCardDetail(String key) {
    if (_loadingCards[key] == true) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final cards = _cardDetails[key];
    if (cards == null || cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Tidak ada transaksi (${_dateFrom ?? ''} s/d ${_dateTo ?? ''})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    final saldo = _saldoAwals[key];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text('Kartu Stok (${_dateFrom ?? ''} s/d ${_dateTo ?? ''})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700)),
          const SizedBox(height: 8),
          if (saldo != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.yellow.shade200)),
              child: Row(
                children: [
                  const Text('Saldo Awal: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Expanded(child: Text(_saldoAwalQty(saldo), style: const TextStyle(fontSize: 11))),
                ],
              ),
            ),
          ...cards.map((card) {
            final isLast = cards.indexOf(card) == cards.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isLast ? Colors.yellow.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(card['date'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _refColor(card['reference_type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          card['reference_label'] ?? card['reference_type'] ?? '-',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _refColor(card['reference_type'])),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Masuk', style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                            Text(_cardInQty(card), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Keluar', style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                            Text(_cardOutQty(card), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saldo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                            Text(_cardSaldoQty(card), style: TextStyle(fontSize: 11, fontWeight: isLast ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (card['description'] != null && card['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(card['description'], style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            );
          }),
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
              GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 14, color: Colors.teal.shade700)),
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
