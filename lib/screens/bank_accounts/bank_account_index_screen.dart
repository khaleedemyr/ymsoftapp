import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class BankAccountIndexScreen extends StatefulWidget {
  const BankAccountIndexScreen({super.key});

  @override
  State<BankAccountIndexScreen> createState() => _BankAccountIndexScreenState();
}

class _BankAccountIndexScreenState extends State<BankAccountIndexScreen> {
  final WarehouseMasterService _service = WarehouseMasterService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _coas = [];
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
      title: 'Filter Bank Account',
      searchLabel: 'Cari',
      searchHint: 'Nama bank / nomor rekening...',
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
    final res = await _service.getBankAccountCreateData();
    if (res['success'] == true && mounted) {
      setState(() {
        _outlets = (res['outlets'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _coas = (res['chartOfAccounts'] as List? ?? const [])
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
    final res = await _service.getBankAccounts(
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
          content:
              Text(res['message']?.toString() ?? 'Gagal memuat bank account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final paged = res['bankAccounts'] is Map<String, dynamic>
        ? res['bankAccounts'] as Map<String, dynamic>
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
    final bankNameController =
        TextEditingController(text: _v(row?['bank_name']));
    final accountNumberController =
        TextEditingController(text: _v(row?['account_number']));
    final accountNameController =
        TextEditingController(text: _v(row?['account_name']));
    int? outletId =
        row?['outlet_id'] == null ? null : _toInt(row?['outlet_id']);
    int? coaId = row?['coa_id'] == null ? null : _toInt(row?['coa_id']);
    bool isActive = row?['is_active'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title:
              Text(row == null ? 'Tambah Bank Account' : 'Edit Bank Account'),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.92,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: outletId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Outlet (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Head Office'),
                      ),
                      ..._outlets.map((e) => DropdownMenuItem<int>(
                            value: _toInt(e['id']),
                            child: Text(_v(e['name'])),
                          )),
                    ],
                    onChanged: (v) =>
                        setModalState(() => outletId = v == 0 ? null : v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: coaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chart of Account (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Tanpa CoA'),
                      ),
                      ..._coas.map((e) => DropdownMenuItem<int>(
                            value: _toInt(e['id']),
                            child: Text('${_v(e['code'])} - ${_v(e['name'])}'),
                          )),
                    ],
                    onChanged: (v) =>
                        setModalState(() => coaId = v == 0 ? null : v),
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
    if (bankNameController.text.trim().isEmpty ||
        accountNumberController.text.trim().isEmpty ||
        accountNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank name, account number, account name wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final res = row == null
        ? await _service.createBankAccount(
            bankName: bankNameController.text.trim(),
            accountNumber: accountNumberController.text.trim(),
            accountName: accountNameController.text.trim(),
            outletId: outletId,
            coaId: coaId,
            isActive: isActive,
          )
        : await _service.updateBankAccount(
            id: _toInt(row['id']),
            bankName: bankNameController.text.trim(),
            accountNumber: accountNumberController.text.trim(),
            accountName: accountNameController.text.trim(),
            outletId: outletId,
            coaId: coaId,
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
        title: const Text('Hapus Bank Account'),
        content: Text('Yakin hapus "${_v(row['bank_name'])}"?'),
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
    final res = await _service.deleteBankAccount(_toInt(row['id']));
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
      title: 'Master Data Bank',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.account_balance_outlined,
            title: 'Master Data Bank',
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
                    hintText: 'Filter bank account...',
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
                              final outlet = row['outlet'] is Map
                                  ? Map<String, dynamic>.from(
                                      row['outlet'] as Map)
                                  : <String, dynamic>{};
                              final coa = row['coa'] is Map
                                  ? Map<String, dynamic>.from(row['coa'] as Map)
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
                                          buildMasterCardTitle(
                                              _v(row['bank_name'])),
                                          const Spacer(),
                                          buildMasterStatusBadge(
                                            isActive: row['is_active'] == true,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          buildMasterMetaPill(
                                            icon: Icons.numbers_outlined,
                                            text: _v(row['account_number']),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.person_outline,
                                            text: _v(row['account_name']),
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.storefront_outlined,
                                            text: outlet.isEmpty
                                                ? 'Head Office'
                                                : _v(outlet['nama_outlet']),
                                          ),
                                          if (coa.isNotEmpty)
                                            buildMasterMetaPill(
                                              icon: Icons.account_tree_outlined,
                                              text:
                                                  '${_v(coa['code'])} - ${_v(coa['name'])}',
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
