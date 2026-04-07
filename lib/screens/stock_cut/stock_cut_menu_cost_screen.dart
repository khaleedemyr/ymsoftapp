import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stock_cut_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOutlets();
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
    if (v == null) return '0';
    if (v is num) return NumberFormat('#,##0', 'id_ID').format(v);
    final s = v.toString().replaceAll(',', '');
    final n = num.tryParse(s);
    return n != null ? NumberFormat('#,##0', 'id_ID').format(n) : v.toString();
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
            if (_data != null) ...[
              const SizedBox(height: 16),
              _buildSummary(),
              const SizedBox(height: 16),
              _buildMenuCostList(),
              const SizedBox(height: 12),
              _buildModifierCostList(),
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
    final grouped = _data!['menu_costs_grouped'];
    if (grouped is! Map || grouped.isEmpty) return const SizedBox.shrink();
    final map = Map<String, dynamic>.from(grouped as Map);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Detail Cost Per Menu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey.shade800)),
        ),
        ...(map.entries.map((e) {
          final catName = e.key;
          final menus = e.value is List ? e.value as List : [];
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
              children: menus.map<Widget>((m) {
                final menu = m is Map ? Map<String, dynamic>.from(m as Map) : <String, dynamic>{};
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(menu['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Qty: ${menu['qty_ordered']} • Rp ${_fmt(menu['total_cost'])}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Text('${menu['profit_margin'] ?? '-'}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(menu['profit']))),
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
    final grouped = _data!['modifier_costs_grouped'];
    if (grouped is! Map || grouped.isEmpty) return const SizedBox.shrink();
    final map = Map<String, dynamic>.from(grouped as Map);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Detail Cost Per Modifier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey.shade800)),
        ),
        ...(map.entries.map((e) {
          final catName = e.key;
          final mods = e.value is List ? e.value as List : [];
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
              children: mods.map<Widget>((m) {
                final mod = m is Map ? Map<String, dynamic>.from(m as Map) : <String, dynamic>{};
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mod['modifier_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Qty: ${mod['total_qty']} • Rp ${_fmt(mod['total_cost'])}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
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
}
