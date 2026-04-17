import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class ChartOfAccountIndexScreen extends StatefulWidget {
  const ChartOfAccountIndexScreen({super.key});

  @override
  State<ChartOfAccountIndexScreen> createState() =>
      _ChartOfAccountIndexScreenState();
}

class _ChartOfAccountIndexScreenState extends State<ChartOfAccountIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _parents = [];
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

  String _v(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
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
    final res = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter Chart of Account',
      searchLabel: 'Cari',
      searchHint: 'Kode / nama...',
      initialSearch: _searchController.text,
      initialShowInactive: _showInactive,
    );
    if (!mounted || res == null) return;
    setState(() {
      _searchController.text = res.search;
      _showInactive = res.showInactive;
    });
    _loadList(refresh: true);
  }

  Future<void> _loadCreateData() async {
    final res = await _service.getChartOfAccountCreateData();
    if (res['success'] == true && mounted) {
      setState(() {
        _parents = (res['parents'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    }
  }

  Future<void> _loadList({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
      });
      await _loadCreateData();
    } else {
      setState(() => _loadingMore = true);
    }

    final targetPage = refresh ? 1 : _page + 1;
    final res = await _service.getChartOfAccounts(
      search:
          _searchController.text.trim().isEmpty ? null : _searchController.text,
      status: _showInactive ? 'inactive' : 'active',
      page: targetPage,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal memuat CoA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final paged = res['chartOfAccounts'] is Map<String, dynamic>
        ? res['chartOfAccounts'] as Map<String, dynamic>
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

  Future<void> _save({Map<String, dynamic>? row}) async {
    final codeController = TextEditingController(text: _v(row?['code']));
    final nameController = TextEditingController(text: _v(row?['name']));
    final descriptionController =
        TextEditingController(text: _v(row?['description']));
    final budgetController =
        TextEditingController(text: _v(row?['budget_limit']));
    String type = row?['type']?.toString() ?? 'Asset';
    int? parentId =
        row?['parent_id'] == null ? null : _toInt(row?['parent_id']);
    bool isActive = row?['is_active'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(row == null
              ? 'Tambah Chart of Account'
              : 'Edit Chart of Account'),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.92,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Asset', child: Text('Asset')),
                      DropdownMenuItem(
                          value: 'Liability', child: Text('Liability')),
                      DropdownMenuItem(value: 'Equity', child: Text('Equity')),
                      DropdownMenuItem(
                          value: 'Revenue', child: Text('Revenue')),
                      DropdownMenuItem(
                          value: 'Expense', child: Text('Expense')),
                    ],
                    onChanged: (v) => setModalState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: parentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Parent (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Tanpa Parent'),
                      ),
                      ..._parents
                          .where((e) => _toInt(e['id']) != _toInt(row?['id']))
                          .map((e) => DropdownMenuItem<int>(
                                value: _toInt(e['id']),
                                child:
                                    Text('${_v(e['code'])} - ${_v(e['name'])}'),
                              )),
                    ],
                    onChanged: (v) =>
                        setModalState(() => parentId = v == 0 ? null : v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget Limit (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || saved != true) return;
    if (codeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code dan name wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final budget = num.tryParse(budgetController.text.trim());
    final res = row == null
        ? await _service.createChartOfAccount(
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            type: type,
            parentId: parentId,
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            budgetLimit: budget,
            isActive: isActive,
          )
        : await _service.updateChartOfAccount(
            id: _toInt(row['id']),
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            type: type,
            parentId: parentId,
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            budgetLimit: budget,
            isActive: isActive,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ??
            (res['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: res['success'] == true ? null : Colors.red,
      ),
    );
    if (res['success'] == true) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Chart of Account'),
        content: Text('Yakin hapus "${_v(row['name'])}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await _service.deleteChartOfAccount(_toInt(row['id']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ??
            (res['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: res['success'] == true ? null : Colors.red,
      ),
    );
    if (res['success'] == true) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Chart of Account',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.account_balance_outlined,
            title: 'Chart of Account',
            onAddPressed: () => _save(),
            addLabel: 'Tambah',
          ),
          buildMasterFilterCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  readOnly: true,
                  onTap: _openFilterSheet,
                  decoration: const InputDecoration(
                    hintText: 'Filter chart of account...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.filter_list_rounded, size: 18),
                      label: const Text('Filter'),
                    ),
                    if (_showInactive) buildFilterTag('Status: Inactive'),
                    if (_searchController.text.trim().isNotEmpty)
                      buildFilterTag('Cari: ${_searchController.text.trim()}'),
                  ],
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
                              Center(child: Text('Tidak ada data')),
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
                              final parent = row['parent'] is Map
                                  ? Map<String, dynamic>.from(
                                      row['parent'] as Map)
                                  : <String, dynamic>{};
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          buildMasterCodeChip(_v(row['code'])),
                                          const Spacer(),
                                          buildMasterStatusBadge(
                                            isActive: row['is_active'] == true,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      buildMasterCardTitle(_v(row['name'])),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          buildMasterMetaPill(
                                            icon: Icons.category_outlined,
                                            text: _v(row['type']),
                                          ),
                                          if (parent.isNotEmpty)
                                            buildMasterMetaPill(
                                              icon: Icons.account_tree_outlined,
                                              text: _v(parent['name']),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () => _save(row: row),
                                        onDelete: () => _delete(row),
                                        deleteLabel: 'Hapus',
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
