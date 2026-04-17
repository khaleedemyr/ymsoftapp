import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class OfficerCheckIndexScreen extends StatefulWidget {
  const OfficerCheckIndexScreen({super.key});

  @override
  State<OfficerCheckIndexScreen> createState() =>
      _OfficerCheckIndexScreenState();
}

class _OfficerCheckIndexScreenState extends State<OfficerCheckIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _users = [];
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
      title: 'Filter Officer Check',
      searchLabel: 'Cari',
      searchHint: 'Nama user...',
      initialSearch: _searchController.text,
      initialShowInactive: false,
    );
    if (!mounted || result == null) return;
    setState(() {
      _searchController.text = result.search;
    });
    _loadList(refresh: true);
  }

  Future<void> _loadCreateData() async {
    final res = await _service.getOfficerCheckCreateData();
    if (res['success'] == true && mounted) {
      final rows = (res['users'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _users = rows);
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
    final result = await _service.getOfficerChecks(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
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
              result['message']?.toString() ?? 'Gagal memuat officer check'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['officerChecks'] is Map<String, dynamic>
        ? result['officerChecks'] as Map<String, dynamic>
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

  Future<int?> _pickUser(int? initialUserId) async {
    return showMasterSingleSelectPicker(
      context: context,
      title: 'Pilih User',
      source: _users,
      initialId: initialUserId,
      searchHint: 'Cari user...',
    );
  }

  Future<void> _saveOfficerCheck({Map<String, dynamic>? row}) async {
    int? userId = _toInt(row?['user_id']);
    final nilaiController =
        TextEditingController(text: row?['nilai']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title:
              Text(row == null ? 'Tambah Officer Check' : 'Edit Officer Check'),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Officer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickUser(userId);
                      if (picked == null) return;
                      setModalState(() => userId = picked);
                    },
                    icon: const Icon(Icons.person_outline),
                    label: Text(
                      userId == null
                          ? 'Pilih User'
                          : (_users.firstWhere(
                              (u) => _toInt(u['id']) == userId,
                              orElse: () => {'name': '-'},
                            )['name'])
                              .toString(),
                    ),
                  ),
                  if (userId != null) ...[
                    const SizedBox(height: 8),
                    buildMasterMetaPill(
                      icon: Icons.person_outline,
                      text: (_users.firstWhere(
                        (u) => _toInt(u['id']) == userId,
                        orElse: () => {'name': '-'},
                      )['name'])
                          .toString(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Nilai Officer Check',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nilaiController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nilai OC',
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
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (!mounted || saved != true) return;

    if (userId == null || nilaiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('User dan nilai wajib diisi'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final response = row == null
        ? await _service.createOfficerCheck(
            userId: userId!,
            nilai: nilaiController.text.trim(),
          )
        : await _service.updateOfficerCheck(
            id: _toInt(row['id']),
            userId: userId!,
            nilai: nilaiController.text.trim(),
          );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ??
            (response['success'] == true ? 'Berhasil disimpan' : 'Gagal')),
        backgroundColor: response['success'] == true ? null : Colors.red,
      ),
    );
    if (response['success'] == true) _loadList(refresh: true);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Officer Check'),
        content: Text('Yakin hapus "${row['user_name'] ?? '-'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final response = await _service.deleteOfficerCheck(_toInt(row['id']));
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
      title: 'Officer Check',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.fact_check_outlined,
            title: 'Officer Check',
            onAddPressed: () => _saveOfficerCheck(),
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
                    hintText: 'Filter: nama user...',
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
                  ],
                ),
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                                  child: Text('Tidak ada data officer check')),
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
                                      buildMasterCardTitle(
                                        row['user_name']?.toString() ?? '-',
                                      ),
                                      const SizedBox(height: 8),
                                      buildMasterMetaPill(
                                        icon: Icons.numbers_outlined,
                                        text:
                                            'Nilai OC: ${row['nilai'] ?? '-'}',
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () =>
                                            _saveOfficerCheck(row: row),
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
