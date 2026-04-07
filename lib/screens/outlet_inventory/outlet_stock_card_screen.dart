import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_stock_position_models.dart';
import '../../services/auth_service.dart';
import '../../services/outlet_stock_position_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class OutletStockCardScreen extends StatefulWidget {
  const OutletStockCardScreen({super.key});

  @override
  State<OutletStockCardScreen> createState() => _OutletStockCardScreenState();
}

class _OutletStockCardScreenState extends State<OutletStockCardScreen> {
  // state fields
  final OutletStockPositionService _service = OutletStockPositionService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  List<OutletStockCardEntry> _cards = [];
  OutletStockCardSaldoAwal? _saldoAwal;
  String _errorMessage = '';
  String? _outletName;

  bool _isLoadingData = false;
  bool _hasLoaded = false;
  bool _isLoadingFilters = false;
  bool _filterExpanded = false;
  bool _outletSelectable = true;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  int? _userOutletId;

  Map<String, dynamic>? _selectedItem;
  int? _selectedOutletId;
  int? _selectedWarehouseOutletId;

  int _pageNum = 1;
  int _perPage = 10;

  @override
  void dispose() {
    _searchController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _isLoadingFilters = true;
    });

    try {
      final auth = AuthService();
      final userData = await auth.getUserData();
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

      _warehouseOutlets = await _service.getWarehouseOutlets(outletId: _selectedOutletId);
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
    if (_selectedItem == null) {
      _showMessage('Pilih barang terlebih dahulu');
      return;
    }

    setState(() {
      _isLoadingData = true;
      _errorMessage = '';
    });

    try {
      final result = await _service.getStockCard(
        itemId: _parseInt(_selectedItem?['id']) ?? 0,
        outletId: _selectedOutletId,
        warehouseOutletId: _selectedWarehouseOutletId,
        fromDate: _fromController.text,
        toDate: _toController.text,
      );

      if (result != null && mounted) {
        final rawCards = result['cards'] as List<dynamic>? ?? [];
        final saldoRaw = result['saldo_awal'] as Map<String, dynamic>?;

        setState(() {
          _cards = rawCards
              .map((entry) => OutletStockCardEntry.fromJson(entry as Map<String, dynamic>))
              .toList();
          _saldoAwal = saldoRaw != null ? OutletStockCardSaldoAwal.fromJson(saldoRaw) : null;
          _hasLoaded = true;
          _pageNum = 1;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat data';
          _cards = [];
          _saldoAwal = null;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _cards = [];
        _saldoAwal = null;
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

  Future<void> _openItemSearch() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ItemSearchModal(
          service: _service,
          initialItem: _selectedItem,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedItem = selected;
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final currentValue = controller.text;
    final initialDate = currentValue.isNotEmpty
        ? DateTime.tryParse(currentValue) ?? DateTime.now()
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
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

  List<OutletStockCardEntry> get _filteredCards {
    if (_searchController.text.isEmpty) return _cards;
    final query = _searchController.text.toLowerCase();
    return _cards.where((entry) {
      return (entry.itemName ?? '').toLowerCase().contains(query) ||
          (entry.outletName ?? '').toLowerCase().contains(query) ||
          (entry.referenceType ?? '').toLowerCase().contains(query) ||
          (entry.description ?? '').toLowerCase().contains(query);
    }).toList();
  }

  int get _totalPages {
    final total = (_filteredCards.length / _perPage).ceil();
    return total == 0 ? 1 : total;
  }

  int get _startIndex {
    return (_pageNum - 1) * _perPage;
  }

  int get _endIndex {
    final end = _startIndex + _perPage;
    return end > _filteredCards.length ? _filteredCards.length : end;
  }

  List<OutletStockCardEntry> get _paginatedCards {
    if (_filteredCards.isEmpty) return [];
    return _filteredCards.sublist(
      _startIndex,
      _endIndex,
    );
  }

  void _prevPage() {
    if (_pageNum > 1) {
      setState(() {
        _pageNum -= 1;
      });
    }
  }

  void _nextPage() {
    if (_pageNum < _totalPages) {
      setState(() {
        _pageNum += 1;
      });
    }
  }

  String _formatNumber(num value) {
    final formatter = NumberFormat('#,##0.##', 'id_ID');
    return formatter.format(value);
  }

  String _formatQtyLine(double qty, String? unit) {
    if (qty == 0) return '-';
    return '${_formatNumber(qty)} ${unit ?? ''}'.trim();
  }

  String _formatQty(OutletStockCardEntry entry, String type) {
    if (type == 'in') {
      return '${_formatQtyLine(entry.inQtySmall, entry.smallUnitName)} | '
          '${_formatQtyLine(entry.inQtyMedium, entry.mediumUnitName)} | '
          '${_formatQtyLine(entry.inQtyLarge, entry.largeUnitName)}';
    }
    return '${_formatQtyLine(entry.outQtySmall, entry.smallUnitName)} | '
        '${_formatQtyLine(entry.outQtyMedium, entry.mediumUnitName)} | '
        '${_formatQtyLine(entry.outQtyLarge, entry.largeUnitName)}';
  }

  String _formatSaldo(OutletStockCardEntry entry) {
    return '${_formatQtyLine(entry.saldoQtySmall, entry.smallUnitName)} | '
        '${_formatQtyLine(entry.saldoQtyMedium, entry.mediumUnitName)} | '
        '${_formatQtyLine(entry.saldoQtyLarge, entry.largeUnitName)}';
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

  String _buildReference(OutletStockCardEntry entry) {
    final reference = entry.referenceType ?? '-';
    if (entry.referenceId != null && entry.referenceId!.isNotEmpty) {
      return '$reference #${entry.referenceId}';
    }
    return reference;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kartu Stok Outlet',
      body: Column(
        children: [
          _buildFilterHeader(),
          if (_filterExpanded) _buildFilterCard(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Filter',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _filterExpanded = !_filterExpanded;
              });
            },
            icon: Icon(
              _filterExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Cari barang, outlet, referensi, keterangan',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) {
              setState(() {
                _pageNum = 1;
              });
            },
          ),
          const SizedBox(height: 12),
          _isLoadingFilters
              ? const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)))
              : Column(
                  children: [
                    _buildOutletField(),
                    const SizedBox(height: 12),
                    _buildWarehouseField(),
                  ],
                ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openItemSearch,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Barang',
                prefixIcon: const Icon(Icons.inventory_2, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              child: Text(
                _selectedItem?['name']?.toString() ?? 'Pilih barang',
                style: TextStyle(
                  color: _selectedItem == null ? Colors.grey.shade600 : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_fromController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _fromController,
                      decoration: InputDecoration(
                        labelText: 'Dari',
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_toController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _toController,
                      decoration: InputDecoration(
                        labelText: 'Sampai',
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _perPage,
                  decoration: InputDecoration(
                    labelText: 'Tampilkan',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 data')),
                    DropdownMenuItem(value: 25, child: Text('25 data')),
                    DropdownMenuItem(value: 50, child: Text('50 data')),
                    DropdownMenuItem(value: 100, child: Text('100 data')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _perPage = value;
                      _pageNum = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingData ? null : _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoadingData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Load Data'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutletField() {
    if (!_outletSelectable) {
      return InputDecorator(
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
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      );
    }

      return DropdownButtonFormField<int?>(
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
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Semua Outlet')),
        ..._outlets.map((outlet) {
          final id = _parseInt(outlet['id'] ?? outlet['id_outlet']);
          final name = outlet['name']?.toString() ?? outlet['nama_outlet']?.toString() ?? '-';
          return DropdownMenuItem<int?>(value: id, child: Text(name));
        }).toList(),
      ],
      onChanged: (value) => _onOutletChanged(value),
    );
  }

  Widget _buildWarehouseField() {
    return DropdownButtonFormField<int?>(
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
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Semua Warehouse')),
        ..._warehouseOutlets.map((warehouse) {
          final id = _parseInt(warehouse['id']);
          final name = warehouse['name']?.toString() ?? '-';
          return DropdownMenuItem<int?>(value: id, child: Text(name));
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedWarehouseOutletId = value;
        });
      },
    );
  }

  Widget _buildContent() {
    if (_errorMessage.isNotEmpty) {
      return _buildInfoState(_errorMessage, Icons.error_outline, Colors.red);
    }

    if (_selectedItem == null) {
      return _buildInfoState(
        'Pilih outlet, warehouse outlet, barang, dan periode tanggal lalu klik Load Data.',
        Icons.info_outline,
        Colors.blueGrey,
      );
    }

    if (_isLoadingData) {
      return const Center(child: AppLoadingIndicator(size: 22, color: Color(0xFF6366F1)));
    }

    if (_hasLoaded && _cards.isEmpty) {
      return _buildInfoState(
        'Tidak ada data kartu stok untuk item yang dipilih.',
        Icons.warning_amber_outlined,
        Colors.orange,
      );
    }

    if (_cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (_saldoAwal != null) _buildSaldoCard(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
            child: _buildListCard(),
          ),
        ),
        if (_filteredCards.isNotEmpty) _buildPagination(),
      ],
    );
  }

  Widget _buildSaldoCard() {
    final saldo = _saldoAwal!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Awal',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatQtyLine(saldo.small, saldo.smallUnitName)} | '
            '${_formatQtyLine(saldo.medium, saldo.mediumUnitName)} | '
            '${_formatQtyLine(saldo.large, saldo.largeUnitName)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }


  Widget _buildListCard() {
    final items = _paginatedCards;
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = items[index];
        final bgColor = index.isEven ? Colors.white : const Color(0xFFF8FAFC);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: const Color(0xFFE6EEF8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header row
              Row(
                children: [
                  Text(_formatDate(entry.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Flexible(
                    child: Text(entry.outletName ?? '-', style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // quantity columns with colored accents
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQtyColumn('Masuk', _formatQty(entry, 'in')),
                    _buildQtyColumn('Keluar', _formatQty(entry, 'out')),
                    _buildQtyColumn('Saldo', _formatSaldo(entry)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // reference and description
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('Referensi', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_buildReference(entry), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('Keterangan', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                  Expanded(
                    child: Text(entry.description ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

  Widget _buildQtyColumn(String title, String value) {
    final parts = value.split('|').map((s) => s.trim()).toList();
    Color numColor = const Color(0xFF0F172A);
    if (title.toLowerCase() == 'masuk') numColor = const Color(0xFF16A34A);
    if (title.toLowerCase() == 'keluar') numColor = const Color(0xFFDC2626);
    if (title.toLowerCase() == 'saldo') numColor = const Color(0xFF1E3A8A);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(_getIconForTitle(title), size: 16, color: numColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 6),
          for (final part in parts)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                part.isEmpty ? '-' : part,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: numColor),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('masuk')) return Icons.arrow_downward;
    if (t.contains('keluar')) return Icons.arrow_upward;
    return Icons.inventory_2;
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _pageNum > 1 ? _prevPage : null,
            child: const Text('Prev'),
          ),
          const SizedBox(width: 12),
          Text('Halaman $_pageNum dari $_totalPages'),
          const Spacer(),
          ElevatedButton(
            onPressed: _pageNum < _totalPages ? _nextPage : null,
            child: const Text('Next'),
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
}

class _ItemSearchModal extends StatefulWidget {
  final OutletStockPositionService service;
  final Map<String, dynamic>? initialItem;

  const _ItemSearchModal({
    required this.service,
    this.initialItem,
  });

  @override
  State<_ItemSearchModal> createState() => _ItemSearchModalState();
}

class _ItemSearchModalState extends State<_ItemSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchItems({String? search}) async {
    setState(() {
      _isLoading = true;
    });

    final items = await widget.service.getStockCardItems(search: search, limit: 200);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchItems(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari barang...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)),
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Barang tidak ditemukan'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final name = item['name']?.toString() ?? '-';
                  return ListTile(
                    title: Text(name),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
