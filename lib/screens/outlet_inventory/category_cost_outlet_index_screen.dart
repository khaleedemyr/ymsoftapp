import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/outlet_category_cost_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'category_cost_outlet_detail_screen.dart';

class CategoryCostOutletIndexScreen extends StatefulWidget {
  const CategoryCostOutletIndexScreen({super.key});

  @override
  State<CategoryCostOutletIndexScreen> createState() => _CategoryCostOutletIndexScreenState();
}

class _CategoryCostOutletIndexScreenState extends State<CategoryCostOutletIndexScreen> {
  final _service = OutletCategoryCostService();
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingFilters = false;
  String _search = '';
  int? _selectedOutletId;
  
  String? _selectedType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _filterExpanded = true;
  bool _outletSelectable = true;
  int? _userOutletId;
  String? _outletName;

  List<Map<String, dynamic>> _outlets = [];

  int _page = 1;
  int _perPage = 10;
  int _lastPage = 1;

  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  final List<Map<String, String>> _typeOptions = [
    {'value': '', 'label': 'All'},
    {'value': 'internal_use', 'label': 'Internal Use'},
    {'value': 'spoil', 'label': 'Spoil'},
    {'value': 'waste', 'label': 'Waste'},
    {'value': 'r_and_d', 'label': 'R & D'},
    {'value': 'marketing', 'label': 'Marketing'},
    {'value': 'non_commodity', 'label': 'Non Commodity'},
    {'value': 'guest_supplies', 'label': 'Guest Supplies'},
    {'value': 'wrong_maker', 'label': 'Wrong Maker'},
    {'value': 'training', 'label': 'Training'},
  ];

  final Map<String, String> _typeLabels = {
    'internal_use': 'Internal Use',
    'spoil': 'Spoil',
    'waste': 'Waste',
    'r_and_d': 'R & D',
    'marketing': 'Marketing',
    'non_commodity': 'Non Commodity',
    'guest_supplies': 'Guest Supplies',
    'wrong_maker': 'Wrong Maker',
    'training': 'Training',
  };

