import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_stock_position_models.dart';
import '../../services/auth_service.dart';
import '../../services/outlet_stock_position_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class OutletStockPositionScreen extends StatefulWidget {
  const OutletStockPositionScreen({super.key});

  @override
  State<OutletStockPositionScreen> createState() => _OutletStockPositionScreenState();
}

class _OutletStockPositionScreenState extends State<OutletStockPositionScreen> {
  final OutletStockPositionService _service = OutletStockPositionService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingFilters = true;
  bool _isLoadingData = false;
  bool _outletSelectable = true;

  int? _userOutletId;
  int? _selectedOutletId;
  int? _selectedWarehouseOutletId;
  String? _outletName;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];

  List<OutletStockPositionItem> _stocks = [];
  Map<String, bool> _expandedCategories = {};
  Map<String, bool> _expandedItems = {};
  Map<String, List<OutletStockCardEntry>> _itemDetails = {};
  Map<String, OutletStockCardSaldoAwal> _saldoAwal = {};
  Map<String, bool> _loadingItems = {};

  String _errorMessage = '';
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _isLoadingFilters = true;
    });

    try {
      final userData = await _authService.getUserData();
      _userOutletId = _parseInt(userData?['id_outlet']);
        _outletName = userData?['outlet']?['nama_outlet']?.toString() ??
          userData?['outlet_name']?.toString() ??
          userData?['nama_outlet']?.toString();
      _outletSelectable = _userOutletId == null || _userOutletId == 1;

      if (_outletSelectable) {
        _outlets = await _service.getOutlets();
      } else if (_userOutletId != null) {
        _selectedOutletId = _userOutletId;
      }

      _warehouseOutlets = await _service.getWarehouseOutlets(
        outletId: _selectedOutletId,
      );
    } catch (e) {
      _errorMessage = 'Gagal memuat filter';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFilters = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    if (_selectedOutletId == null && _selectedWarehouseOutletId == null) {
      _showMessage('Pilih minimal outlet atau warehouse outlet');
      return;
    }

    setState(() {
      _isLoadingData = true;
      _errorMessage = '';
    });

    try {
      final result = await _service.getStockPosition(
        outletId: _selectedOutletId,
        warehouseOutletId: _selectedWarehouseOutletId,
        search: null,
        perPage: 200,
      );

      if (result != null && mounted) {
        final data = result['data'] ?? result;
        List<dynamic> raw = [];
        if (data is List) {
          raw = data;
        } else if (data is Map && data['data'] is List) {
          raw = data['data'] as List;
        }

        final items = raw
            .map((item) => OutletStockPositionItem.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          _stocks = items;
          _expandedCategories = {
            for (final category in _groupedStocks.keys) category: true,
          };
          _expandedItems.clear();
          _itemDetails.clear();
          _saldoAwal.clear();
          _loadingItems.clear();
          _hasLoaded = true;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat data';
          _stocks = [];
          _hasLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _stocks = [];
        _hasLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Map<String, List<OutletStockPositionItem>> get _groupedStocks {
    final filtered = _filteredStocks;
    final grouped = <String, List<OutletStockPositionItem>>{};
    for (final item in filtered) {
      final key = item.categoryName ?? 'Tanpa Kategori';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }
    return grouped;
  }

  List<OutletStockPositionItem> get _filteredStocks {
    if (_searchController.text.isEmpty) return _stocks;
    final query = _searchController.text.toLowerCase();
    return _stocks.where((item) {
      return item.itemName.toLowerCase().contains(query) ||
          item.outletName.toLowerCase().contains(query) ||
          (item.categoryName ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleItemDetail(OutletStockPositionItem item) async {
    final key = item.itemKey;
    final isExpanded = _expandedItems[key] ?? false;

    setState(() {
      _expandedItems[key] = !isExpanded;
    });

    if (!isExpanded) {
      if (_itemDetails.containsKey(key) || _loadingItems[key] == true) return;

      setState(() {
        _loadingItems[key] = true;
      });

      final detail = await _service.getStockCardDetail(
        itemId: item.itemId,
        outletId: item.outletId,
        warehouseOutletId: item.warehouseOutletId,
      );

      if (mounted) {
        if (detail != null && detail['cards'] is List) {
          final cards = (detail['cards'] as List)
              .map((entry) => OutletStockCardEntry.fromJson(entry as Map<String, dynamic>))
              .toList();
          final saldoRaw = detail['saldo_awal'] as Map<String, dynamic>?;
          setState(() {
            _itemDetails[key] = cards;
            if (saldoRaw != null) {
              _saldoAwal[key] = OutletStockCardSaldoAwal.fromJson(saldoRaw);
            }
          });
        } else {
          setState(() {
            _itemDetails[key] = [];
          });
        }
      }

      if (mounted) {
        setState(() {
          _loadingItems[key] = false;
        });
      }
    }
  }

  void _onOutletChanged(int? value) async {
    setState(() {
      _selectedOutletId = value;
      _selectedWarehouseOutletId = null;
      _warehouseOutlets = [];
    });

    _warehouseOutlets = await _service.getWarehouseOutlets(outletId: value);
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      _expandedCategories[category] = !(_expandedCategories[category] ?? false);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laporan Stok Akhir Outlet',
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _isLoadingFilters
          ? const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)))
          : Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama barang / outlet / kategori',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (_outletSelectable)
                  DropdownButtonFormField<int>(
                    value: _selectedOutletId,
                    decoration: InputDecoration(
                      labelText: 'Outlet',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _outlets
                        .map((outlet) {
                          final id = _parseInt(outlet['id_outlet'] ?? outlet['id']);
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(outlet['nama_outlet']?.toString() ?? outlet['name']?.toString() ?? '-'),
                          );
                        })
                        .where((item) => item.value != null)
                        .toList(),
                    onChanged: _onOutletChanged,
                  )
                else
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Outlet',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    child: Text(
                      _outletName ?? '-',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedWarehouseOutletId,
                  decoration: InputDecoration(
                    labelText: 'Warehouse Outlet',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _warehouseOutlets
                      .map((wo) => DropdownMenuItem<int>(
                            value: _parseInt(wo['id']),
                            child: Text(wo['name']?.toString() ?? '-'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWarehouseOutletId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoadingData
                            ? null
                            : () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedWarehouseOutletId = null;
                                  if (_outletSelectable) {
                                    _selectedOutletId = null;
                                  }
                                  _stocks = [];
                                  _hasLoaded = false;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoadingData ? null : _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoadingData
                            ? const AppLoadingIndicator(size: 18, color: Colors.white)
                            : const Text('Load Data'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingData && _stocks.isEmpty) {
      return const Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)));
    }

    if (_errorMessage.isNotEmpty) {
      return _buildInfoState(_errorMessage, Icons.error_outline, const Color(0xFFDC2626));
    }

    if (!_hasLoaded) {
      return _buildInfoState(
        'Pilih minimal satu filter lalu klik Load Data',
        Icons.info_outline,
        const Color(0xFF2563EB),
      );
    }

    if (_filteredStocks.isEmpty) {
      return _buildInfoState(
        'Tidak ada data stok untuk filter yang dipilih',
        Icons.warning_amber_rounded,
        const Color(0xFFF59E0B),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _groupedStocks.keys.length,
      itemBuilder: (context, index) {
        final category = _groupedStocks.keys.elementAt(index);
        final items = _groupedStocks[category] ?? [];
        final expanded = _expandedCategories[category] ?? true;
        return _buildCategoryCard(category, items, expanded);
      },
    );
  }

  Widget _buildCategoryCard(String category, List<OutletStockPositionItem> items, bool expanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleCategory(category),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.chevron_right,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${items.length} item',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Column(
              children: items.map(_buildItemTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildItemTile(OutletStockPositionItem item) {
    final expanded = _expandedItems[item.itemKey] ?? false;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ExpansionTile(
        key: PageStorageKey(item.itemKey),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        initiallyExpanded: expanded,
        onExpansionChanged: (_) => _toggleItemDetail(item),
        title: Text(
          item.itemName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            _buildInfoLine('Outlet', item.outletName),
            _buildInfoLine('Warehouse', item.warehouseOutletName ?? '-'),
            _buildInfoLine('Update', _formatDateTime(item.updatedAt)),
          ],
        ),
        trailing: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          color: const Color(0xFF64748B),
        ),
        children: [
          _buildQtyRow(item),
          const SizedBox(height: 12),
          _buildDetailSection(item),
        ],
      ),
    );
  }

  Widget _buildDetailSection(OutletStockPositionItem item) {
    final key = item.itemKey;
    if (_loadingItems[key] == true) {
      return const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF2563EB)));
    }

    final cards = _itemDetails[key];
    if (cards == null) {
      return const Text('Klik untuk memuat detail kartu stok', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_saldoAwal[key] != null) _buildSaldoAwalCard(_saldoAwal[key]!),
        if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Tidak ada transaksi bulan ini', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          )
        else
          ...cards.map(_buildCardEntry).toList(),
      ],
    );
  }

  Widget _buildSaldoAwalCard(OutletStockCardSaldoAwal saldo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Awal Bulan',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 6),
          _buildQtyLine('Small', saldo.small, saldo.smallUnitName),
          _buildQtyLine('Medium', saldo.medium, saldo.mediumUnitName),
          _buildQtyLine('Large', saldo.large, saldo.largeUnitName),
        ],
      ),
    );
  }

  Widget _buildCardEntry(OutletStockCardEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(entry.date),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          _buildQtyLine('Masuk', entry.inQtySmall, entry.smallUnitName, entry.inQtyMedium, entry.mediumUnitName, entry.inQtyLarge, entry.largeUnitName),
          _buildQtyLine('Keluar', entry.outQtySmall, entry.smallUnitName, entry.outQtyMedium, entry.mediumUnitName, entry.outQtyLarge, entry.largeUnitName),
          _buildQtyLine('Saldo', entry.saldoQtySmall, entry.smallUnitName, entry.saldoQtyMedium, entry.mediumUnitName, entry.saldoQtyLarge, entry.largeUnitName),
          const SizedBox(height: 6),
          Text(
            _buildReference(entry),
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          if (entry.description != null && entry.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.description!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildQtyRow(OutletStockPositionItem item) {
    return Row(
      children: [
        Expanded(child: _buildQtyCard('Small', item.qtySmall, item.smallUnitName)),
        const SizedBox(width: 8),
        Expanded(child: _buildQtyCard('Medium', item.qtyMedium, item.mediumUnitName)),
        const SizedBox(width: 8),
        Expanded(child: _buildQtyCard('Large', item.qtyLarge, item.largeUnitName)),
      ],
    );
  }

  Widget _buildQtyCard(String label, double value, String? unit) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            '${_formatNumber(value)} ${unit ?? ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyLine(String label, double small, String? smallUnit,
      [double? medium, String? mediumUnit, double? large, String? largeUnit]) {
    final parts = <String>[];
    if (small > 0) parts.add('${_formatNumber(small)} ${smallUnit ?? ''}');
    if (medium != null && medium > 0) parts.add('${_formatNumber(medium)} ${mediumUnit ?? ''}');
    if (large != null && large > 0) parts.add('${_formatNumber(large)} ${largeUnit ?? ''}');
    final value = parts.isEmpty ? '-' : parts.join(' | ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _buildReference(OutletStockCardEntry entry) {
    final reference = entry.referenceType ?? '-';
    if (entry.referenceId != null && entry.referenceId!.isNotEmpty) {
      return '$reference #${entry.referenceId}';
    }
    return reference;
  }

  Widget _buildInfoState(String message, IconData icon, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(dateTime);
      return DateFormat('dd MMM yyyy HH:mm').format(parsed);
    } catch (e) {
      return dateTime ?? '-';
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
