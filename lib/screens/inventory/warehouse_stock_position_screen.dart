import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/warehouse_stock_position_models.dart';
import '../../services/warehouse_stock_position_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class WarehouseStockPositionScreen extends StatefulWidget {
  const WarehouseStockPositionScreen({super.key});

  @override
  State<WarehouseStockPositionScreen> createState() =>
      _WarehouseStockPositionScreenState();
}

class _WarehouseStockPositionScreenState extends State<WarehouseStockPositionScreen> {
  final WarehouseStockPositionService _service = WarehouseStockPositionService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingFilters = true;
  bool _isLoadingData = false;

  int? _selectedWarehouseId;
  List<Map<String, dynamic>> _warehouses = [];

  List<WarehouseStockPositionItem> _stocks = [];
  Map<String, bool> _expandedCategories = {};
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
    setState(() => _isLoadingFilters = true);
    try {
      _warehouses = await _service.getWarehouses();
    } catch (e) {
      _errorMessage = 'Gagal memuat filter';
    } finally {
      if (mounted) setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = '';
    });

    try {
      final result = await _service.getStockPosition(
        warehouseId: _selectedWarehouseId,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (result != null && mounted) {
        final stocksRaw = result['stocks'];
        List<dynamic> raw = [];
        if (stocksRaw is List) raw = stocksRaw;

        final items = raw
            .map((item) => WarehouseStockPositionItem.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          _stocks = items;
          _expandedCategories = {
            for (final category in _groupedStocks.keys) category: true,
          };
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _stocks = [];
          _hasLoaded = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Map<String, List<WarehouseStockPositionItem>> get _groupedStocks {
    final filtered = _filteredStocks;
    final grouped = <String, List<WarehouseStockPositionItem>>{};
    for (final item in filtered) {
      final key = item.categoryName ?? 'Tanpa Kategori';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }
    return grouped;
  }

  List<WarehouseStockPositionItem> get _filteredStocks {
    if (_searchController.text.isEmpty) return _stocks;
    final query = _searchController.text.toLowerCase();
    return _stocks.where((item) {
      return item.itemName.toLowerCase().contains(query) ||
          item.warehouseName.toLowerCase().contains(query) ||
          (item.categoryName ?? '').toLowerCase().contains(query);
    }).toList();
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
      title: 'Laporan Stok Akhir Warehouse',
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(child: _buildBody()),
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
                    hintText: 'Cari nama barang / gudang / kategori',
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
                DropdownButtonFormField<int?>(
                  value: _selectedWarehouseId,
                  decoration: InputDecoration(
                    labelText: 'Gudang',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Gudang')),
                    ..._warehouses
                        .map((w) => DropdownMenuItem<int?>(
                              value: _parseInt(w['id']),
                              child: Text(w['name']?.toString() ?? '-'),
                            ))
                        .where((item) => item.value != null),
                  ],
                  onChanged: (value) => setState(() => _selectedWarehouseId = value),
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
                                  _selectedWarehouseId = null;
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
        'Pilih gudang (atau Semua) lalu klik Load Data',
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

  Widget _buildCategoryCard(
      String category, List<WarehouseStockPositionItem> items, bool expanded) {
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

  Widget _buildItemTile(WarehouseStockPositionItem item) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _buildInfoLine('Gudang', item.warehouseName),
            _buildInfoLine('Update', _formatDateTime(item.updatedAt)),
            const SizedBox(height: 10),
            _buildQtyRow(item),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyRow(WarehouseStockPositionItem item) {
    return Row(
      children: [
        Expanded(
            child: _buildQtyCard('Small', item.qtySmall, item.smallUnitName)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildQtyCard('Medium', item.qtyMedium, item.mediumUnitName)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildQtyCard('Large', item.qtyLarge, item.largeUnitName)),
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
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            '${_formatNumber(value)} ${unit ?? ''}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A)),
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
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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

  String _formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(dateTime);
      return DateFormat('dd MMM yyyy HH:mm').format(parsed);
    } catch (e) {
      return dateTime;
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
