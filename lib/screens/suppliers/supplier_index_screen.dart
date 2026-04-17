import 'package:flutter/material.dart';
import '../../services/warehouse_master_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_data_ui.dart';
import '../../widgets/master_filter_bottom_sheet.dart';

class SupplierIndexScreen extends StatefulWidget {
  const SupplierIndexScreen({super.key});

  @override
  State<SupplierIndexScreen> createState() => _SupplierIndexScreenState();
}

class _SupplierIndexScreenState extends State<SupplierIndexScreen> {
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
      title: 'Filter Suppliers',
      searchLabel: 'Cari',
      searchHint: 'Kode / nama / CP / phone / email...',
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
    final result = await _service.getSuppliers(
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
          content:
              Text(result['message']?.toString() ?? 'Gagal memuat supplier'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paged = result['suppliers'] is Map<String, dynamic>
        ? result['suppliers'] as Map<String, dynamic>
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

  Future<void> _saveSupplier({Map<String, dynamic>? row}) async {
    final codeController =
        TextEditingController(text: row?['code']?.toString() ?? '');
    final nameController =
        TextEditingController(text: row?['name']?.toString() ?? '');
    final contactController =
        TextEditingController(text: row?['contact_person']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: row?['phone']?.toString() ?? '');
    final emailController =
        TextEditingController(text: row?['email']?.toString() ?? '');
    final addressController =
        TextEditingController(text: row?['address']?.toString() ?? '');
    final cityController =
        TextEditingController(text: row?['city']?.toString() ?? '');
    final provinceController =
        TextEditingController(text: row?['province']?.toString() ?? '');
    final postalController =
        TextEditingController(text: row?['postal_code']?.toString() ?? '');
    final npwpController =
        TextEditingController(text: row?['npwp']?.toString() ?? '');
    final bankNameController =
        TextEditingController(text: row?['bank_name']?.toString() ?? '');
    final bankAccNoController = TextEditingController(
        text: row?['bank_account_number']?.toString() ?? '');
    final bankAccNameController = TextEditingController(
        text: row?['bank_account_name']?.toString() ?? '');
    final paymentTermController =
        TextEditingController(text: row?['payment_term']?.toString() ?? '');
    final paymentDaysController =
        TextEditingController(text: row?['payment_days']?.toString() ?? '');
    String status = row?['status']?.toString() ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(row == null ? 'Tambah Supplier' : 'Edit Supplier'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                            labelText: 'Kode', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: 'Nama', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: contactController,
                        decoration: const InputDecoration(
                            labelText: 'Contact Person',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                            labelText: 'Phone', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                            labelText: 'Email', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Alamat', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: cityController,
                        decoration: const InputDecoration(
                            labelText: 'Kota', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: provinceController,
                        decoration: const InputDecoration(
                            labelText: 'Provinsi',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: postalController,
                        decoration: const InputDecoration(
                            labelText: 'Kode Pos',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: npwpController,
                        decoration: const InputDecoration(
                            labelText: 'NPWP', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: bankNameController,
                        decoration: const InputDecoration(
                            labelText: 'Bank', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: bankAccNoController,
                        decoration: const InputDecoration(
                            labelText: 'No. Rekening',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: bankAccNameController,
                        decoration: const InputDecoration(
                            labelText: 'Nama Rekening',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                        controller: paymentTermController,
                        decoration: const InputDecoration(
                            labelText: 'Term Pembayaran',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                      controller: paymentDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Hari Pembayaran',
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
        ? await _service.createSupplier(
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            contactPerson: contactController.text.trim().isEmpty
                ? null
                : contactController.text.trim(),
            phone: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            email: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            address: addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim(),
            city: cityController.text.trim().isEmpty
                ? null
                : cityController.text.trim(),
            province: provinceController.text.trim().isEmpty
                ? null
                : provinceController.text.trim(),
            postalCode: postalController.text.trim().isEmpty
                ? null
                : postalController.text.trim(),
            npwp: npwpController.text.trim().isEmpty
                ? null
                : npwpController.text.trim(),
            bankName: bankNameController.text.trim().isEmpty
                ? null
                : bankNameController.text.trim(),
            bankAccountNumber: bankAccNoController.text.trim().isEmpty
                ? null
                : bankAccNoController.text.trim(),
            bankAccountName: bankAccNameController.text.trim().isEmpty
                ? null
                : bankAccNameController.text.trim(),
            paymentTerm: paymentTermController.text.trim().isEmpty
                ? null
                : paymentTermController.text.trim(),
            paymentDays: paymentDaysController.text.trim().isEmpty
                ? null
                : paymentDaysController.text.trim(),
            status: status,
          )
        : await _service.updateSupplier(
            id: _toInt(row['id']),
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            contactPerson: contactController.text.trim().isEmpty
                ? null
                : contactController.text.trim(),
            phone: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            email: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            address: addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim(),
            city: cityController.text.trim().isEmpty
                ? null
                : cityController.text.trim(),
            province: provinceController.text.trim().isEmpty
                ? null
                : provinceController.text.trim(),
            postalCode: postalController.text.trim().isEmpty
                ? null
                : postalController.text.trim(),
            npwp: npwpController.text.trim().isEmpty
                ? null
                : npwpController.text.trim(),
            bankName: bankNameController.text.trim().isEmpty
                ? null
                : bankNameController.text.trim(),
            bankAccountNumber: bankAccNoController.text.trim().isEmpty
                ? null
                : bankAccNoController.text.trim(),
            bankAccountName: bankAccNameController.text.trim().isEmpty
                ? null
                : bankAccNameController.text.trim(),
            paymentTerm: paymentTermController.text.trim().isEmpty
                ? null
                : paymentTermController.text.trim(),
            paymentDays: paymentDaysController.text.trim().isEmpty
                ? null
                : paymentDaysController.text.trim(),
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
    final response = await _service.toggleSupplierStatus(
        id: _toInt(row['id']), status: next);
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
        title: const Text('Nonaktifkan Supplier'),
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

    final response = await _service.deleteSupplier(_toInt(row['id']));
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
      title: 'Suppliers',
      showDrawer: true,
      body: Column(
        children: [
          buildMasterHeaderCard(
            icon: Icons.local_shipping_rounded,
            title: 'Master Data Supplier',
            onAddPressed: () => _saveSupplier(),
          ),
          buildMasterFilterCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  readOnly: true,
                  onTap: _openFilterSheet,
                  decoration: const InputDecoration(
                    hintText: 'Filter: kode / nama / CP / phone / email...',
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
                              Center(child: Text('Tidak ada data Supplier')),
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
                                      buildMasterCardTitle(
                                        row['name']?.toString() ?? '-',
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          buildMasterMetaPill(
                                            icon: Icons.person_outline,
                                            text:
                                                'CP: ${_valueOrDash(row['contact_person'])}',
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.call_outlined,
                                            text:
                                                'Phone: ${_valueOrDash(row['phone'])}',
                                          ),
                                          buildMasterMetaPill(
                                            icon: Icons.email_outlined,
                                            text:
                                                'Email: ${_valueOrDash(row['email'])}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      buildMasterMetaText(
                                        'Alamat: ${_valueOrDash(row['address'])}',
                                      ),
                                      const SizedBox(height: 4),
                                      buildMasterMetaText(
                                        'Kota/Provinsi: ${_valueOrDash(row['city'])} / ${_valueOrDash(row['province'])}',
                                      ),
                                      const SizedBox(height: 4),
                                      buildMasterMetaText(
                                        'Payment: ${_valueOrDash(row['payment_term'])} (${_valueOrDash(row['payment_days'])} hari)',
                                      ),
                                      const SizedBox(height: 10),
                                      buildMasterActionButtons(
                                        onEdit: () => _saveSupplier(row: row),
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
