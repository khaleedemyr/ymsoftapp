import 'package:flutter/material.dart';
import '../../services/modifier_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class ModifierIndexScreen extends StatefulWidget {
  const ModifierIndexScreen({super.key});

  @override
  State<ModifierIndexScreen> createState() => _ModifierIndexScreenState();
}

class _ModifierIndexScreenState extends State<ModifierIndexScreen> {
  final ModifierMasterService _service = ModifierMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 10;

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
    final result = await _service.getModifiers(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
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
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal memuat modifiers'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['modifiers'] is Map<String, dynamic>
        ? result['modifiers'] as Map<String, dynamic>
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

  Future<void> _saveModifier({Map<String, dynamic>? row}) async {
    final nameController = TextEditingController(text: row?['name']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Tambah Modifier' : 'Edit Modifier'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nama Modifier',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (!mounted) return;
    if (saved != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama wajib diisi'), backgroundColor: Colors.red),
      );
      return;
    }

    final response = row == null
        ? await _service.createModifier(name)
        : await _service.updateModifier(_toInt(row['id']), name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? (response['success'] == true ? 'Berhasil disimpan' : 'Gagal disimpan')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Modifier'),
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

    final response = await _service.deleteModifier(_toInt(row['id']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? (response['success'] == true ? 'Berhasil dihapus' : 'Gagal dihapus')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Modifiers',
      showDrawer: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveModifier(),
        backgroundColor: const Color(0xFF2563EB),
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
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadList(refresh: true),
              decoration: InputDecoration(
                hintText: 'Cari modifier...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => _loadList(refresh: true),
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
              ),
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
                              Center(child: Text('Tidak ada data Modifier')),
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
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFDBEAFE),
                                    child: Icon(Icons.tune_rounded, color: Colors.blue.shade700),
                                  ),
                                  title: Text(row['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('ID: ${row['id'] ?? '-'}'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _saveModifier(row: row);
                                      if (v == 'delete') _delete(row);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
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

