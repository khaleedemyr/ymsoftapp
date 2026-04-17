import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class PaymentTypeIndexScreen extends StatefulWidget {
  const PaymentTypeIndexScreen({super.key});

  @override
  State<PaymentTypeIndexScreen> createState() => _PaymentTypeIndexScreenState();
}

class _PaymentTypeIndexScreenState extends State<PaymentTypeIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _regions = [];
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
      title: 'Filter Jenis Pembayaran',
      searchLabel: 'Cari',
      searchHint: 'Nama / kode...',
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

  Future<void> _loadCreateData() async {
    final res = await _service.getPaymentTypeCreateData();
    if (res['success'] == true && mounted) {
      setState(() {
        _outlets = (res['outlets'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _regions = (res['regions'] as List? ?? const [])
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
    final result = await _service.getPaymentTypes(
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
          content: Text(
              result['message']?.toString() ?? 'Gagal memuat payment type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['paymentTypes'] is Map<String, dynamic>
        ? result['paymentTypes'] as Map<String, dynamic>
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

  Future<List<int>?> _pickEntities({
    required String title,
    required List<Map<String, dynamic>> source,
    required List<int> initialIds,
  }) async {
    return showMasterMultiSelectPicker(
      context: context,
      title: title,
      source: source,
      initialIds: initialIds,
      searchHint: 'Cari...',
    );
  }

  String _generateCode(String name) {
    final cleaned = name
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '');
    return cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
  }

  Future<void> _savePaymentType({Map<String, dynamic>? row}) async {
    final nameController =
        TextEditingController(text: row?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: row?['code']?.toString() ?? '');
    final bankNameController =
        TextEditingController(text: row?['bank_name']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: row?['description']?.toString() ?? '');
    bool isBank = row?['is_bank'] == true;
    String status = row?['status']?.toString() ?? 'active';
    String outletType = ((row?['regions'] as List?) ?? const []).isNotEmpty
        ? 'region'
        : 'outlet';
    List<int> outletIds = ((row?['outlets'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .toList();
    List<int> regionIds = ((row?['regions'] as List?) ?? const [])
        .map((e) => _toInt((e as Map)['id']))
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(row == null
              ? 'Tambah Jenis Pembayaran'
              : 'Edit Jenis Pembayaran'),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.92,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Utama',
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
                    onChanged: (_) {
                      if (row == null) {
                        codeController.text =
                            _generateCode(nameController.text);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                        labelText: 'Kode', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pembayaran Bank'),
                    value: isBank,
                    onChanged: (v) => setModalState(() => isBank = v),
                  ),
                  if (isBank) ...[
                    TextField(
                      controller: bankNameController,
                      decoration: const InputDecoration(
                          labelText: 'Nama Bank', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'Cakupan Outlet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: outletType,
                    decoration: const InputDecoration(
                        labelText: 'Outlet Pembayaran',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'region', child: Text('By Region')),
                      DropdownMenuItem(
                          value: 'outlet', child: Text('By Outlet')),
                    ],
                    onChanged: (v) => setModalState(() {
                      outletType = v ?? 'outlet';
                      if (outletType == 'region') {
                        outletIds = [];
                      } else {
                        regionIds = [];
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (outletType == 'region') {
                        final picked = await _pickEntities(
                          title: 'Pilih Region',
                          source: _regions,
                          initialIds: regionIds,
                        );
                        if (picked != null) {
                          setModalState(() => regionIds = picked);
                        }
                      } else {
                        final picked = await _pickEntities(
                          title: 'Pilih Outlet',
                          source: _outlets,
                          initialIds: outletIds,
                        );
                        if (picked != null) {
                          setModalState(() => outletIds = picked);
                        }
                      }
                    },
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(
                      outletType == 'region'
                          ? '${regionIds.length} region dipilih'
                          : '${outletIds.length} outlet dipilih',
                    ),
                  ),
                  if (outletType == 'region' && regionIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: regionIds.take(3).map((id) {
                        final name = _regions.firstWhere(
                          (r) => _toInt(r['id']) == id,
                          orElse: () => {'name': '-'},
                        )['name'];
                        return buildMasterMetaPill(
                          icon: Icons.public_outlined,
                          text: name.toString(),
                        );
                      }).toList()
                        ..addAll(
                          regionIds.length > 3
                              ? [
                                  buildMasterMetaPill(
                                    icon: Icons.more_horiz,
                                    text: '+${regionIds.length - 3} lainnya',
                                  ),
                                ]
                              : [],
                        ),
                    ),
                  ],
                  if (outletType == 'outlet' && outletIds.isNotEmpty) ...[
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
                  const SizedBox(height: 10),
                  const Text(
                    'Informasi Tambahan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Deskripsi', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                        labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
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
      ),
    );
    if (!mounted || saved != true) return;

    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama dan kode wajib diisi'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (outletType == 'region' && regionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih minimal 1 region'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (outletType == 'outlet' && outletIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih minimal 1 outlet'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final response = row == null
        ? await _service.createPaymentType(
            name: nameController.text.trim(),
            code: codeController.text.trim(),
            isBank: isBank,
            bankName: bankNameController.text.trim().isEmpty
                ? null
                : bankNameController.text.trim(),
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            status: status,
            outletType: outletType,
            outletIds: outletIds,
            regionIds: regionIds,
          )
        : await _service.updatePaymentType(
            id: _toInt(row['id']),
            name: nameController.text.trim(),
            code: codeController.text.trim(),
            isBank: isBank,
            bankName: bankNameController.text.trim().isEmpty
                ? null
                : bankNameController.text.trim(),
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            status: status,
            outletType: outletType,
            outletIds: outletIds,
            regionIds: regionIds,
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
        title: const Text('Hapus Jenis Pembayaran'),
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

    final response = await _service.deletePaymentType(_toInt(row['id']));
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
      title: 'Jenis Pembayaran',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.payments_outlined,
            title: 'Master Jenis Pembayaran',
            onAddPressed: () => _savePaymentType(),
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
                    hintText: 'Filter: nama / kode...',
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
                              Center(
                                  child:
                                      Text('Tidak ada data jenis pembayaran')),
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
                              final isBank = row['is_bank'] == true;
                              final outlets =
                                  ((row['outlets'] as List?) ?? const []);
                              final regions =
                                  ((row['regions'] as List?) ?? const []);
                              final byRegion = regions.isNotEmpty;
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
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      buildMasterCardTitle(
                                        row['name']?.toString() ?? '-',
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          buildMasterMetaPill(
                                            icon: isBank
                                                ? Icons.account_balance
                                                : Icons.money_outlined,
                                            text: isBank ? 'Bank' : 'Non-Bank',
                                          ),
                                          buildMasterMetaPill(
                                            icon: byRegion
                                                ? Icons.public_outlined
                                                : Icons.storefront_outlined,
                                            text: byRegion
                                                ? 'By Region (${regions.length})'
                                                : 'By Outlet (${outlets.length})',
                                          ),
                                          if (isBank &&
                                              (row['bank_name'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                            buildMasterMetaPill(
                                              icon: Icons
                                                  .account_balance_wallet_outlined,
                                              text: row['bank_name'].toString(),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () =>
                                            _savePaymentType(row: row),
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
