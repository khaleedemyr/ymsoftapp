import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class BudgetManagementIndexScreen extends StatefulWidget {
  const BudgetManagementIndexScreen({super.key});

  @override
  State<BudgetManagementIndexScreen> createState() =>
      _BudgetManagementIndexScreenState();
}

class _BudgetManagementIndexScreenState
    extends State<BudgetManagementIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _outlets = [];
  List<String> _divisionOptions = [];
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  String? _divisionFilter;
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

  int _outletId(Map<String, dynamic> outlet) {
    return _toInt(outlet['id'] ?? outlet['id_outlet']);
  }

  String _outletLabel(Map<String, dynamic> outlet) {
    final keys = const [
      'nama_outlet',
      'outlet_name',
      'name',
      'nama',
      'title',
      'label',
      'text',
    ];
    for (final key in keys) {
      final text = outlet[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '-' && !RegExp(r'^\d+$').hasMatch(text)) {
        return text;
      }
    }
    final id = _outletId(outlet);
    return id > 0 ? 'ID $id' : '-';
  }

  List<Map<String, dynamic>> _normalizeOutlets(List rawOutlets) {
    return rawOutlets.map((e) {
      if (e is! Map) {
        final text = e?.toString().trim() ?? '';
        final id = _toInt(text);
        return {
          'id': id,
          'name': text.isEmpty ? (id > 0 ? 'ID $id' : '-') : text,
        };
      }
      final map = Map<String, dynamic>.from(e);
      final id = _outletId(map);
      return {
        ...map,
        'id': id,
        'name': _outletLabel(map),
      };
    }).where((row) => _outletId(row) > 0).toList();
  }

  Future<Map<int, String>> _loadMasterOutletNameById() async {
    final nameById = <int, String>{};
    var page = 1;
    var lastPage = 1;

    do {
      final result = await _service.getMasterOutlets(page: page, perPage: 200);
      if (result['success'] != true) break;

      final paged = result['outlets'] is Map<String, dynamic>
          ? result['outlets'] as Map<String, dynamic>
          : <String, dynamic>{};
      final rows = ((paged['data'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      for (final outlet in rows) {
        final id = _outletId(outlet);
        final name = _outletLabel(outlet);
        if (id > 0 && name != '-' && !name.startsWith('ID ')) {
          nameById[id] = name;
        }
      }

      final parsedCurrent = _toInt(paged['current_page'], fallback: page);
      final parsedLast = _toInt(paged['last_page'], fallback: page);
      page = parsedCurrent + 1;
      lastPage = parsedLast <= 0 ? parsedCurrent : parsedLast;
    } while (page <= lastPage);

    return nameById;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (!_loading && !_loadingMore && _page < _lastPage) {
        _loadList(refresh: false);
      }
    }
  }

  Future<void> _loadCreateData() async {
    final res = await _service.getBudgetManagementCreateData();
    if (res['success'] == true && mounted) {
      var outlets = _normalizeOutlets(res['outlets'] as List? ?? const []);
      final hasRealOutletName = outlets.any((o) {
        final name = _outletLabel(o);
        return name != '-' && !name.startsWith('ID ');
      });

      if (!hasRealOutletName && outlets.isNotEmpty) {
        final nameById = await _loadMasterOutletNameById();
        if (nameById.isNotEmpty) {
          outlets = outlets.map((outlet) {
            final id = _outletId(outlet);
            final mapped = nameById[id];
            if (mapped == null) return outlet;
            return {
              ...outlet,
              'name': mapped,
              'nama_outlet': mapped,
            };
          }).toList();
        }
      }

      setState(() {
        _outlets = outlets;
        _divisionOptions = (res['divisionOptions'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final options = <MasterFilterOption>[
      const MasterFilterOption(label: 'Semua Divisi', value: ''),
      ..._divisionOptions.map((e) => MasterFilterOption(label: e, value: e)),
    ];
    final result = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter Budget Management',
      searchLabel: 'Cari',
      searchHint: 'Nama kategori / subkategori...',
      initialSearch: _searchController.text,
      initialShowInactive: false,
      optionTitle: 'Divisi',
      options: options,
      initialOptionValue: _divisionFilter ?? '',
    );
    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
      _divisionFilter =
          (result.selectedOption ?? '').isEmpty ? null : result.selectedOption;
    });
    _loadList(refresh: true);
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
    final res = await _service.getBudgetManagementCategories(
      search:
          _searchController.text.trim().isEmpty ? null : _searchController.text,
      division: _divisionFilter,
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
          content: Text(res['message']?.toString() ?? 'Gagal memuat data'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = res['budgetCategories'] is Map<String, dynamic>
        ? res['budgetCategories'] as Map<String, dynamic>
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
    final nameController = TextEditingController(text: _v(row?['name']));
    final subcategoryController =
        TextEditingController(text: _v(row?['subcategory']));
    final budgetController =
        TextEditingController(text: _v(row?['budget_limit']));
    final descriptionController =
        TextEditingController(text: _v(row?['description']));
    String division = row?['division']?.toString() ??
        (_divisionOptions.isNotEmpty ? _divisionOptions.first : 'GENERAL');
    String budgetType = row?['budget_type']?.toString() ?? 'GLOBAL';
    List<int> selectedOutlets = ((row?['outlet_budgets'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['outlet_id']))
        .toList();
    final existingOutletBudgets = <int, String>{};
    for (final entry in ((row?['outlet_budgets'] as List?) ?? const [])) {
      final map =
          entry is Map ? Map<String, dynamic>.from(entry) : <String, dynamic>{};
      final id = _toInt(map['outlet_id']);
      if (id > 0) {
        existingOutletBudgets[id] = (map['allocated_budget'] ?? '').toString();
      }
    }
    final outletBudgetControllers = <int, TextEditingController>{};
    void disposeOutletBudgetControllers() {
      for (final controller in outletBudgetControllers.values) {
        controller.dispose();
      }
    }

    void syncOutletBudgetControllers() {
      final currentSet = selectedOutlets.toSet();
      final existingKeys = outletBudgetControllers.keys.toList();
      for (final id in existingKeys) {
        if (!currentSet.contains(id)) {
          outletBudgetControllers[id]?.dispose();
          outletBudgetControllers.remove(id);
        }
      }
      for (final id in selectedOutlets) {
        outletBudgetControllers.putIfAbsent(
          id,
          () => TextEditingController(
            text: existingOutletBudgets[id] ?? budgetController.text.trim(),
          ),
        );
      }
    }

    syncOutletBudgetControllers();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(
              row == null ? 'Tambah Budget Category' : 'Edit Budget Category'),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.92,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: division,
                    decoration: const InputDecoration(
                      labelText: 'Divisi',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: _divisionOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => division = v ?? division),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subcategoryController,
                    decoration: const InputDecoration(
                      labelText: 'Sub Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget Limit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: budgetType,
                    decoration: const InputDecoration(
                      labelText: 'Budget Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GLOBAL', child: Text('GLOBAL')),
                      DropdownMenuItem(
                        value: 'PER_OUTLET',
                        child: Text('PER_OUTLET'),
                      ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => budgetType = v ?? 'GLOBAL'),
                  ),
                  if (budgetType == 'PER_OUTLET') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showMasterMultiSelectPicker(
                          context: context,
                          title: 'Pilih Outlet',
                          source: _outlets,
                          initialIds: selectedOutlets,
                          idBuilder: _outletId,
                          labelBuilder: _outletLabel,
                          searchHint: 'Cari outlet...',
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedOutlets = picked;
                            syncOutletBudgetControllers();
                          });
                        }
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text('${selectedOutlets.length} outlet dipilih'),
                    ),
                    if (selectedOutlets.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Budget Per Outlet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...selectedOutlets.map((outletId) {
                              final outlet = _outlets.firstWhere(
                                (o) => _outletId(o) == outletId,
                                orElse: () => {'name': '-'},
                              );
                              final controller =
                                  outletBudgetControllers[outletId] ??
                                      TextEditingController();
                              outletBudgetControllers[outletId] = controller;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: _outletLabel(outlet),
                                    hintText: 'Nominal budget',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(),
                    ),
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
    if (!mounted || saved != true) {
      disposeOutletBudgetControllers();
      return;
    }

    final budgetLimit = num.tryParse(budgetController.text.trim());
    if (nameController.text.trim().isEmpty ||
        subcategoryController.text.trim().isEmpty ||
        budgetLimit == null ||
        (budgetType == 'PER_OUTLET' && selectedOutlets.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi data wajib terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      disposeOutletBudgetControllers();
      return;
    }

    final outletBudgets = <String, dynamic>{};
    if (budgetType == 'PER_OUTLET') {
      for (final id in selectedOutlets) {
        final value = num.tryParse(
          outletBudgetControllers[id]?.text.trim() ?? '',
        );
        if (value == null || value < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Budget outlet "${_outletLabel(_outlets.firstWhere((o) => _outletId(o) == id, orElse: () => {
                      'name': '-'
                    }))}" tidak valid',
              ),
              backgroundColor: Colors.red,
            ),
          );
          disposeOutletBudgetControllers();
          return;
        }
        outletBudgets[id.toString()] = value;
      }
    }

    final payloadOutletIds =
        budgetType == 'PER_OUTLET' ? selectedOutlets : <int>[];
    final payloadOutletBudgets =
        budgetType == 'PER_OUTLET' ? outletBudgets : <String, dynamic>{};

    final res = row == null
        ? await _service.createBudgetManagementCategory(
            name: nameController.text.trim(),
            division: division,
            subcategory: subcategoryController.text.trim(),
            budgetLimit: budgetLimit,
            budgetType: budgetType,
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            selectedOutletIds: payloadOutletIds,
            outletBudgets: payloadOutletBudgets,
          )
        : await _service.updateBudgetManagementCategory(
            id: _toInt(row['id']),
            name: nameController.text.trim(),
            division: division,
            subcategory: subcategoryController.text.trim(),
            budgetLimit: budgetLimit,
            budgetType: budgetType,
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            selectedOutletIds: payloadOutletIds,
            outletBudgets: payloadOutletBudgets,
          );
    disposeOutletBudgetControllers();
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
        title: const Text('Hapus Kategori Budget'),
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
    final res =
        await _service.deleteBudgetManagementCategory(_toInt(row['id']));
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
      title: 'Budget Management',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Budget Management',
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
                    hintText: 'Filter budget...',
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
                    if (_divisionFilter != null)
                      buildFilterTag('Divisi: $_divisionFilter'),
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
                              final outletBudgets =
                                  ((row['outlet_budgets'] as List?) ??
                                      const []);
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
                                      buildMasterCardTitle(_v(row['name'])),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          buildMasterMetaPill(
                                            icon: Icons.account_tree_outlined,
                                            text: _v(row['division']),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.label_outline,
                                            text: _v(row['subcategory']),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.style_outlined,
                                            text: _v(row['budget_type']),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.storefront_outlined,
                                            text:
                                                'Outlet: ${outletBudgets.length}',
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
