import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class ROScheduleIndexScreen extends StatefulWidget {
  const ROScheduleIndexScreen({super.key});

  @override
  State<ROScheduleIndexScreen> createState() => _ROScheduleIndexScreenState();
}

class _ROScheduleIndexScreenState extends State<ROScheduleIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseDivisions = [];
  List<String> _foModes = const ['RO Utama', 'RO Tambahan', 'RO Pengambilan'];
  List<String> _days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool _loading = false;
  bool _loadingMore = false;
  String _foModeFilter = 'all';
  String _dayFilter = 'all';
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 10;

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
    final result = await _service.getRoScheduleCreateData();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _regions = ((result['regions'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _outlets = ((result['outlets'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _warehouseDivisions =
            ((result['warehouseDivisions'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        _foModes = ((result['foModes'] as List?) ?? _foModes).cast<String>();
        _days = ((result['days'] as List?) ?? _days).cast<String>();
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showMasterFilterBottomSheet(
      context: context,
      title: 'Filter RO Schedule',
      searchLabel: 'Cari',
      searchHint: 'Mode / hari / outlet / division...',
      initialSearch: _searchController.text,
      initialShowInactive: false,
      optionTitle: 'Mode RO',
      options: [
        const MasterFilterOption(label: 'Semua Mode', value: 'all'),
        ..._foModes.map((m) => MasterFilterOption(label: m, value: m)),
      ],
      initialOptionValue: _foModeFilter,
    );

    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
      _foModeFilter = result.selectedOption ?? 'all';
    });
    _loadList(refresh: true);
  }

  Color _modeBg(String mode) {
    switch (mode) {
      case 'RO Utama':
        return const Color(0xFFDCFCE7);
      case 'RO Tambahan':
        return const Color(0xFFDBEAFE);
      case 'RO Pengambilan':
        return const Color(0xFFEDE9FE);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _modeFg(String mode) {
    switch (mode) {
      case 'RO Utama':
        return const Color(0xFF166534);
      case 'RO Tambahan':
        return const Color(0xFF1D4ED8);
      case 'RO Pengambilan':
        return const Color(0xFF5B21B6);
      default:
        return const Color(0xFF334155);
    }
  }

  Widget _buildModeBadge(String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _modeBg(mode),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: _modeFg(mode),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEntityChips({
    required List<dynamic> rows,
    required String key,
    required IconData icon,
    int max = 3,
  }) {
    if (rows.isEmpty) return buildMasterMetaPill(icon: icon, text: '-');
    final names = rows
        .map((e) => (e as Map<String, dynamic>)[key]?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return buildMasterMetaPill(icon: icon, text: '-');

    final chips = <Widget>[
      ...names
          .take(max)
          .map((name) => buildMasterMetaPill(icon: icon, text: name)),
    ];
    if (names.length > max) {
      chips.add(buildMasterMetaPill(
          icon: Icons.more_horiz, text: '+${names.length - max}'));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
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
    final result = await _service.getRoSchedules(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      foMode: _foModeFilter == 'all' ? null : _foModeFilter,
      day: _dayFilter == 'all' ? null : _dayFilter,
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
          content:
              Text(result['message']?.toString() ?? 'Gagal memuat RO schedule'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['foSchedules'] is Map<String, dynamic>
        ? result['foSchedules'] as Map<String, dynamic>
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

  String _joinNames({
    required List<int> ids,
    required List<Map<String, dynamic>> source,
    required int Function(Map<String, dynamic> row) getId,
    required String Function(Map<String, dynamic> row) getLabel,
  }) {
    if (ids.isEmpty) return 'Pilih';
    final names = source
        .where((row) => ids.contains(getId(row)))
        .map(getLabel)
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Pilih';
    return names.join(', ');
  }

  bool _isTimeValid(String value) {
    return RegExp(r'^\d{2}:\d{2}$').hasMatch(value);
  }

  Future<void> _saveSchedule({Map<String, dynamic>? row}) async {
    String foMode = row?['fo_mode']?.toString() ?? _foModes.first;
    String day = row?['day']?.toString() ?? _days.first;
    final openController =
        TextEditingController(text: row?['open_time']?.toString() ?? '08:00');
    final closeController =
        TextEditingController(text: row?['close_time']?.toString() ?? '17:00');

    List<int> selectedDivisionIds =
        ((row?['warehouse_divisions'] as List?) ?? const [])
            .map((e) => _toInt((e as Map)['id']))
            .where((e) => e > 0)
            .toList();
    List<int> selectedRegionIds = ((row?['regions'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .where((e) => e > 0)
        .toList();
    List<int> selectedOutletIds = ((row?['outlets'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id_outlet']))
        .where((e) => e > 0)
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title:
                Text(row == null ? 'Tambah RO Schedule' : 'Edit RO Schedule'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: foMode,
                      decoration: const InputDecoration(
                        labelText: 'Mode RO',
                        border: OutlineInputBorder(),
                      ),
                      items: _foModes
                          .map((mode) =>
                              DropdownMenuItem(value: mode, child: Text(mode)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => foMode = v ?? _foModes.first),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: day,
                      decoration: const InputDecoration(
                        labelText: 'Hari',
                        border: OutlineInputBorder(),
                      ),
                      items: _days
                          .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => day = v ?? _days.first),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: openController,
                      decoration: const InputDecoration(
                        labelText: 'Jam Buka (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: closeController,
                      decoration: const InputDecoration(
                        labelText: 'Jam Tutup (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showMasterMultiSelectPicker(
                          context: context,
                          title: 'Pilih Warehouse Division',
                          source: _warehouseDivisions,
                          initialIds: selectedDivisionIds,
                          searchHint: 'Cari division...',
                        );
                        if (picked != null) {
                          setModalState(() => selectedDivisionIds = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Warehouse Division',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _joinNames(
                            ids: selectedDivisionIds,
                            source: _warehouseDivisions,
                            getId: (row) => _toInt(row['id']),
                            getLabel: (row) => row['name']?.toString() ?? '-',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showMasterMultiSelectPicker(
                          context: context,
                          title: 'Pilih Regions',
                          source: _regions,
                          initialIds: selectedRegionIds,
                          searchHint: 'Cari region...',
                        );
                        if (picked != null) {
                          setModalState(() => selectedRegionIds = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Regions',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _joinNames(
                            ids: selectedRegionIds,
                            source: _regions,
                            getId: (row) => _toInt(row['id']),
                            getLabel: (row) => row['name']?.toString() ?? '-',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showMasterMultiSelectPicker(
                          context: context,
                          title: 'Pilih Outlets',
                          source: _outlets,
                          initialIds: selectedOutletIds,
                          idBuilder: (row) => _toInt(row['id_outlet']),
                          labelBuilder: (row) =>
                              row['nama_outlet']?.toString() ?? '-',
                          searchHint: 'Cari outlet...',
                        );
                        if (picked != null) {
                          setModalState(() => selectedOutletIds = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Outlets',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _joinNames(
                            ids: selectedOutletIds,
                            source: _outlets,
                            getId: (row) => _toInt(row['id_outlet']),
                            getLabel: (row) =>
                                row['nama_outlet']?.toString() ?? '-',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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

    final openTime = openController.text.trim();
    final closeTime = closeController.text.trim();
    if (!_isTimeValid(openTime) || !_isTimeValid(closeTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format jam harus HH:mm'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedDivisionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warehouse division wajib dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedRegionIds.isEmpty && selectedOutletIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 region atau 1 outlet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final response = row == null
        ? await _service.createRoSchedule(
            foMode: foMode,
            warehouseDivisionIds: selectedDivisionIds,
            day: day,
            openTime: openTime,
            closeTime: closeTime,
            regionIds: selectedRegionIds,
            outletIds: selectedOutletIds,
          )
        : await _service.updateRoSchedule(
            id: _toInt(row['id']),
            foMode: foMode,
            warehouseDivisionIds: selectedDivisionIds,
            day: day,
            openTime: openTime,
            closeTime: closeTime,
            regionIds: selectedRegionIds,
            outletIds: selectedOutletIds,
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
        title: const Text('Hapus RO Schedule'),
        content: Text(
            'Yakin hapus jadwal "${row['fo_mode'] ?? '-'} - ${row['day'] ?? '-'}"?'),
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

    final response = await _service.deleteRoSchedule(_toInt(row['id']));
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
      title: 'RO Schedule',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.event_note_rounded,
            title: 'RO Schedule',
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
                    hintText: 'Filter: mode / hari / outlet / division...',
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
                    if (_foModeFilter != 'all')
                      buildFilterTag('Mode: $_foModeFilter'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final day = idx == 0 ? 'all' : _days[idx - 1];
                      final selected = _dayFilter == day;
                      return ChoiceChip(
                        label: Text(day == 'all' ? 'Semua Hari' : day),
                        selected: selected,
                        onSelected: (_) {
                          if (_dayFilter == day) return;
                          setState(() => _dayFilter = day);
                          _loadList(refresh: true);
                        },
                        selectedColor: const Color(0xFFDBEAFE),
                        labelStyle: TextStyle(
                          color: selected
                              ? const Color(0xFF1D4ED8)
                              : Colors.grey.shade700,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF93C5FD)
                              : Colors.grey.shade300,
                        ),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  buildFilterTag('Cari: ${_searchController.text.trim()}'),
                ],
                if (_dayFilter != 'all') ...[
                  const SizedBox(height: 6),
                  buildFilterTag('Hari: $_dayFilter'),
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
                              Center(child: Text('Tidak ada data RO Schedule')),
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
                              final divisions =
                                  ((row['warehouse_divisions'] as List?) ??
                                          const [])
                                      .cast<dynamic>();
                              final regions =
                                  ((row['regions'] as List?) ?? const [])
                                      .cast<dynamic>();
                              final outlets =
                                  ((row['outlets'] as List?) ?? const [])
                                      .cast<dynamic>();
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
                                      buildMasterCodeChip(
                                        row['day']?.toString() ?? '-',
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildModeBadge(
                                            row['fo_mode']?.toString() ?? '-',
                                          ),
                                          const SizedBox(width: 8),
                                          buildMasterMetaPill(
                                            icon: Icons.access_time_rounded,
                                            text:
                                                '${row['open_time'] ?? '-'} - ${row['close_time'] ?? '-'}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      buildMasterCardTitle(
                                          'Warehouse Division'),
                                      const SizedBox(height: 4),
                                      _buildEntityChips(
                                        rows: divisions,
                                        key: 'name',
                                        icon: Icons.account_tree_outlined,
                                      ),
                                      const SizedBox(height: 4),
                                      buildMasterCardTitle('Regions'),
                                      const SizedBox(height: 4),
                                      _buildEntityChips(
                                        rows: regions,
                                        key: 'name',
                                        icon: Icons.public_rounded,
                                      ),
                                      const SizedBox(height: 4),
                                      buildMasterCardTitle('Outlets'),
                                      const SizedBox(height: 4),
                                      _buildEntityChips(
                                        rows: outlets,
                                        key: 'nama_outlet',
                                        icon: Icons.store_rounded,
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
