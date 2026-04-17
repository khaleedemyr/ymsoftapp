import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class InvestorIndexScreen extends StatefulWidget {
  const InvestorIndexScreen({super.key});

  @override
  State<InvestorIndexScreen> createState() => _InvestorIndexScreenState();
}

class _InvestorIndexScreenState extends State<InvestorIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _outlets = [];
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
      title: 'Filter Investor',
      searchLabel: 'Cari',
      searchHint: 'Nama / email / phone...',
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
    final res = await _service.getInvestorCreateData();
    if (res['success'] == true && mounted) {
      final rows = (res['outlets'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _outlets = rows);
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
    final result = await _service.getInvestors(
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
          content:
              Text(result['message']?.toString() ?? 'Gagal memuat investor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['investors'] is Map<String, dynamic>
        ? result['investors'] as Map<String, dynamic>
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

  Future<List<int>?> _pickOutlets({
    required List<int> initialIds,
  }) {
    return showMasterMultiSelectPicker(
      context: context,
      title: 'Pilih Outlet',
      source: _outlets,
      initialIds: initialIds,
      searchHint: 'Cari outlet...',
    );
  }

  Future<void> _saveInvestor({Map<String, dynamic>? row}) async {
    final nameController =
        TextEditingController(text: row?['name']?.toString() ?? '');
    final emailController =
        TextEditingController(text: row?['email']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: row?['phone']?.toString() ?? '');
    List<int> outletIds = ((row?['outlet_ids'] as List?) ?? const [])
        .map((e) => _toInt(e))
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(row == null ? 'Tambah Investor' : 'Edit Investor'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Investor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Nama', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Outlet Dimiliki',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked =
                            await _pickOutlets(initialIds: outletIds);
                        if (picked == null) return;
                        setModalState(() => outletIds = picked);
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text(
                        outletIds.isEmpty
                            ? 'Pilih Outlet'
                            : '${outletIds.length} outlet dipilih',
                      ),
                    ),
                    if (outletIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: outletIds.take(3).map((id) {
                          final name = _outlets.firstWhere(
                            (o) => _toInt(o['id']) == id,
                            orElse: () => {'name': '-'},
                          )['name'];
                          return buildMasterMetaPill(
                            icon: Icons.storefront_outlined,
                            text: name.toString(),
                          );
                        }).toList()
                          ..addAll(
                            outletIds.length > 3
                                ? [
                                    buildMasterMetaPill(
                                      icon: Icons.more_horiz,
                                      text: '+${outletIds.length - 3} lainnya',
                                    ),
                                  ]
                                : [],
                          ),
                      ),
                    ],
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

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama investor wajib diisi'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final response = row == null
        ? await _service.createInvestor(
            name: nameController.text.trim(),
            email: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            phone: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            outletIds: outletIds,
          )
        : await _service.updateInvestor(
            id: _toInt(row['id']),
            name: nameController.text.trim(),
            email: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            phone: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            outletIds: outletIds,
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
        title: const Text('Hapus Investor'),
        content: Text('Yakin hapus "${row['name'] ?? '-'}"?'),
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

    final response = await _service.deleteInvestor(_toInt(row['id']));
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

  String _valueOrDash(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Data Investor Outlet',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.person_pin_circle_outlined,
            title: 'Data Investor Outlet',
            onAddPressed: () => _saveInvestor(),
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
                    hintText: 'Filter: nama / email / phone...',
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
                              Center(child: Text('Tidak ada data investor')),
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
                              final outlets =
                                  ((row['outlets'] as List?) ?? const [])
                                      .map((e) =>
                                          Map<String, dynamic>.from(e as Map))
                                      .toList();
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
                                        row['name']?.toString() ?? '-',
                                      ),
                                      const SizedBox(height: 6),
                                      buildMasterMetaPill(
                                        icon: Icons.email_outlined,
                                        text: _valueOrDash(row['email']),
                                      ),
                                      const SizedBox(height: 6),
                                      buildMasterMetaPill(
                                        icon: Icons.call_outlined,
                                        text: _valueOrDash(row['phone']),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: outlets.isEmpty
                                            ? [
                                                buildMasterMetaPill(
                                                  icon:
                                                      Icons.storefront_outlined,
                                                  text: 'Tidak ada outlet',
                                                ),
                                              ]
                                            : outlets
                                                .take(3)
                                                .map((o) => buildMasterMetaPill(
                                                      icon: Icons
                                                          .storefront_outlined,
                                                      text: o['name']
                                                              ?.toString() ??
                                                          '-',
                                                    ))
                                                .toList()
                                          ..addAll(
                                            outlets.length > 3
                                                ? [
                                                    buildMasterMetaPill(
                                                      icon: Icons.more_horiz,
                                                      text:
                                                          '+${outlets.length - 3} lainnya',
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () => _saveInvestor(row: row),
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
