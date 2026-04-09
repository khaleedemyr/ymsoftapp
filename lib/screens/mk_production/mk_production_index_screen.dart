import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mk_production_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'mk_production_create_screen.dart';
import 'mk_production_detail_screen.dart';

class MKProductionIndexScreen extends StatefulWidget {
  const MKProductionIndexScreen({super.key});

  @override
  State<MKProductionIndexScreen> createState() => _MKProductionIndexScreenState();
}

class _MKProductionIndexScreenState extends State<MKProductionIndexScreen> {
  final MKProductionService _service = MKProductionService();
  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _fromC = TextEditingController();
  final TextEditingController _toC = TextEditingController();
  final ScrollController _scrollC = ScrollController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _itemOptions = [];
  String? _selectedItemId;
  bool _loading = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadCreateData();
    _load(isRefresh: true);
    _scrollC.addListener(() {
      if (_scrollC.position.pixels >= _scrollC.position.maxScrollExtent - 150 && !_loading && _hasMore) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    _fromC.dispose();
    _toC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final data = await _service.getCreateData();
    if (!mounted || data == null) return;
    final list = (data['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    setState(() => _itemOptions = list);
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (isRefresh) {
      _page = 1;
      _hasMore = true;
      _items = [];
    }
    setState(() => _loading = true);
    final result = await _service.getList(
      page: _page,
      perPage: 15,
      search: _searchC.text.trim().isEmpty ? null : _searchC.text.trim(),
      itemId: _selectedItemId,
      fromDate: _fromC.text.isEmpty ? null : _fromC.text,
      toDate: _toC.text.isEmpty ? null : _toC.text,
    );
    if (!mounted) return;
    final data = (result?['data'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      if (isRefresh) {
        _items = data;
      } else {
        _items.addAll(data);
      }
      _hasMore = data.length >= 15;
      if (_hasMore) _page++;
      _loading = false;
    });
  }

  Future<void> _pickDate(TextEditingController c) async {
    final d = await showDatePicker(
      context: context,
      initialDate: c.text.isEmpty ? DateTime.now() : (DateTime.tryParse(c.text) ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => c.text = DateFormat('yyyy-MM-dd').format(d));
  }

  String get _selectedItemName {
    if (_selectedItemId == null) return 'Semua Item';
    final selected = _itemOptions.cast<Map<String, dynamic>?>().firstWhere(
          (e) => (e?['id'] ?? '').toString() == _selectedItemId,
          orElse: () => null,
        );
    return selected?['name']?.toString() ?? 'Semua Item';
  }

  Future<void> _openItemSearch() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(_itemOptions);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.65,
                minChildSize: 0.35,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari item...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onChanged: (v) {
                          final q = v.trim().toLowerCase();
                          setModalState(() {
                            filtered = q.isEmpty
                                ? List<Map<String, dynamic>>.from(_itemOptions)
                                : _itemOptions.where((e) => (e['name'] ?? '').toString().toLowerCase().contains(q)).toList();
                          });
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Semua Item'),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() => _selectedItemId = null);
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final id = (item['id'] ?? '').toString();
                          return ListTile(
                            title: Text(item['name']?.toString() ?? '-'),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() => _selectedItemId = id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        searchController.dispose();
      } catch (_) {}
    });
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produksi'),
        content: const Text('Data dan stok akan di-rollback. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _service.destroy(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text((res['success'] == true) ? 'Berhasil dihapus' : (res['message']?.toString() ?? 'Gagal hapus')),
        backgroundColor: (res['success'] == true) ? Colors.green : Colors.red,
      ),
    );
    if (res['success'] == true) _load(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'MK Production',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MKProductionCreateScreen()));
          if (r == true) _load(isRefresh: true);
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Column(
        children: [
          _filterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(isRefresh: true),
              child: _items.isEmpty && !_loading
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scrollC,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1))),
                          );
                        }
                        final row = _items[i];
                        return _card(row);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterCard() {
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
              Icon(Icons.filter_alt_rounded, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text(
                'Filter & Pencarian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Cari item, batch, user, catatan...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _openItemSearch,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              ),
              child: Text(
                _selectedItemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fromC,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Dari tanggal',
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () => _pickDate(_fromC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _toC,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Sampai tanggal',
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () => _pickDate(_toC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _searchC.clear();
                    _fromC.clear();
                    _toC.clear();
                    setState(() => _selectedItemId = null);
                    _load(isRefresh: true);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _load(isRefresh: true),
                  child: const Text('Terapkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final id = int.tryParse((row['id'] ?? '').toString()) ?? 0;
    final qty = double.tryParse((row['qty'] ?? '0').toString()) ?? 0;
    final qtyJadi = double.tryParse((row['qty_jadi'] ?? '0').toString()) ?? 0;
    final dateText = _formatDate((row['production_date'] ?? '').toString());
    final createdBy = row['created_by_name']?.toString() ?? '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              _getInitials(createdBy),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['item_name']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _pill(row['batch_number']?.toString().isNotEmpty == true ? row['batch_number'].toString() : '-'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$dateText • $createdBy',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Qty ${_formatQty(qty)} -> ${_formatQty(qtyJadi)} ${row['unit_name'] ?? ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                ),
                const SizedBox(height: 6),
                Text(
                  row['notes']?.toString().isNotEmpty == true ? row['notes'].toString() : '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final r = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MKProductionDetailScreen(id: id)),
                        );
                        if (r == true) _load(isRefresh: true);
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Detail'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                      onPressed: () => _delete(id),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }

  String _formatQty(double value) {
    return NumberFormat('#,##0.##').format(value);
  }

  String _getInitials(String name) {
    final t = name.trim();
    if (t.isEmpty || t == '-') return '?';
    final p = t.split(RegExp(r'\s+'));
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return '${p.first.substring(0, 1)}${p.last.substring(0, 1)}'.toUpperCase();
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Belum ada data MK Production',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
