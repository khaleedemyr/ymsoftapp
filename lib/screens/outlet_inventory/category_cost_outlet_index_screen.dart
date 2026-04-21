import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/outlet_category_cost_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/category_cost_type_label.dart';
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
  bool _isLoadingFilters = false;
  int? _deletingId;
  String _search = '';
  int? _selectedOutletId;
  
  String? _selectedType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _filterExpanded = false;
  bool _outletSelectable = true;
  int? _userOutletId;
  String? _outletName;

  List<Map<String, dynamic>> _outlets = [];

  int _page = 1;
  int _perPage = 10;
  int _lastPage = 1;
  int _totalResults = 0;
  int _fromRow = 0;
  int _toRow = 0;

  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  final List<Map<String, String>> _typeOptions = [
    {'value': '', 'label': 'All Types'},
    {'value': 'internal_use', 'label': 'Internal Use'},
    {'value': 'spoil', 'label': 'Spoil'},
    {'value': 'waste', 'label': 'Waste'},
    {'value': 'usage', 'label': 'Usage'},
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
    'usage': 'Usage',
    'stock_cut': 'Usage',
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadList({int page = 1}) async {
    setState(() => _isLoading = true);
    _page = page;

    final resp = await _service.getList(
      outletId: _selectedOutletId,
      search: _search,
      page: _page,
      perPage: _perPage,
      type: _selectedType,
      dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
      dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
    );

    if (resp != null) {
      List<Map<String, dynamic>> newItems = [];
      final dataSection = resp['data'];
      if (dataSection is List) {
        newItems = List<Map<String, dynamic>>.from(dataSection);
        _lastPage = 1;
        _totalResults = newItems.length;
        _fromRow = newItems.isEmpty ? 0 : 1;
        _toRow = newItems.length;
      } else if (dataSection is Map) {
        final nested = dataSection['data'];
        if (nested is List) {
          newItems = List<Map<String, dynamic>>.from(nested);
        }
        final metaLast = dataSection['last_page'] ?? (dataSection['meta'] is Map ? dataSection['meta']['last_page'] : null);
        if (metaLast != null) {
          _lastPage = metaLast is int ? metaLast : int.tryParse('$metaLast') ?? 1;
        }
        final total = dataSection['total'];
        _totalResults = total is int ? total : int.tryParse('$total') ?? 0;
        final from = dataSection['from'];
        _fromRow = from is int ? from : int.tryParse('$from') ?? 0;
        final to = dataSection['to'];
        _toRow = to is int ? to : int.tryParse('$to') ?? 0;
      }
      _items = newItems;
    } else {
      _items = [];
      _totalResults = 0;
      _fromRow = 0;
      _toRow = 0;
    }

    setState(() => _isLoading = false);
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _search = '';
      _selectedOutletId = _outletSelectable ? null : _userOutletId;
      _selectedType = null;
      _dateFrom = null;
      _dateTo = null;
      _perPage = 10;
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

  Future<void> _openReportUniversal() async {
    final uri = Uri.parse('${AuthService.baseUrl}/outlet-internal-use-waste/report-universal');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok && mounted) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka laporan di browser')),
        );
      }
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryCostOutletDetailScreen(id: 0)),
    );
    _loadList(page: 1);
  }

  Future<void> _editDraft(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryCostOutletDetailScreen(id: id)),
    );
    _loadList(page: _page);
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakin hapus data ini?'),
        content: const Text('Stok akan di-rollback otomatis!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingId = id);
    final res = await _service.deleteHeader(id);
    if (!mounted) return;
    setState(() => _deletingId = null);

    final success = res != null && (res['success'] == true || res['success'] == 'true');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Data berhasil dihapus dan stok di-rollback!'
              : (res?['message']?.toString() ?? 'Gagal menghapus data'),
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
    if (success) await _loadList(page: _page);
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
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static const Color _appBarBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _appBarBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 104,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.sync, color: Colors.green.shade300, size: 22),
              onPressed: _isLoading ? null : () => _loadList(page: _page),
            ),
          ],
        ),
        title: TextButton.icon(
          onPressed: _openReportUniversal,
          icon: const Icon(Icons.description_outlined, color: Colors.white, size: 22),
          label: const Text(
            'Laporan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
            child: FilledButton.icon(
              onPressed: _openCreate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text('+ Tambah Baru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: RefreshIndicator(
              color: _appBarBlue,
              onRefresh: () => _loadList(page: 1),
              child: _buildListContent(),
            ),
          ),
          if (!_isLoading) _buildPaginationRow(),
        ],
      ),
    );
  }

  /// Filter + isian dalam satu kartu putih (seperti Outlet Transfer / mockup).
  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_filterExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ),
                  Icon(
                    _filterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_filterExpanded) _buildFilterCardInner(),
        ],
      ),
    );
  }

  Widget _buildFilterCardInner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingFilters)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const Text(
            'Search',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by number, outlet, warehouse, or creator...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _search = value,
            onSubmitted: (_) => _applyFiltersFromInputs(),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isNarrow = maxWidth < 520;
              final twoColumnWidth = maxWidth > 600 ? (maxWidth - 12) / 2 : maxWidth;
              final fieldWidth = isNarrow ? maxWidth : min(maxWidth, min(320.0, max(220.0, twoColumnWidth)));
              final dateFieldWidth = isNarrow ? maxWidth : min(maxWidth, min(240.0, twoColumnWidth));
              final perPageWidth = min(isNarrow ? maxWidth : 140.0, maxWidth);

              return Wrap(
                alignment: WrapAlignment.start,
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: fieldWidth, child: _buildOutletField()),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('cc_type_${_selectedType ?? ''}'),
                      value: _selectedType ?? '',
                      decoration: const InputDecoration(labelText: 'Type'),
                      isExpanded: true,
                      items: _typeOptions
                          .map((t) => DropdownMenuItem<String>(value: t['value'], child: Text(t['label']!)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = (value == null || value.isEmpty) ? null : value;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: dateFieldWidth, child: _buildDateFilter('Date From', _dateFrom, _pickDateFrom)),
                  SizedBox(width: dateFieldWidth, child: _buildDateFilter('Date To', _dateTo, _pickDateTo)),
                  SizedBox(
                    width: perPageWidth,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<int>(_perPage),
                      value: _perPage,
                      decoration: const InputDecoration(labelText: 'Per page'),
                      isExpanded: true,
                      items: [10, 25, 50, 100]
                          .map((value) => DropdownMenuItem<int>(value: value, child: Text('$value')))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _perPage = value);
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
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFiltersFromInputs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('Apply Filters'),
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
      key: ValueKey<int?>(_selectedOutletId),
      value: _selectedOutletId,
      decoration: const InputDecoration(labelText: 'Outlet'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All Outlets'),
        ),
        ..._outlets.map((o) {
          final id = o['id_outlet'] ?? o['id'];
          final label = o['nama_outlet'] ?? o['name'] ?? '';
          return DropdownMenuItem<int?>(value: int.tryParse('$id'), child: Text('$label'));
        }).where((item) => item.value != null),
      ],
      onChanged: (value) async {
        setState(() {
          _selectedOutletId = value;
        });
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

  void _applyFiltersFromInputs() {
    _search = _searchController.text.trim();
    _loadList(page: 1);
  }

  int _parseRowId(Map<String, dynamic> row) {
    final raw = row['id'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}') ?? 0;
  }

  String _creatorDisplayName(Map<String, dynamic> item) {
    return item['creator_name']?.toString() ??
        item['created_by_name']?.toString() ??
        (item['creator'] is Map ? (item['creator'] as Map)['nama_lengkap']?.toString() : null) ??
        '-';
  }

  String _creatorInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first.substring(0, 1).toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Kartu daftar — pola sama dengan `OutletTransferIndexScreen._buildTransferCard`.
  Widget _buildCategoryCostCard(Map<String, dynamic> item) {
    final id = _parseRowId(item);
    final number = '${item['number'] ?? item['reference'] ?? item['id'] ?? '-'}';
    final isDraftNumber = number.startsWith('DRAFT-');
    final typeKey = item['type']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final creatorName = _creatorDisplayName(item);
    final outletName = item['outlet_name'] ?? item['nama_outlet'] ?? '-';
    final wh = item['warehouse_outlet_name'] ?? item['warehouse_name'] ?? '-';
    final deleting = _deletingId == id;
    final flows = (item['approval_flows'] as List?) ?? [];

    return InkWell(
      onTap: id > 0 ? () => _openDetail(item) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: Text(
                    _creatorInitials(creatorName),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 104,
                  child: Text(
                    creatorName,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          number,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDraftNumber ? Colors.orange.shade800 : Colors.blue.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildErpStatusChip(status),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: Icon(Icons.more_vert, size: 22, color: Colors.grey.shade600),
                        onSelected: (v) {
                          if (v == 'detail') _openDetail(item);
                          if (v == 'edit') _editDraft(id);
                          if (v == 'delete') _confirmDelete(id);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'detail', child: Text('Detail')),
                          if (status == 'DRAFT')
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            enabled: !deleting,
                            child: deleting
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red.shade700),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('Menghapus…'),
                                    ],
                                  )
                                : Text('Hapus', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDisplayDate(item['date'] ?? item['created_at']),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                            ),
                            Text(
                              _formatTime(item['created_at']),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoPill(Icons.layers_outlined, _typeDisplayLabel(typeKey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.store_rounded, size: 16, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$outletName',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              wh.toString(),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (flows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Approval',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: flows.map<Widget>((f) {
                        if (f is! Map) return const SizedBox.shrink();
                        final m = Map<String, dynamic>.from(f);
                        final lvl = m['approval_level'];
                        final st = (m['status'] ?? '').toString();
                        return Tooltip(
                          message: 'Level $lvl: $st',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _approvalToneBg(st),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'L$lvl',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _approvalToneFg(st)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _approvalToneBg(String status) {
    final u = status.toUpperCase();
    if (u == 'APPROVED') return Colors.green.shade100;
    if (u == 'REJECTED') return Colors.red.shade100;
    if (u == 'PENDING') return Colors.amber.shade100;
    return Colors.grey.shade200;
  }

  Color _approvalToneFg(String status) {
    final u = status.toUpperCase();
    if (u == 'APPROVED') return Colors.green.shade800;
    if (u == 'REJECTED') return Colors.red.shade800;
    if (u == 'PENDING') return Colors.amber.shade900;
    return Colors.grey.shade800;
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErpStatusChip(String status) {
    final u = status.toUpperCase();
    Color bg;
    Color fg;
    String label;
    switch (u) {
      case 'DRAFT':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'Draft';
        break;
      case 'SUBMITTED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Menunggu';
        break;
      case 'APPROVED':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        label = 'Disetujui';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Ditolak';
        break;
      case 'PROCESSED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Diproses';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = status.isEmpty ? '-' : status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildListContent() {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: [
          Center(child: AppLoadingIndicator(size: 28, color: _appBarBlue)),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: [
          Center(
            child: Text(
              'Tidak ada data.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildCategoryCostCard(_items[index]),
    );
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '-';
    try {
      final date = raw is String ? DateTime.tryParse(raw) : (raw is DateTime ? raw : DateTime.tryParse(raw.toString()));
      if (date == null) return '-';
      return _timeFormat.format(date.toLocal());
    } catch (_) {
      return '-';
    }
  }

  String _typeDisplayLabel(String typeKey) {
    final k = typeKey.toLowerCase();
    if (_typeLabels.containsKey(k)) return _typeLabels[k]!;
    return categoryCostTypeLabel(k);
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

  Widget _buildPaginationRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Showing $_fromRow to $_toRow of $_totalResults results',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1 ? () => _loadList(page: _page - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_page / $_lastPage', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
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
