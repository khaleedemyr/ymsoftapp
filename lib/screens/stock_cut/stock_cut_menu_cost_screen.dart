import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stock_cut_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'stock_cut_form_screen.dart';

class StockCutMenuCostScreen extends StatefulWidget {
  const StockCutMenuCostScreen({super.key});

  @override
  State<StockCutMenuCostScreen> createState() => _StockCutMenuCostScreenState();
}

class _StockCutMenuCostScreenState extends State<StockCutMenuCostScreen> {
  final StockCutService _service = StockCutService();
  List<Map<String, dynamic>> _outlets = [];
  int? _selectedOutletId;
  DateTime _selectedDate = DateTime.now();
  String _selectedType = '';
  bool _loadingOutlets = true;
  bool _loading = false;
  Map<String, dynamic>? _data;
  bool _hasSearched = false;
  final TextEditingController _searchMenuController = TextEditingController();
  final TextEditingController _searchModifierController = TextEditingController();
  final Set<int> _expandedMenuIds = <int>{};
  final Set<String> _expandedModifierNames = <String>{};

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  @override
  void dispose() {
    _searchMenuController.dispose();
    _searchModifierController.dispose();
    super.dispose();
  }

  Future<void> _loadOutlets() async {
    setState(() => _loadingOutlets = true);
    try {
      final result = await _service.getFormData();
      if (!mounted) return;
      if (result != null && result['success'] == true) {
        final outlets = result['outlets'];
        final rawList = outlets is List ? outlets : [];
        final list = rawList.map((e) {
          final m = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
          return {'id': m['id'] ?? m['id_outlet'], 'name': m['name'] ?? m['nama_outlet'] ?? ''};
        }).toList();
        setState(() {
          _outlets = List<Map<String, dynamic>>.from(list);
          _loadingOutlets = false;
        });
      } else {
        setState(() => _loadingOutlets = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOutlets = false);
    }
  }

  Future<void> _loadMenuCost() async {
    if (_selectedOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet')));
      return;
    }
    setState(() {
      _loading = true;
      _data = null;
      _hasSearched = true;
      _expandedMenuIds.clear();
      _expandedModifierNames.clear();
    });
    try {
      final result = await _service.getMenuCost(
        outletId: _selectedOutletId!,
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0,00';
    if (v is num) return NumberFormat('#,##0.00', 'id_ID').format(v);
    final s = v.toString().replaceAll(',', '');
    final n = num.tryParse(s);
    return n != null ? NumberFormat('#,##0.00', 'id_ID').format(n) : '0,00';
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, List<Map<String, dynamic>>> _filteredMenuGrouped() {
    final groupedRaw = _data?['menu_costs_grouped'];
    if (groupedRaw is! Map) return {};
    final q = _searchMenuController.text.trim().toLowerCase();
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in Map<String, dynamic>.from(groupedRaw).entries) {
      final rows = (entry.value as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((row) {
        if (q.isEmpty) return true;
        final itemName = row['item_name']?.toString().toLowerCase() ?? '';
        final category = row['category_name']?.toString().toLowerCase() ?? '';
        final subCategory = row['sub_category_name']?.toString().toLowerCase() ?? '';
        return itemName.contains(q) || category.contains(q) || subCategory.contains(q);
      }).toList();
      if (rows.isNotEmpty) result[entry.key] = rows;
    }
    return result;
  }

  Map<String, List<Map<String, dynamic>>> _filteredModifierGrouped() {
    final groupedRaw = _data?['modifier_costs_grouped'];
    if (groupedRaw is! Map) return {};
    final q = _searchModifierController.text.trim().toLowerCase();
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in Map<String, dynamic>.from(groupedRaw).entries) {
      final rows = (entry.value as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((row) {
        if (q.isEmpty) return true;
        final modifier = row['modifier_name']?.toString().toLowerCase() ?? '';
        final category = row['category_name']?.toString().toLowerCase() ?? '';
        return modifier.contains(q) || category.contains(q);
      }).toList();
      if (rows.isNotEmpty) result[entry.key] = rows;
    }
    return result;
  }

  String _formatPeriode(dynamic value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '-';
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOutlets) {
      return AppScaffold(
        title: 'Report Cost Menu',
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return AppScaffold(
      title: 'Report Cost Menu',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Log Stock Cut'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockCutFormScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Stock Cut'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Filter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey.shade800)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedOutletId,
                      decoration: InputDecoration(
                        labelText: 'Outlet',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _outlets.map((o) {
                        final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '0');
                        return DropdownMenuItem<int>(value: id, child: Text(o['name']?.toString() ?? ''));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedOutletId = v),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null && mounted) setState(() => _selectedDate = d);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tanggal',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey.shade600),
                              const SizedBox(width: 10),
                              Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Semua')),
                        DropdownMenuItem(value: 'food', child: Text('Food')),
                        DropdownMenuItem(value: 'beverages', child: Text('Beverages')),
                      ],
                      onChanged: (v) => setState(() => _selectedType = v ?? ''),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _loading ? null : _loadMenuCost,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_loading)
                                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              else
                                const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text('Cari', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: AppLoadingIndicator()),
              ),
            ] else if (_data != null &&
                (_filteredMenuGrouped().isNotEmpty || _filteredModifierGrouped().isNotEmpty)) ...[
              const SizedBox(height: 16),
              _buildSummary(),
              const SizedBox(height: 16),
              _buildMenuCostList(),
              const SizedBox(height: 12),
              _buildModifierCostList(),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calculate_outlined, size: 44, color: Colors.grey.shade500),
                    const SizedBox(height: 10),
                    Text(
                      _hasSearched
                          ? 'Tidak ada data cost menu untuk filter yang dipilih.'
                          : 'Pilih outlet dan tanggal, lalu klik Cari.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final d = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard('Total Menu', d['total_menu']?.toString() ?? '0', Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard('Total Modifier', d['total_modifier']?.toString() ?? '0', Colors.purple),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _summaryCard('Total Cost', 'Rp ${_fmt(d['total_cost'])}', Colors.green),
        const SizedBox(height: 8),
        _summaryCard('Total Revenue', 'Rp ${_fmt(d['total_revenue'])}', Colors.orange),
        const SizedBox(height: 8),
        _summaryCard('Total Profit', 'Rp ${_fmt(d['total_profit'])}', Colors.teal),
        const SizedBox(height: 8),
        _summaryCard('Profit Margin', '${_fmt(d['total_profit_margin'])}%', Colors.indigo),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard('Menu Cost', 'Rp ${_fmt(d['total_menu_cost'])}', Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard('Modifier Cost', 'Rp ${_fmt(d['total_modifier_cost'])}', Colors.purple),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Periode: ${_formatPeriode(d['periode'])}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color.shade700, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color.shade900, letterSpacing: -0.3)),
        ],
      ),
    );
  }

  Widget _buildMenuCostList() {
    final map = _filteredMenuGrouped();
    if (map.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Detail Cost Per Menu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey.shade800)),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _searchMenuController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari menu...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur export Excel akan segera tersedia'),
                  ),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(map.entries.map((e) {
          final catName = e.key;
          final menus = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${menus.length} menu', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              children: menus.map<Widget>((menu) {
                final itemId = _toInt(menu['item_id']);
                final isExpanded = _expandedMenuIds.contains(itemId);
                final bomDetails = (menu['bom_details'] as List? ?? const [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                return Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              menu['item_name']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sub Kategori: ${menu['sub_category_name'] ?? '-'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty: ${menu['qty_ordered'] ?? 0} • Cost/Unit: Rp ${_fmt(menu['cost_per_unit'])}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Cost: Rp ${_fmt(menu['total_cost'])} • Revenue: Rp ${_fmt(menu['total_revenue'])}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Profit: Rp ${_fmt(menu['profit'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _profitColor(menu['profit']),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${menu['profit_margin'] ?? 0}%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _profitColor(menu['profit']),
                                  ),
                                ),
                              ],
                            ),
                            if (bomDetails.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () => setState(() {
                                  if (isExpanded) {
                                    _expandedMenuIds.remove(itemId);
                                  } else {
                                    _expandedMenuIds.add(itemId);
                                  }
                                }),
                                child: Text(isExpanded ? 'Sembunyikan Detail BOM' : 'Tampilkan Detail BOM'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isExpanded)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: bomDetails.map((bom) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${bom['material_name'] ?? '-'} • '
                                  '${bom['qty_needed'] ?? 0} ${bom['unit_name'] ?? ''} • '
                                  'Rp ${_fmt(bom['cost_per_unit'])} • '
                                  'Total Rp ${_fmt(bom['total_cost'])}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        })),
      ],
    );
  }

  Color _profitColor(dynamic profit) {
    final n = num.tryParse(profit?.toString().replaceAll(',', '') ?? '0');
    if (n == null) return Colors.grey;
    return n >= 0 ? Colors.green : Colors.red;
  }

  Widget _buildModifierCostList() {
    final map = _filteredModifierGrouped();
    if (map.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Detail Cost Per Modifier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey.shade800)),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _searchModifierController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari modifier...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(map.entries.map((e) {
          final catName = e.key;
          final mods = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${mods.length} modifier', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              children: mods.map<Widget>((mod) {
                final name = mod['modifier_name']?.toString() ?? '-';
                final isExpanded = _expandedModifierNames.contains(name);
                final bomDetails = (mod['bom_details'] as List? ?? const [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                return Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        'Qty: ${mod['total_qty'] ?? 0} • Cost/Unit: Rp ${_fmt(mod['cost_per_unit'])} • Total: Rp ${_fmt(mod['total_cost'])}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      if (bomDetails.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => setState(() {
                            if (isExpanded) {
                              _expandedModifierNames.remove(name);
                            } else {
                              _expandedModifierNames.add(name);
                            }
                          }),
                          child: Text(isExpanded ? 'Sembunyikan Detail BOM' : 'Tampilkan Detail BOM'),
                        ),
                      ],
                      if (isExpanded)
                        ...bomDetails.map((bom) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${bom['material_name'] ?? '-'} • '
                                '${bom['qty_needed'] ?? 0} ${bom['unit_name'] ?? ''} • '
                                'Rp ${_fmt(bom['cost_per_unit'])} • '
                                'Total Rp ${_fmt(bom['total_cost'])}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            )),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        })),
      ],
    );
  }
}
