import 'package:flutter/material.dart';
import '../../services/promo_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'promo_form_screen.dart';

class PromoIndexScreen extends StatefulWidget {
  const PromoIndexScreen({super.key});

  @override
  State<PromoIndexScreen> createState() => _PromoIndexScreenState();
}

class _PromoIndexScreenState extends State<PromoIndexScreen> {
  final PromoService _service = PromoService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 10;
  String _typeFilter = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadList(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _typeText(String type) {
    switch (type) {
      case 'percent':
        return 'Diskon Persen';
      case 'nominal':
        return 'Diskon Nominal';
      case 'bundle':
        return 'Bundling';
      case 'bogo':
        return 'Buy 1 Get 1';
      default:
        return type;
    }
  }

  String _valueText(Map<String, dynamic> row) {
    final type = (row['type'] ?? '').toString();
    final value = row['value'];
    if (value == null) return '-';
    if (type == 'percent') return '$value%';
    return value.toString();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_loading && !_loadingMore && _page < _lastPage) {
        _loadList(refresh: false);
      }
    }
  }

  Future<void> _loadList({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    final targetPage = refresh ? 1 : _page + 1;
    final result = await _service.getList(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      type: _typeFilter.isEmpty ? null : _typeFilter,
      status: _statusFilter.isEmpty ? null : _statusFilter,
      page: targetPage,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Gagal memuat promo'), backgroundColor: Colors.red),
      );
      return;
    }

    final paged = result['promos'] is Map<String, dynamic>
        ? result['promos'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rows = ((paged['data'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      if (refresh) {
        _items
          ..clear()
          ..addAll(rows);
      } else {
        _items.addAll(rows);
      }
      _page = _toInt(paged['current_page'], fallback: targetPage);
      _lastPage = _toInt(paged['last_page'], fallback: 1);
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _openForm({int? id}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PromoFormScreen(promoId: id)),
    );
    if (changed == true) _loadList(refresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> row) async {
    final id = _toInt(row['id']);
    if (id <= 0) return;
    final result = await _service.toggleStatus(id);
    if (!mounted) return;
    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (ok ? 'Berhasil' : 'Gagal')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = _toInt(row['id']);
    if (id <= 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Promo'),
        content: Text('Yakin hapus "${row['name'] ?? '-'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await _service.delete(id);
    if (!mounted) return;
    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (ok ? 'Berhasil' : 'Gagal')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Promo',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFFDB2777),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14)],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadList(refresh: true),
                  decoration: InputDecoration(
                    hintText: 'Cari nama promo...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () => _loadList(refresh: true),
                      icon: const Icon(Icons.search),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _typeFilter.isEmpty ? null : _typeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Tipe',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua')),
                          DropdownMenuItem(value: 'percent', child: Text('Diskon Persen')),
                          DropdownMenuItem(value: 'nominal', child: Text('Diskon Nominal')),
                          DropdownMenuItem(value: 'bundle', child: Text('Bundling')),
                          DropdownMenuItem(value: 'bogo', child: Text('Buy 1 Get 1')),
                        ],
                        onChanged: (v) => setState(() => _typeFilter = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua')),
                          DropdownMenuItem(value: 'active', child: Text('Aktif')),
                          DropdownMenuItem(value: 'inactive', child: Text('Nonaktif')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () => _loadList(refresh: true),
                    child: const Text('Terapkan Filter'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadList(refresh: true),
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Tidak ada data promo')),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              final row = _items[index];
                              final active = (row['status'] ?? '').toString() == 'active';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFFCE7F3),
                                    child: Icon(Icons.local_offer, color: Colors.pink.shade600),
                                  ),
                                  title: Text(
                                    row['name']?.toString() ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text('${_typeText((row['type'] ?? '').toString())} • ${_valueText(row)}'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'toggle') _toggleStatus(row);
                                      if (v == 'edit') _openForm(id: _toInt(row['id']));
                                      if (v == 'delete') _delete(row);
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
                                      ),
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