  @override
  void initState() {
    super.initState();
    _loadFiltersAndList();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_isLoadingMore && !_isLoading && _page < _lastPage) {
        _loadList(page: _page + 1, append: true);
      }
    }
  }

  Future<void> _loadFiltersAndList() async {
    setState(() {
      _isLoading = true;
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
        final outs = await _service.getOutlets();
        setState(() => _outlets = outs);
      } else if (_userOutletId != null) {
        _selectedOutletId = _userOutletId;
        setState(() {
          _outlets = [
            {'id_outlet': _userOutletId, 'nama_outlet': _outletName ?? '-'}
          ];
        });
      }

    } catch (e) {
      setState(() => _outlets = []);
    } finally {
      if (mounted) {
        setState(() => _isLoadingFilters = false);
      }
    }
    await _loadList();
  }

  Future<void> _loadList({int page = 1, bool append = false}) async {
    if (append) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }
    _page = page;
    print('Index._loadList: outlet=$_selectedOutletId search=$_search type=$_selectedType dateFrom=$_dateFrom dateTo=$_dateTo page=$_page perPage=$_perPage');

    final resp = await _service.getList(
      outletId: _selectedOutletId,
      search: _search,
      page: _page,
      perPage: _perPage,
      type: _selectedType,
      dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
      dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
    );
    print('Index._loadList: response received: ${resp == null ? 'null' : resp.runtimeType}');

    if (resp != null) {
      List<Map<String, dynamic>> newItems = [];
      final dataSection = resp['data'];
      if (dataSection is List) {
        newItems = List<Map<String, dynamic>>.from(dataSection);
      } else if (dataSection is Map) {
        final nested = dataSection['data'];
        if (nested is List) {
          newItems = List<Map<String, dynamic>>.from(nested);
        }
        final metaLast = dataSection['last_page'] ?? (dataSection['meta'] is Map ? dataSection['meta']['last_page'] : null);
        if (metaLast is int) {
          _lastPage = metaLast;
        }
      }

      if (append) {
        _items.addAll(newItems);
      } else {
        _items = newItems;
      }
      try {
        print('Index._loadList: items count=${_items.length} sample=${jsonEncode(_items.isNotEmpty ? _items.first : {})}');
      } catch (e) {
        print('Index._loadList: could not jsonEncode items sample: $e');
      }
    } else if (!append) {
      _items = [];
    }

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _search = '';
      _selectedOutletId = _outletSelectable ? null : _userOutletId;
      _selectedType = null;
      _dateFrom = null;
      _dateTo = null;
      _page = 1;
    });
    _loadList(page: 1);
  }

  void _openDetail(Map<String, dynamic> raw) async {
    final id = raw['id'] is int ? raw['id'] : int.tryParse('${raw['id'] ?? ''}') ?? 0;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryCostOutletDetailScreen(id: id)),
    );
    _loadList(page: _page);
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateFrom = picked);
      _loadList(page: 1);
    }
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateTo = picked);
      _loadList(page: 1);
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Category Cost Outlet')),
      body: Column(
        children: [
          _buildFilterHeader(),
          if (_filterExpanded) _buildFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadList(page: 1),
              child: _buildListContent(),
            ),
          ),
          if (!_isLoading) _buildPaginationRow(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryCostOutletDetailScreen(id: 0)),
          );
          _loadList(page: 1);
        },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingFilters)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nomor / outlet / warehouse / pembuat',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _search = value,
            onSubmitted: (value) {
              _search = value;
              _loadList(page: 1);
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final isNarrow = maxWidth < 520;
                  final twoColumnWidth = maxWidth > 600 ? (maxWidth - 12) / 2 : maxWidth;
                  final fieldWidth = isNarrow
                    ? maxWidth
                    : min(maxWidth, min(320.0, max(220.0, twoColumnWidth)));
                  final dateFieldWidth = isNarrow ? maxWidth : min(maxWidth, min(240.0, twoColumnWidth));
                  final perPageWidth = min(isNarrow ? maxWidth : 140.0, maxWidth);

              return Wrap(
                alignment: WrapAlignment.start,
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _buildOutletField(),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      isExpanded: true,
                      items: _typeOptions
                          .map((t) => DropdownMenuItem<String>(value: t['value'], child: Text(t['label']!)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                        _loadList(page: 1);
                      },
                    ),
                  ),
                  SizedBox(
                    width: dateFieldWidth,
                    child: _buildDateFilter('Date From', _dateFrom, _pickDateFrom),
                  ),
                  SizedBox(
                    width: dateFieldWidth,
                    child: _buildDateFilter('Date To', _dateTo, _pickDateTo),
                  ),
                  SizedBox(
                    width: perPageWidth,
                    child: DropdownButtonFormField<int>(
                      value: _perPage,
                      decoration: const InputDecoration(labelText: 'Per page'),
                      isExpanded: true,
                      items: [10, 25, 50, 100]
                          .map((value) => DropdownMenuItem<int>(value: value, child: Text('$value')))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _perPage = value;
                          });
                          _loadList(page: 1);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _resetFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Reset filters'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _loadList(page: 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Refresh list'),
                ),
              ),
            ],
          ),
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

  Widget _buildOutletField() {
    if (!_outletSelectable) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Outlet (admin)',
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

    return DropdownButtonFormField<int>(
      value: _selectedOutletId,
      decoration: const InputDecoration(labelText: 'Outlet (admin)'),
      isExpanded: true,
      items: _outlets
          .map((o) {
            final id = o['id_outlet'] ?? o['id'];
            final label = o['nama_outlet'] ?? o['name'] ?? '';
            return DropdownMenuItem<int>(value: int.tryParse('$id'), child: Text(label));
          })
          .where((item) => item.value != null)
          .toList(),
      onChanged: (value) async {
        setState(() {
          _selectedOutletId = value;
        });
        _loadList(page: 1);
      },
    );
  }

  Widget _buildDateFilter(String label, DateTime? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(value == null ? '-' : DateFormat('yyyy-MM-dd').format(value)),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: const [Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)))],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: const [Center(child: Text('No data. Adjust filters or try search.'))],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1))),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildItemCard(_items[index]),
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final reference = item['reference'] ?? item['number'] ?? item['id']?.toString() ?? '';
    final dateText = _formatDisplayDate(item['date'] ?? item['created_at']);
    final outletName = item['outlet_name'] ?? item['nama_outlet'] ?? '-';
    final warehouseName = item['warehouse_outlet_name'] ?? item['warehouse_name'] ?? '-';
    final creator = _getCreatorName(item);
    final total = _extractTotal(item);
    final status = item['status']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reference,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        _buildTypeChip(type),
                        const SizedBox(width: 6),
                      ],
                      if (status.isNotEmpty) _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      const Spacer(),
                      Text(
                        'Total: ${NumberFormat.currency(symbol: '', decimalDigits: 0).format(total)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Outlet', outletName),
                  _buildInfoRow('Warehouse', warehouseName),
                  _buildInfoRow('Dibuat', creator),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> item) {
    final creatorName = _getCreatorName(item);
    final avatarUrl = _getAvatarUrl(_extractAvatarRaw(item));
    final initials = _getInitials(creatorName);

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)))
          : null,
    );
  }

  String _getCreatorName(Map<String, dynamic> item) {
    return item['creator_name'] ?? item['created_by_name'] ?? item['creator'] ?? '-';
  }

  String? _extractAvatarRaw(Map<String, dynamic> item) {
    final direct = item['creator_avatar'] ??
        item['creator_avatar_url'] ??
        item['creator_photo'] ??
        item['creator_photo_url'] ??
        item['created_by_avatar'] ??
        item['avatar'] ??
        item['avatar_url'] ??
        item['photo'] ??
        item['photo_url'];
    if (direct != null) return direct.toString();

    final creator = item['creator'];
    if (creator is Map) {
      final nested = creator['avatar'] ?? creator['photo'] ?? creator['avatar_url'] ?? creator['photo_url'];
      if (nested != null) return nested.toString();
    }

    final user = item['user'];
    if (user is Map) {
      final nested = user['avatar'] ?? user['photo'] ?? user['avatar_url'] ?? user['photo_url'];
      if (nested != null) return nested.toString();
    }

    return null;
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) {
      return '${AuthService.storageUrl}/$normalized';
    }
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final normalized = status.toLowerCase();
    Color bg;
    Color fg;

    if (normalized.contains('process')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized.contains('reject') || normalized.contains('cancel')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else if (normalized.contains('waiting')) {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFE2E8F0);
      fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        _statusLabel(normalized),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _statusLabel(String normalized) {
    if (normalized.contains('process')) return 'Processed';
    if (normalized.contains('reject')) return 'Rejected';
    if (normalized.contains('cancel')) return 'Canceled';
    if (normalized.contains('waiting')) return 'Waiting';
    return normalized.isNotEmpty ? normalized.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ') : '-';
  }

  Widget _buildTypeChip(String type) {
    final normalized = type.toLowerCase();
    final label = _typeLabels[normalized] ?? _humanizeType(normalized);
    final colors = _typeChipColors(normalized);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.foreground)),
    );
  }

  _ChipColors _typeChipColors(String normalized) {
    if (normalized == 'internal_use') return _ChipColors(const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
    if (normalized == 'spoil') return _ChipColors(const Color(0xFFFEE2E2), const Color(0xFF9C4221));
    if (normalized == 'waste') return _ChipColors(const Color(0xFFFDE68A), const Color(0xFF92400E));
    if (normalized == 'r_and_d') return _ChipColors(const Color(0xFFE0E7FF), const Color(0xFF4338CA));
    return _ChipColors(const Color(0xFFE2E8F0), const Color(0xFF475569));
  }

  String _humanizeType(String value) {
    if (value.isEmpty) return '-';
    return value.split('_').map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }

  String _formatDisplayDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      final date = raw is String ? DateTime.parse(raw) : (raw is DateTime ? raw : DateTime.tryParse(raw.toString()));
      if (date == null) return raw.toString();
      return _displayDateFormat.format(date);
    } catch (e) {
      return raw.toString();
    }
  }

  num _extractTotal(Map<String, dynamic> item) {
    final value = item['total_cost'] ??
        item['total'] ??
        item['subtotal_mac'] ??
        item['total_value'] ??
        item['grand_total'] ??
        item['amount'] ??
        item['total_cost_value'] ??
        item['total_cost_amount'] ??
        item['total_cost_sum'] ??
        0;
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildPaginationRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page $_page / $_lastPage'),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1 ? () => _loadList(page: _page - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < _lastPage ? () => _loadList(page: _page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipColors {
  final Color background;
  final Color foreground;

  const _ChipColors(this.background, this.foreground);
}
