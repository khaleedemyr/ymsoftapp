import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class LockedBudgetFoodCategoryIndexScreen extends StatefulWidget {
  const LockedBudgetFoodCategoryIndexScreen({super.key});

  @override
  State<LockedBudgetFoodCategoryIndexScreen> createState() =>
      _LockedBudgetFoodCategoryIndexScreenState();
}

class _LockedBudgetFoodCategoryIndexScreenState
    extends State<LockedBudgetFoodCategoryIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  int? _categoryFilterId;
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

  String _entityLabel(Map<String, dynamic> entity, List<String> keys) {
    for (final key in keys) {
      final text = entity[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '-' && !RegExp(r'^\d+$').hasMatch(text)) {
        return text;
      }
    }
    final id = _toInt(entity['id'] ?? entity['id_outlet']);
    return id > 0 ? 'ID $id' : '-';
  }

  List<Map<String, dynamic>> _normalizeEntities(
    List rawList, {
    required String idKey,
    required List<String> nameKeys,
  }) {
    String pickName(Map<String, dynamic> map) {
      for (final key in nameKeys) {
        final value = map[key];
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty &&
            text != '-' &&
            !RegExp(r'^\d+$').hasMatch(text)) {
          return text;
        }
      }
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is String) {
          final text = value.trim();
          if (text.isNotEmpty &&
              text != '-' &&
              !RegExp(r'^\d+$').hasMatch(text)) {
            return text;
          }
        }
      }
      return '';
    }

    return rawList.map((e) {
      if (e is Map) {
        final map = Map<String, dynamic>.from(e);
        final id = _toInt(map['id'] ?? map[idKey]);
        final name = pickName(map);
        return {
          ...map,
          'id': id,
          'name': name.isNotEmpty ? name : (id > 0 ? 'ID $id' : '-'),
        };
      }
      final text = e?.toString().trim() ?? '';
      return {
        'id': _toInt(text),
        'name': text.isEmpty ? '-' : text,
      };
    }).toList();
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
        final id = _toInt(outlet['id'] ?? outlet['id_outlet']);
        final name = _entityLabel(
          outlet,
          const [
            'nama_outlet',
            'outlet_name',
            'name',
            'nama',
            'title',
            'label',
            'text',
          ],
        );
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

  Future<void> _openFilterSheet() async {
    final options = <MasterFilterOption>[
      const MasterFilterOption(label: 'Semua Kategori', value: ''),
      ..._categories.map((e) => MasterFilterOption(
            label: _v(e['name']),
            value: _toInt(e['id']).toString(),
          )),
    ];
    final result = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter Locked Budget',
      searchLabel: 'Cari',
      searchHint: 'Kategori / sub kategori / outlet...',
      initialSearch: _searchController.text,
      initialShowInactive: false,
      optionTitle: 'Kategori',
      options: options,
      initialOptionValue: _categoryFilterId?.toString() ?? '',
    );
    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
      _categoryFilterId = (result.selectedOption ?? '').isEmpty
          ? null
          : _toInt(result.selectedOption);
    });
    _loadList(refresh: true);
  }

  Future<void> _loadCreateData() async {
    final res = await _service.getLockedBudgetFoodCategoryCreateData();
    if (res['success'] == true && mounted) {
      final categories = _normalizeEntities(
        (res['categories'] as List? ?? const []),
        idKey: 'id',
        nameKeys: const ['name', 'nama', 'title', 'label', 'text'],
      );
      final subCategories = _normalizeEntities(
        (res['subCategories'] as List? ?? const []),
        idKey: 'id',
        nameKeys: const ['name', 'nama', 'title', 'label', 'text'],
      );
      var outlets = _normalizeEntities(
        (res['outlets'] as List? ?? const []),
        idKey: 'id_outlet',
        nameKeys: const [
          'name',
          'nama_outlet',
          'outlet_name',
          'nama',
          'title',
          'label',
          'text',
        ],
      );

      final hasRealOutletName = outlets.any((e) {
        final name = _v(e['name']);
        return name != '-' && !name.startsWith('ID ');
      });

      if (!hasRealOutletName) {
        final nameById = await _loadMasterOutletNameById();
        if (nameById.isNotEmpty) {
          outlets = outlets.map((outlet) {
            final id = _toInt(outlet['id']);
            final patchedName = nameById[id];
            if (patchedName != null) {
              return {
                ...outlet,
                'name': patchedName,
              };
            }
            return outlet;
          }).toList();
        }
      }

      setState(() {
        _categories = categories;
        _subCategories = subCategories;
        _outlets = outlets;
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
    final res = await _service.getLockedBudgetFoodCategories(
      search:
          _searchController.text.trim().isEmpty ? null : _searchController.text,
      categoryId: _categoryFilterId,
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
          content:
              Text(res['message']?.toString() ?? 'Gagal memuat locked budget'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = res['lockedBudgetFoodCategories'] is Map<String, dynamic>
        ? res['lockedBudgetFoodCategories'] as Map<String, dynamic>
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
    int? categoryId =
        row?['category_id'] == null ? null : _toInt(row?['category_id']);
    int? subCategoryId = row?['sub_category_id'] == null
        ? null
        : _toInt(row?['sub_category_id']);
    int? outletId =
        row?['outlet_id'] == null ? null : _toInt(row?['outlet_id']);
    final budgetController = TextEditingController(
      text: row?['budget']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredSubCategories = _subCategories
              .where((e) => _toInt(e['category_id']) == categoryId)
              .toList();
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(
                row == null ? 'Tambah Locked Budget' : 'Edit Locked Budget'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _categories
                          .map((e) => DropdownMenuItem<int>(
                                value: _toInt(e['id']),
                                child: Text(_entityLabel(
                                  e,
                                  const [
                                    'name',
                                    'nama',
                                    'title',
                                    'label',
                                    'text'
                                  ],
                                )),
                              ))
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        categoryId = v;
                        subCategoryId = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: filteredSubCategories
                              .any((e) => _toInt(e['id']) == subCategoryId)
                          ? subCategoryId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Sub Kategori',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: filteredSubCategories
                          .map((e) => DropdownMenuItem<int>(
                                value: _toInt(e['id']),
                                child: Text(_entityLabel(
                                  e,
                                  const [
                                    'name',
                                    'nama',
                                    'title',
                                    'label',
                                    'text'
                                  ],
                                )),
                              ))
                          .toList(),
                      onChanged: (v) => setModalState(() => subCategoryId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: outletId,
                      decoration: const InputDecoration(
                        labelText: 'Outlet',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _outlets
                          .map((e) => DropdownMenuItem<int>(
                                value: _toInt(e['id']),
                                child: Text(_entityLabel(
                                  e,
                                  const [
                                    'name',
                                    'nama_outlet',
                                    'outlet_name',
                                    'nama',
                                    'title',
                                    'label',
                                    'text',
                                  ],
                                )),
                              ))
                          .toList(),
                      onChanged: (v) => setModalState(() => outletId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget',
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
          );
        },
      ),
    );
    if (!mounted || saved != true) return;

    final budget = num.tryParse(budgetController.text.trim());
    if (categoryId == null ||
        subCategoryId == null ||
        outletId == null ||
        budget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua field wajib diisi dengan benar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final res = row == null
        ? await _service.createLockedBudgetFoodCategory(
            categoryId: categoryId!,
            subCategoryId: subCategoryId!,
            outletId: outletId!,
            budget: budget,
          )
        : await _service.updateLockedBudgetFoodCategory(
            id: _toInt(row['id']),
            categoryId: categoryId!,
            subCategoryId: subCategoryId!,
            outletId: outletId!,
            budget: budget,
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
        title: const Text('Hapus Data'),
        content: const Text('Yakin hapus data locked budget ini?'),
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
        await _service.deleteLockedBudgetFoodCategory(_toInt(row['id']));
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
      title: 'Locked Budget Food Categories',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.lock_outline,
            title: 'Locked Budget Food Categories',
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
                    hintText: 'Filter data...',
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
                              final category = row['category'] is Map
                                  ? Map<String, dynamic>.from(
                                      row['category'] as Map)
                                  : <String, dynamic>{};
                              final subCategory = row['sub_category'] is Map
                                  ? Map<String, dynamic>.from(
                                      row['sub_category'] as Map)
                                  : <String, dynamic>{};
                              final outlet = row['outlet'] is Map
                                  ? Map<String, dynamic>.from(
                                      row['outlet'] as Map)
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
                                      buildMasterCardTitle(
                                          _v(category['name'])),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          buildMasterMetaPill(
                                            icon: Icons.label_outline,
                                            text: _v(subCategory['name']),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.storefront_outlined,
                                            text: _entityLabel(
                                              outlet,
                                              const [
                                                'nama_outlet',
                                                'outlet_name',
                                                'name',
                                                'nama',
                                                'title',
                                                'label',
                                                'text',
                                              ],
                                            ),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.payments_outlined,
                                            text:
                                                'Budget: ${_v(row['budget'])}',
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
