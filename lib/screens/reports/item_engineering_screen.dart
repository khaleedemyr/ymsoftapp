import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../services/auth_service.dart';
import '../../services/item_engineering_service.dart';

class ItemEngineeringScreen extends StatefulWidget {
  const ItemEngineeringScreen({super.key});

  @override
  State<ItemEngineeringScreen> createState() => _ItemEngineeringScreenState();
}

class _ItemEngineeringScreenState extends State<ItemEngineeringScreen> {
  final _authService = AuthService();
  final _service = ItemEngineeringService();

  final TextEditingController _dateFromC = TextEditingController();
  final TextEditingController _dateToC = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingOutlets = true;
  String? _error;
  int? _userOutletId;

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _regions = [];
  int? _selectedRegionId;
  String _selectedOutletCode = '';

  bool _hasReport = false;
  Map<String, dynamic> _itemsByCategory = {};
  List<Map<String, dynamic>> _modifiers = [];
  double _grandTotal = 0;
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _dateFromC.dispose();
    _dateToC.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final userData = await _authService.getUserData();
    _userOutletId = _toInt(userData?['id_outlet']);
    await _loadOutlets();
  }

  bool get _isHeadOffice => (_userOutletId ?? 1) == 1;

  Future<void> _loadOutlets() async {
    setState(() => _isLoadingOutlets = true);
    try {
      final outlets = await _authService.getOutlets();
      final uniqueOutlets = _dedupeOutlets(outlets);
      if (!mounted) return;

      _regions = _extractRegions(uniqueOutlets);

      if (!_isHeadOffice) {
        for (final o in uniqueOutlets) {
          final id = _toInt(o['id_outlet'] ?? o['id']);
          if (id == _userOutletId) {
            _selectedOutletCode = _outletCode(o);
            break;
          }
        }
      }

      setState(() {
        _outlets = uniqueOutlets;
        _isLoadingOutlets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOutlets = false);
    }
  }

  Future<void> _pickDate(TextEditingController c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: c.text.isEmpty ? DateTime.now() : (DateTime.tryParse(c.text) ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => c.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _fetchReport() async {
    if (_isHeadOffice && _selectedOutletCode.isEmpty && _selectedRegionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih outlet atau region terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _service.getReport(
        outletCode: _selectedOutletCode.isNotEmpty ? _selectedOutletCode : null,
        regionId: _selectedRegionId,
        dateFrom: _dateFromC.text.isNotEmpty ? _dateFromC.text : null,
        dateTo: _dateToC.text.isNotEmpty ? _dateToC.text : null,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        final rawData = res['data'];
        final data = rawData is Map<String, dynamic>
            ? rawData
            : Map<String, dynamic>.from(rawData as Map);

        final items = (data['items'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final itemsByCategory = _normalizeItemsByCategory(data['items_by_category'], items);

        final categoryNames = itemsByCategory.keys.toList();
        _expandedCategories.clear();
        if (categoryNames.isNotEmpty) _expandedCategories[categoryNames.first] = true;

        setState(() {
          _itemsByCategory = itemsByCategory;
          _modifiers = (data['modifiers'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _grandTotal = _toDouble(data['grand_total']);
          _hasReport = true;
        });
      } else {
        setState(() {
          _error = (res['message'] ?? 'Gagal memuat report').toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi error saat memuat report: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _normalizeItemsByCategory(
    dynamic rawItemsByCategory,
    List<Map<String, dynamic>> items,
  ) {
    if (rawItemsByCategory is Map) {
      return rawItemsByCategory.map((key, value) {
        final name = key?.toString() ?? '';
        final val = _normalizeCategoryValue(value);
        return MapEntry(name, val);
      });
    }

    if (rawItemsByCategory is List) {
      final map = <String, dynamic>{};
      for (final row in rawItemsByCategory.whereType<Map>()) {
        final m = Map<String, dynamic>.from(row);
        final categoryName = (m['category_name'] ?? m['category'] ?? '').toString();
        map[categoryName] = _normalizeCategoryValue(m);
      }
      if (map.isNotEmpty) return map;
    }

    // Fallback: build category groups from plain items list.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final categoryName = (item['category_name'] ?? '').toString();
      grouped.putIfAbsent(categoryName, () => []).add(item);
    }

    final result = <String, dynamic>{};
    grouped.forEach((category, rows) {
      double totalQty = 0;
      double totalSubtotal = 0;
      for (final r in rows) {
        totalQty += _toDouble(r['qty_terjual']);
        totalSubtotal += _toDouble(r['subtotal']);
      }
      result[category] = {
        'items': rows,
        'total_qty': totalQty,
        'total_subtotal': totalSubtotal,
      };
    });
    return result;
  }

  Map<String, dynamic> _normalizeCategoryValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      final items = (value['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return {
        'items': items,
        'total_qty': value['total_qty'] ?? items.fold<double>(0, (p, e) => p + _toDouble(e['qty_terjual'])),
        'total_subtotal': value['total_subtotal'] ?? items.fold<double>(0, (p, e) => p + _toDouble(e['subtotal'])),
      };
    }

    if (value is Map) {
      return _normalizeCategoryValue(Map<String, dynamic>.from(value));
    }

    if (value is List) {
      final items = value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return {
        'items': items,
        'total_qty': items.fold<double>(0, (p, e) => p + _toDouble(e['qty_terjual'])),
        'total_subtotal': items.fold<double>(0, (p, e) => p + _toDouble(e['subtotal'])),
      };
    }

    return {
      'items': <Map<String, dynamic>>[],
      'total_qty': 0,
      'total_subtotal': 0,
    };
  }

  List<Map<String, dynamic>> get _filteredOutlets {
    if (_selectedRegionId == null) return _outlets;
    return _outlets.where((o) {
      final regionId = _toInt(o['region_id']);
      return regionId == _selectedRegionId;
    }).toList();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  String _outletCode(Map<String, dynamic> outlet) {
    final qr = (outlet['qr_code'] ?? '').toString().trim();
    if (qr.isNotEmpty) return qr;
    final kode = (outlet['kode_outlet'] ?? outlet['outlet_code'] ?? '').toString().trim();
    if (kode.isNotEmpty) return kode;
    return (outlet['id_outlet'] ?? outlet['id'] ?? '').toString().trim();
  }

  String _outletName(Map<String, dynamic> outlet) {
    final name = (outlet['name'] ?? outlet['nama_outlet'] ?? '').toString().trim();
    return name.isNotEmpty ? name : _outletCode(outlet);
  }

  List<Map<String, dynamic>> _dedupeOutlets(List<Map<String, dynamic>> raw) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final o in raw) {
      final key = _outletCode(o);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(o);
    }
    return result;
  }

  List<Map<String, dynamic>> _extractRegions(List<Map<String, dynamic>> outlets) {
    final map = <int, String>{};
    for (final o in outlets) {
      final id = _toInt(o['region_id']);
      if (id <= 0) continue;
      final name = (o['region_name'] ?? o['region'] ?? '').toString().trim();
      map[id] = name.isNotEmpty ? name : 'Region $id';
    }
    return map.entries.map((e) => {'id': e.key, 'name': e.value}).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  String _formatCurrency(dynamic value) {
    final n = _toDouble(value);
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(n);
  }

  String _formatNum(dynamic value) {
    final n = _toDouble(value);
    return NumberFormat('#,##0.##', 'id_ID').format(n);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Item Engineering',
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator(size: 30, color: Color(0xFF6366F1)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : !_hasReport
                        ? const Center(child: Text('Pilih filter lalu tap Tampilkan'))
                        : _buildReportBody(),
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text('Filter Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (_isHeadOffice && _regions.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedRegionId,
              decoration: _inputDec('Region'),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Semua Region')),
                ..._regions.map(
                  (r) => DropdownMenuItem<int>(
                    value: _toInt(r['id']),
                    child: Text(r['name']?.toString() ?? '-'),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedRegionId = v;
                  _selectedOutletCode = '';
                });
              },
            ),
            const SizedBox(height: 8),
          ],
          if (_isHeadOffice) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedOutletCode.isEmpty ? null : _selectedOutletCode,
              decoration: _inputDec('Outlet'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Semua Outlet')),
                ..._filteredOutlets.map(
                  (o) => DropdownMenuItem<String>(
                    value: _outletCode(o),
                    child: Text(_outletName(o)),
                  ),
                ),
              ],
              onChanged: _isLoadingOutlets ? null : (v) => setState(() => _selectedOutletCode = v ?? ''),
            ),
            const SizedBox(height: 8),
          ] else ...[
            TextFormField(
              readOnly: true,
              initialValue: _filteredOutlets
                  .where((o) => _outletCode(o) == _selectedOutletCode)
                  .map(_outletName)
                  .firstWhere((_) => true, orElse: () => '-'),
              decoration: _inputDec('Outlet'),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dateFromC,
                  readOnly: true,
                  decoration: _inputDec('Tanggal From').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: () => _pickDate(_dateFromC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _dateToC,
                  readOnly: true,
                  decoration: _inputDec('Tanggal To').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: () => _pickDate(_dateToC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoadingOutlets ? null : _fetchReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tampilkan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _sectionTitle(
          icon: Icons.category_outlined,
          title: 'Item Engineering by Category',
        ),
        const SizedBox(height: 8),
        ..._itemsByCategory.entries.map((entry) {
          final categoryName = entry.key.isEmpty ? 'Uncategorized' : entry.key;
          final data = Map<String, dynamic>.from(entry.value as Map);
          final rows = (data['items'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final expanded = _expandedCategories[categoryName] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => setState(() => _expandedCategories[categoryName] = !expanded),
                  contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  leading: Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  title: Text(
                    categoryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    'Qty ${_formatNum(data['total_qty'])} • Sales ${_formatCurrency(data['total_subtotal'])} • Items ${rows.length.toString()}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                  ),
                ),
                if (expanded) ...[
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                  ...rows.asMap().entries.map((r) {
                    final idx = r.key + 1;
                    final item = r.value;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$idx. ${item['item_name'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15.2,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Qty ${_formatNum(item['qty_terjual'])} • Harga ${_formatCurrency(item['harga_jual'])}',
                                  style: const TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontSize: 13.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatCurrency(item['subtotal']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.2,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      border: Border(top: BorderSide(color: Colors.blue.withValues(alpha: 0.16))),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Category Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        Text(
                          _formatCurrency(data['total_subtotal']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF166534), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Grand Total Summary',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                ),
              ),
              Text(
                _formatCurrency(_grandTotal),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF166534),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle(
          icon: Icons.tune_rounded,
          title: 'Modifier Engineering',
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _modifiers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tidak ada modifier',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                )
              : Column(
                  children: _modifiers.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final mod = entry.value;
                    return Container(
                      decoration: BoxDecoration(
                        border: entry.key == _modifiers.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$idx. ${mod['name'] ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _formatNum(mod['qty']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _sectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

