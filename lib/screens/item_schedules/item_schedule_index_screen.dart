import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class ItemScheduleIndexScreen extends StatefulWidget {
  const ItemScheduleIndexScreen({super.key});

  @override
  State<ItemScheduleIndexScreen> createState() =>
      _ItemScheduleIndexScreenState();
}

class _ItemScheduleIndexScreenState extends State<ItemScheduleIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _itemOptions = [];
  bool _loading = false;
  bool _loadingMore = false;
  String _dayFilter = 'all';
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 10;

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCreateData();
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

  Future<void> _loadCreateData() async {
    final result = await _service.getItemScheduleCreateData();
    if (!mounted) return;
    if (result['success'] == true) {
      final rows = ((result['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _itemOptions
        ..clear()
        ..addAll(rows));
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter Item Schedule',
      searchLabel: 'Cari',
      searchHint: 'Item / hari / catatan...',
      initialSearch: _searchController.text,
      initialShowInactive: false,
      optionTitle: 'Hari Kedatangan',
      options: const [
        MasterFilterOption(label: 'Semua Hari', value: 'all'),
        MasterFilterOption(label: 'Monday', value: 'Monday'),
        MasterFilterOption(label: 'Tuesday', value: 'Tuesday'),
        MasterFilterOption(label: 'Wednesday', value: 'Wednesday'),
        MasterFilterOption(label: 'Thursday', value: 'Thursday'),
        MasterFilterOption(label: 'Friday', value: 'Friday'),
        MasterFilterOption(label: 'Saturday', value: 'Saturday'),
        MasterFilterOption(label: 'Sunday', value: 'Sunday'),
      ],
      initialOptionValue: _dayFilter,
    );

    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
      _dayFilter = result.selectedOption ?? 'all';
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
    final result = await _service.getItemSchedules(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      arrivalDay: _dayFilter == 'all' ? null : _dayFilter,
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
          content: Text(
              result['message']?.toString() ?? 'Gagal memuat item schedule'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['itemSchedules'] is Map<String, dynamic>
        ? result['itemSchedules'] as Map<String, dynamic>
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

  Future<void> _saveSchedule({Map<String, dynamic>? row}) async {
    final notesController =
        TextEditingController(text: row?['notes']?.toString() ?? '');
    int? itemId = _toInt(row?['item_id'], fallback: 0);
    if (itemId == 0) itemId = null;
    String arrivalDay = row?['arrival_day']?.toString() ?? _days.first;

    String selectedItemName() {
      if (itemId == null) return 'Pilih Item';
      final match =
          _itemOptions.where((o) => _toInt(o['id']) == itemId).toList();
      if (match.isEmpty) return 'Pilih Item';
      return match.first['name']?.toString() ?? 'Pilih Item';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(
                row == null ? 'Tambah Item Schedule' : 'Edit Item Schedule'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.86,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showMasterSingleSelectPicker(
                          context: context,
                          title: 'Pilih Item',
                          source: _itemOptions,
                          initialId: itemId,
                          searchHint: 'Cari item...',
                        );
                        if (picked != null) {
                          setModalState(() => itemId = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Item',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedItemName(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.search_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: arrivalDay,
                      decoration: const InputDecoration(
                        labelText: 'Hari Kedatangan',
                        border: OutlineInputBorder(),
                      ),
                      items: _days
                          .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => arrivalDay = v ?? _days.first),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
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
        );
      },
    );
    if (!mounted || saved != true) return;

    if (itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item wajib dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final response = row == null
        ? await _service.createItemSchedule(
            itemId: itemId!,
            arrivalDay: arrivalDay,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          )
        : await _service.updateItemSchedule(
            id: _toInt(row['id']),
            itemId: itemId!,
            arrivalDay: arrivalDay,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
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

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Item Schedule'),
        content: Text('Yakin hapus jadwal "${row['item']?['name'] ?? '-'}"?'),
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

    final response = await _service.deleteItemSchedule(_toInt(row['id']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true
                ? 'Berhasil dihapus'
                : 'Gagal dihapus')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Item Schedule',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.calendar_month_rounded,
            title: 'Item Schedule',
            onAddPressed: () => _saveSchedule(),
          ),
          buildMasterFilterCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  readOnly: true,
                  onTap: _openFilterSheet,
                  decoration: const InputDecoration(
                    hintText: 'Filter: item / hari / catatan...',
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
                    if (_dayFilter != 'all')
                      buildFilterTag('Hari: $_dayFilter'),
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
                              Center(
                                  child: Text('Tidak ada data Item Schedule')),
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
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              final row = _items[index];
                              final noteText =
                                  row['notes']?.toString().trim() ?? '';
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
                                          buildMasterCodeChip(
                                            row['arrival_day']?.toString() ??
                                                '-',
                                          ),
                                          const SizedBox(width: 8),
                                          buildMasterMetaPill(
                                            icon: Icons.inventory_2_outlined,
                                            text:
                                                'Item ID: ${row['item_id']?.toString() ?? '-'}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      buildMasterCardTitle(
                                        row['item']?['name']?.toString() ?? '-',
                                      ),
                                      const SizedBox(height: 6),
                                      if (noteText.isNotEmpty)
                                        buildMasterMetaText(
                                            'Catatan: $noteText')
                                      else
                                        buildMasterMetaPill(
                                          icon: Icons.notes_rounded,
                                          text: 'Tanpa catatan',
                                        ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () => _saveSchedule(row: row),
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
