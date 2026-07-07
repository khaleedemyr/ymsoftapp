import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/asset_inventory_report_service.dart';
import '../../services/auth_service.dart';
import '../../utils/asset_qty_format.dart';

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
  int? _userOutletId;
  int? _selectedOwnerOutletId;
  int? _selectedLocationOutletId;
  int? _selectedWarehouseId;
  int _perPage = 25;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _hasSearchText = false;

  String? _dateFrom;
  String? _dateTo;

  final Map<String, bool> _expandedItems = {};
  final Map<String, List<dynamic>> _cardDetails = {};
  final Map<String, Map<String, dynamic>> _saldoAwals = {};
  final Map<String, bool> _loadingCards = {};

  bool get _isHQ => _userOutletId == 1;

  List<dynamic> get _filteredWarehouses {
    if (_selectedLocationOutletId == null) return _warehouseOutlets;
    return _warehouseOutlets.where((w) {
      return int.tryParse(w['outlet_id']?.toString() ?? '') == _selectedLocationOutletId;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(now.year, now.month + 1, 0);
    _dateTo = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
    _loadUserData();
    _loadStocks();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final hasText = _searchController.text.isNotEmpty;
      if (hasText != _hasSearchText) {
        setState(() => _hasSearchText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService().getUserData();
    if (mounted) {
      setState(() {
        _userOutletId = int.tryParse(userData?['id_outlet']?.toString() ?? '');
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
      _loadMore();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
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
      outletId: _selectedLocationOutletId,
      warehouseOutletId: _selectedWarehouseId,
      page: _currentPage,
      perPage: _perPage,
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
        }
      }

      setState(() {
        if (reset) {
          _stocks = list;
        } else {
          _stocks.addAll(list);
        }
      });
    } else if (mounted) {
      _showError('Gagal memuat data stok');
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
    } else if (mounted) {
      _showError('Gagal memuat kartu stok');
    }
    setState(() => _loadingCards[key] = false);
  }

  void _clearCardCache() {
    _expandedItems.clear();
    _cardDetails.clear();
    _saldoAwals.clear();
    _loadingCards.clear();
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
        if (isFrom) {
          _dateFrom = formatted;
        } else {
          _dateTo = formatted;
        }
        _clearCardCache();
      });
    }
  }

  String _displayQtyCell(dynamic val, String? unitName) {
    final d = double.tryParse(val?.toString() ?? '') ?? 0;
    if (d == 0) return '-';
    final unit = unitName?.trim();
    if (unit != null && unit.isNotEmpty) {
      return '${formatAssetQty(val)} $unit';
    }
    return formatAssetQty(val);
  }

  String _formatValue(dynamic val) {
    final d = double.tryParse(val?.toString() ?? '') ?? 0;
    if (d == 0) return '-';
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(d)}';
  }

  String _formatUpdatedAt(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    final dt = DateTime.tryParse(val.toString());
    if (dt == null) return val.toString();
    return DateFormat('d/M/y HH:mm', 'id_ID').format(dt.toLocal());
  }

  String _cardInQty(dynamic card) {
    final parts = <String>[];
    final s = _displayQtyCell(card['in_qty_small'], card['small_unit_name']);
    final m = _displayQtyCell(card['in_qty_medium'], card['medium_unit_name']);
    final l = _displayQtyCell(card['in_qty_large'], card['large_unit_name']);
    if (s != '-') parts.add(s);
    if (m != '-') parts.add(m);
    if (l != '-') parts.add(l);
    return parts.isEmpty ? '-' : parts.join(' | ');
  }

  String _cardOutQty(dynamic card) {
    final parts = <String>[];
    final s = _displayQtyCell(card['out_qty_small'], card['small_unit_name']);
    final m = _displayQtyCell(card['out_qty_medium'], card['medium_unit_name']);
    final l = _displayQtyCell(card['out_qty_large'], card['large_unit_name']);
    if (s != '-') parts.add(s);
    if (m != '-') parts.add(m);
    if (l != '-') parts.add(l);
    return parts.isEmpty ? '-' : parts.join(' | ');
  }

  String _cardSaldoQty(dynamic card) {
    final parts = <String>[];
    final s = _displayQtyCell(card['saldo_qty_small'], card['small_unit_name']);
    final m = _displayQtyCell(card['saldo_qty_medium'], card['medium_unit_name']);
    final l = _displayQtyCell(card['saldo_qty_large'], card['large_unit_name']);
    if (s != '-') parts.add(s);
    if (m != '-') parts.add(m);
    if (l != '-') parts.add(l);
    return parts.isEmpty ? '0' : parts.join(' | ');
  }

  String _saldoAwalQty(Map<String, dynamic> saldo) {
    final parts = <String>[];
    final s = _displayQtyCell(saldo['small'], saldo['small_unit_name']);
    final m = _displayQtyCell(saldo['medium'], saldo['medium_unit_name']);
    final l = _displayQtyCell(saldo['large'], saldo['large_unit_name']);
    if (s != '-') parts.add(s);
    if (m != '-') parts.add(m);
    if (l != '-') parts.add(l);
    return parts.isEmpty ? '0' : parts.join(' | ');
  }

  Color _refColor(String? refType) {
    switch (refType) {
      case 'asset_good_receive':
        return Colors.green;
      case 'asset_inventory_transfer':
        return Colors.blue;
      case 'asset_owner_transfer':
        return Colors.deepPurple;
      case 'asset_stock_adjustment':
        return Colors.orange;
      case 'asset_service_order':
        return Colors.purple;
      case 'asset_disposal':
        return Colors.red;
      case 'initial_balance':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _onLocationOutletChanged(String v) {
    final newId = v.isEmpty ? null : int.tryParse(v);
    setState(() {
      _selectedLocationOutletId = newId;
      if (_selectedWarehouseId != null) {
        final stillValid = _filteredWarehouses.any(
          (w) => int.tryParse(w['id'].toString()) == _selectedWarehouseId,
        );
        if (!stillValid) _selectedWarehouseId = null;
      }
    });
    _loadStocks();
  }

  Map<String, String> _outletMap() {
    final map = <String, String>{};
    for (final o in _outlets) {
      final id = o['id_outlet']?.toString() ?? '';
      if (id.isNotEmpty) map[id] = o['nama_outlet']?.toString() ?? '';
    }
    return map;
  }

  Map<String, String> _warehouseMap() {
    final map = <String, String>{};
    for (final w in _filteredWarehouses) {
      map[w['id'].toString()] = w['name']?.toString() ?? '';
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Akhir'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadStocks(),
              child: _stocks.isEmpty && !_isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Tidak ada data stok asset', style: TextStyle(color: Colors.grey))),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _stocks.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _stocks.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
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
              hintText: 'Cari nama barang atau warehouse...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _hasSearchText
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _loadStocks();
                      },
                    )
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
                _filterChip('Dari', _dateFrom, () => _pickDate(true), () {
                  setState(() {
                    _dateFrom = null;
                    _clearCardCache();
                  });
                }),
                const SizedBox(width: 6),
                _filterChip('Sampai', _dateTo, () => _pickDate(false), () {
                  setState(() {
                    _dateTo = null;
                    _clearCardCache();
                  });
                }),
                const SizedBox(width: 6),
                if (_isHQ && _outlets.isNotEmpty)
                  _dropdownChip(
                    'Pemilik',
                    _selectedOwnerOutletId?.toString() ?? '',
                    {'': 'Semua Pemilik', ..._outletMap()},
                    (v) {
                      setState(() => _selectedOwnerOutletId = v.isEmpty ? null : int.tryParse(v));
                      _loadStocks();
                    },
                  ),
                if (_isHQ && _outlets.isNotEmpty) const SizedBox(width: 6),
                if (_outlets.isNotEmpty)
                  _dropdownChip(
                    'Lokasi',
                    _selectedLocationOutletId?.toString() ?? '',
                    {'': 'Semua Lokasi', ..._outletMap()},
                    _onLocationOutletChanged,
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
                const SizedBox(width: 6),
                _dropdownChip(
                  'Tampilkan',
                  _perPage.toString(),
                  {for (final n in [10, 25, 50, 100]) n.toString(): '$n data'},
                  (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed != _perPage) {
                      setState(() => _perPage = parsed);
                      _loadStocks();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockItem(dynamic row) {
    final key = _itemKey(row);
    final isExpanded = _expandedItems[key] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isExpanded ? Colors.blue.shade50 : null,
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
                      Expanded(
                        child: Text(
                          row['item_name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _metaRow('Pemilik', row['owner_outlet_name']),
                  _metaRow('Lokasi', row['location_outlet_name']),
                  _metaRow('Warehouse', row['warehouse_name']),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _qtyChip('Small', _displayQtyCell(row['qty_small'], row['small_unit_name'])),
                        const SizedBox(width: 8),
                        _qtyChip('Medium', _displayQtyCell(row['qty_medium'], row['medium_unit_name'])),
                        const SizedBox(width: 8),
                        _qtyChip('Large', _displayQtyCell(row['qty_large'], row['large_unit_name'])),
                        const SizedBox(width: 8),
                        _qtyChip('Value', _formatValue(row['value']), highlight: true),
                        const SizedBox(width: 8),
                        _qtyChip('Update', _formatUpdatedAt(row['updated_at'])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildCardDetail(key),
        ],
      ),
    );
  }

  Widget _metaRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: ${value ?? '-'}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _qtyChip(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? Colors.teal.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? Colors.teal.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              color: highlight ? Colors.teal.shade800 : null,
            ),
          ),
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
        child: Text(
          'Tidak ada transaksi (${_dateFrom ?? ''} s/d ${_dateTo ?? ''})',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    final saldo = _saldoAwals[key];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(
            'Kartu Stok (${_dateFrom ?? ''} s/d ${_dateTo ?? ''})',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Masuk (Qty)')),
                DataColumn(label: Text('Keluar (Qty)')),
                DataColumn(label: Text('Saldo (Qty)')),
                DataColumn(label: Text('Referensi')),
                DataColumn(label: Text('Keterangan')),
              ],
              rows: [
                if (saldo != null)
                  DataRow(
                    color: WidgetStateProperty.all(Colors.yellow.shade50),
                    cells: [
                      DataCell(Text(_dateFrom ?? '-')),
                      const DataCell(Text('-')),
                      const DataCell(Text('-')),
                      DataCell(Text(_saldoAwalQty(saldo), style: const TextStyle(fontWeight: FontWeight.w600))),
                      const DataCell(Text('Saldo Awal')),
                      const DataCell(Text('Saldo sebelum periode')),
                    ],
                  ),
                ...cards.asMap().entries.map((entry) {
                  final index = entry.key;
                  final card = entry.value;
                  final isLast = index == cards.length - 1;
                  final refType = card['reference_type']?.toString();
                  return DataRow(
                    color: WidgetStateProperty.all(isLast ? Colors.yellow.shade100 : null),
                    cells: [
                      DataCell(Text(card['date']?.toString() ?? '-')),
                      DataCell(Text(_cardInQty(card))),
                      DataCell(Text(_cardOutQty(card))),
                      DataCell(
                        Text(
                          _cardSaldoQty(card),
                          style: TextStyle(fontWeight: isLast ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _refColor(refType).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            card['reference_label'] ?? card['reference_type'] ?? '-',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _refColor(refType),
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(card['description']?.toString().isNotEmpty == true ? card['description'] : '-')),
                    ],
                  );
                }),
              ],
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
            Text(hasValue ? value : label, style: TextStyle(fontSize: 12, color: hasValue ? Colors.teal.shade700 : Colors.grey.shade600)),
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
