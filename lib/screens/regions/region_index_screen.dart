import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class RegionIndexScreen extends StatefulWidget {
  const RegionIndexScreen({super.key});

  @override
  State<RegionIndexScreen> createState() => _RegionIndexScreenState();
}

class _RegionIndexScreenState extends State<RegionIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _showInactive = false;
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (!_loading && !_loadingMore && _page < _lastPage) {
        _loadList(refresh: false);
      }
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter Regions',
      searchLabel: 'Cari',
      searchHint: 'Kode / nama region...',
      initialSearch: _searchController.text,
      initialShowInactive: _showInactive,
    );

    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
      _showInactive = result.showInactive;
    });
    _loadList(refresh: true);
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
    final result = await _service.getRegions(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      status: _showInactive ? 'inactive' : 'active',
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
          content: Text(result['message']?.toString() ?? 'Gagal memuat region'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['regions'] is Map<String, dynamic>
        ? result['regions'] as Map<String, dynamic>
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

  Future<void> _saveRegion({Map<String, dynamic>? row}) async {
    final codeController =
        TextEditingController(text: row?['code']?.toString() ?? '');
    final nameController =
        TextEditingController(text: row?['name']?.toString() ?? '');
    String status = row?['status']?.toString() ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(row == null ? 'Tambah Region' : 'Edit Region'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.86,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                          labelText: 'Kode', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Nama Region',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                          labelText: 'Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) =>
                          setModalState(() => status = v ?? 'active'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Simpan')),
            ],
          ),
        );
      },
    );
    if (!mounted || saved != true) return;

    if (codeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kode dan nama wajib diisi'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final response = row == null
        ? await _service.createRegion(
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            status: status,
          )
        : await _service.updateRegion(
            id: _toInt(row['id']),
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            status: status,
          );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true
                ? 'Berhasil disimpan'
                : 'Gagal disimpan')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _toggleStatus(Map<String, dynamic> row) async {
    final current = row['status']?.toString() ?? 'active';
    final next = current == 'active' ? 'inactive' : 'active';
    final response =
        await _service.toggleRegionStatus(id: _toInt(row['id']), status: next);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true
                ? 'Status diubah'
                : 'Gagal ubah status')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Region'),
        content: Text('Yakin nonaktifkan "${row['name'] ?? '-'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final response = await _service.deleteRegion(_toInt(row['id']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Regions',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.public_rounded,
            title: 'Master Data Region',
            onAddPressed: () => _saveRegion(),
          ),
          buildMasterFilterCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  readOnly: true,
                  onTap: _openFilterSheet,
                  decoration: const InputDecoration(
                    hintText: 'Filter: kode / nama region...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.filter_list_rounded, size: 18),
                      label: const Text('Filter'),
                    ),
                    const SizedBox(width: 8),
                    if (_showInactive) buildFilterTag('Status: Inactive'),
                  ],
                ),
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  buildFilterTag('Cari: ${_searchController.text.trim()}'),
                ],
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
                              Center(child: Text('Tidak ada data Region')),
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
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                );
                              }
                              final row = _items[index];
                              final status =
                                  row['status']?.toString() ?? 'inactive';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          buildMasterCodeChip(
                                            row['code']?.toString() ?? '-',
                                          ),
                                          const Spacer(),
                                          buildMasterStatusBadge(
                                            isActive: status == 'active',
                                            onTap: () => _toggleStatus(row),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        row['name']?.toString() ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () => _saveRegion(row: row),
                                        onDelete: () => _delete(row),
                                      ),
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
