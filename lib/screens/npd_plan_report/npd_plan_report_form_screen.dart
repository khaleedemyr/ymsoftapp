import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/npd_plan_report_models.dart';
import '../../services/npd_plan_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/master_entity_picker.dart';
import 'npd_plan_report_ui.dart';

class _ItemEditorState {
  String productName;
  int? categoryId;
  String? categoryName;
  List<NpdUserOption> pics;
  String? developmentDate;
  String purpose;
  String? proposedLaunchDate;
  List<int> launchOutletIds;
  double fbCost;
  double sellingPrice;
  late final TextEditingController productNameCtrl;
  late final TextEditingController fbCostCtrl;
  late final TextEditingController sellingPriceCtrl;

  _ItemEditorState({
    this.productName = '',
    this.categoryId,
    this.categoryName,
    List<NpdUserOption>? pics,
    this.developmentDate,
    this.purpose = 'new_product',
    this.proposedLaunchDate,
    List<int>? launchOutletIds,
    this.fbCost = 0,
    this.sellingPrice = 0,
  })  : pics = pics ?? [],
        launchOutletIds = launchOutletIds ?? [] {
    productNameCtrl = TextEditingController(text: productName);
    fbCostCtrl = TextEditingController(text: fbCost == 0 ? '' : fbCost.toStringAsFixed(0));
    sellingPriceCtrl = TextEditingController(text: sellingPrice == 0 ? '' : sellingPrice.toStringAsFixed(0));
  }

  void dispose() {
    productNameCtrl.dispose();
    fbCostCtrl.dispose();
    sellingPriceCtrl.dispose();
  }
}

class NpdPlanReportFormScreen extends StatefulWidget {
  final int? recordId;

  const NpdPlanReportFormScreen({super.key, this.recordId});

  @override
  State<NpdPlanReportFormScreen> createState() => _NpdPlanReportFormScreenState();
}

class _NpdPlanReportFormScreenState extends State<NpdPlanReportFormScreen> {
  final _service = NpdPlanReportService();
  final _notesCtrl = TextEditingController();
  final _approverSearchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Timer? _approverTimer;

  String _reportMonth = '';
  int? _outletId;
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _launchOutlets = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _purposeOptions = [];
  List<_ItemEditorState> _items = [_ItemEditorState()];
  List<NpdUserOption> _selectedApprovers = [];
  List<NpdUserOption> _approverResults = [];
  bool _showApproverResults = false;

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _reportMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() {
    _approverTimer?.cancel();
    _notesCtrl.dispose();
    _approverSearchCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getCreateData(recordId: widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message']?.toString() ?? 'Gagal memuat form')),
      );
      return;
    }

    _outlets = (res['outlets'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _launchOutlets = (res['launchOutlets'] as List? ?? res['launch_outlets'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _categories = (res['categories'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _purposeOptions = (res['purposeOptions'] as List? ?? res['purpose_options'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final record = res['record'] as Map?;
    if (record != null) {
      _reportMonth = record['report_month']?.toString() ?? _reportMonth;
      _outletId = record['outlet_id'] as int?;
      _notesCtrl.text = record['notes']?.toString() ?? '';
      _items = (record['items'] as List? ?? []).map((raw) {
        final item = NpdReportItem.fromJson(Map<String, dynamic>.from(raw as Map));
        return _ItemEditorState(
          productName: item.productName,
          categoryId: item.categoryId,
          categoryName: item.category,
          pics: item.pics,
          developmentDate: item.developmentDate,
          purpose: item.purpose,
          proposedLaunchDate: item.proposedLaunchDate,
          launchOutletIds: item.launchOutlets
              .map((e) => e['id'] ?? e['id_outlet'])
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList(),
          fbCost: item.fbCost,
          sellingPrice: item.sellingPrice,
        );
      }).toList();
      if (_items.isEmpty) _items = [_ItemEditorState()];

      final flows = record['approval_flows'] as List? ?? [];
      _selectedApprovers = flows
          .map((f) {
            final m = Map<String, dynamic>.from(f as Map);
            final approver = m['approver'] as Map?;
            if (approver == null) return null;
            return NpdUserOption(
              id: approver['id'] as int? ?? 0,
              name: approver['nama_lengkap']?.toString() ?? '',
            );
          })
          .whereType<NpdUserOption>()
          .toList();
    }

    setState(() => _loading = false);
  }

  void _searchApprovers(String query) {
    _approverTimer?.cancel();
    _approverTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _service.searchApprovers(query.trim());
      if (!mounted) return;
      setState(() {
        _approverResults = results.where((u) => !_selectedApprovers.any((a) => a.id == u.id)).toList();
        _showApproverResults = query.isNotEmpty && _approverResults.isNotEmpty;
      });
    });
  }

  Future<void> _pickMonth() async {
    DateTime initial = DateTime.now();
    if (_reportMonth.length >= 7) {
      final p = _reportMonth.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), 1);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reportMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickDate(ValueChanged<String?> onPicked, String? current) async {
    DateTime initial = DateTime.now();
    if (current != null && current.length >= 10) {
      final p = current.split('-');
      initial = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onPicked('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  Future<void> _pickCategory(_ItemEditorState item) async {
    final picked = await showMasterSingleSelectPicker(
      context: context,
      title: 'Pilih Category',
      source: _categories,
      initialId: item.categoryId,
      idBuilder: NpdPlanReportUi.categoryId,
      labelBuilder: NpdPlanReportUi.categoryName,
    );
    if (picked == null || !mounted) return;
    final cat = _categories.firstWhere((c) => NpdPlanReportUi.categoryId(c) == picked, orElse: () => {});
    setState(() {
      item.categoryId = picked;
      item.categoryName = cat.isNotEmpty ? NpdPlanReportUi.categoryName(cat) : null;
    });
  }

  Future<void> _pickLaunchOutlets(_ItemEditorState item) async {
    final picked = await showMasterMultiSelectPicker(
      context: context,
      title: 'Area / Outlet Launch',
      source: _launchOutlets,
      initialIds: item.launchOutletIds,
      idBuilder: NpdPlanReportUi.outletId,
      labelBuilder: NpdPlanReportUi.outletName,
    );
    if (picked == null || !mounted) return;
    setState(() => item.launchOutletIds = picked);
  }

  Future<void> _pickPics(_ItemEditorState item) async {
    final results = await _service.searchApprovers('');
    final selected = item.pics.map((p) => p.id).toSet();
    if (!mounted) return;

    final picked = await showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        final localSelected = Set<int>.from(selected);
        final searchCtrl = TextEditingController();
        var filtered = results;
        return StatefulBuilder(
          builder: (context, setModal) => AlertDialog(
            title: const Text('Pilih PIC'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(hintText: 'Cari user...', border: OutlineInputBorder()),
                    onChanged: (v) async {
                      final q = v.trim();
                      final users = await _service.searchApprovers(q);
                      setModal(() => filtered = users);
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        return CheckboxListTile(
                          value: localSelected.contains(u.id),
                          title: Text(u.name),
                          subtitle: Text(u.jabatan ?? u.email ?? '-'),
                          onChanged: (checked) {
                            setModal(() {
                              if (checked == true) {
                                localSelected.add(u.id);
                              } else {
                                localSelected.remove(u.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(ctx, localSelected.toList()), child: const Text('Pilih')),
            ],
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    final allUsers = [...results, ...item.pics];
    setState(() {
      item.pics = picked.map((id) {
        final found = allUsers.firstWhere((u) => u.id == id, orElse: () => NpdUserOption(id: id, name: '#$id'));
        return found;
      }).toList();
    });
  }

  String _launchOutletLabel(List<int> ids) {
    if (ids.isEmpty) return 'Pilih outlet launch...';
    final names = ids.map((id) {
      final found = _launchOutlets.firstWhere((o) => NpdPlanReportUi.outletId(o) == id, orElse: () => {});
      return found.isNotEmpty ? NpdPlanReportUi.outletName(found) : '#$id';
    }).toList();
    return names.join(', ');
  }

  Future<void> _save() async {
    if (_outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih outlet')));
      return;
    }
    if (_selectedApprovers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal satu approver')));
      return;
    }

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.productName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product #${i + 1}: nama wajib diisi')));
        return;
      }
      if (item.categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product #${i + 1}: category wajib dipilih')));
        return;
      }
      if (item.launchOutletIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product #${i + 1}: area/outlet wajib dipilih')));
        return;
      }
    }

    setState(() => _saving = true);
    final payload = {
      'report_month': _reportMonth,
      'outlet_id': _outletId,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'approvers': _selectedApprovers.map((a) => a.id).toList(),
      'items': _items.map((item) {
        return {
          'product_name': item.productName.trim(),
          'category_id': item.categoryId,
          'development_date': item.developmentDate,
          'purpose': item.purpose,
          'proposed_launch_date': item.proposedLaunchDate,
          'proposed_launch_outlet_ids': item.launchOutletIds,
          'pic_user_ids': item.pics.map((p) => p.id).toList(),
          'fb_cost': item.fbCost,
          'selling_price': item.sellingPrice,
        };
      }).toList(),
    };

    final res = await _service.save(payload: payload, recordId: widget.recordId);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Widget _buildItemCard(int index, _ItemEditorState item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: NpdPlanReportUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFEF3C7),
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: NpdPlanReportUi.primaryDark)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Product #${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() {
                    item.dispose();
                    _items.removeAt(index);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
            controller: item.productNameCtrl,
            onChanged: (v) => item.productName = v,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickCategory(item),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(item.categoryName ?? 'Pilih category *'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickPics(item),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(item.pics.isEmpty ? 'Pilih PIC' : item.pics.map((p) => p.name).join(', ')),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate((v) => setState(() => item.developmentDate = v), item.developmentDate),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Dev. Date', border: OutlineInputBorder()),
                    child: Text(NpdPlanReportUi.formatDate(item.developmentDate)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate((v) => setState(() => item.proposedLaunchDate = v), item.proposedLaunchDate),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Launch Date', border: OutlineInputBorder()),
                    child: Text(NpdPlanReportUi.formatDate(item.proposedLaunchDate)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: item.purpose,
            decoration: const InputDecoration(labelText: 'Purpose *', border: OutlineInputBorder()),
            items: _purposeOptions
                .map((o) => DropdownMenuItem(value: o['value']?.toString(), child: Text(o['label']?.toString() ?? '')))
                .toList(),
            onChanged: (v) => setState(() => item.purpose = v ?? 'new_product'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickLaunchOutlets(item),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_launchOutletLabel(item.launchOutletIds)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'F&B Cost', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  controller: item.fbCostCtrl,
                  onChanged: (v) => item.fbCost = double.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Selling Price', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  controller: item.sellingPriceCtrl,
                  onChanged: (v) => item.sellingPrice = double.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit NPD Report' : 'Buat NPD Report',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: NpdPlanReportUi.cardDecoration,
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Informasi Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickMonth,
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Bulan *', border: OutlineInputBorder()),
                                  child: Text(NpdPlanReportUi.formatMonth(_reportMonth)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                value: _outletId,
                                decoration: const InputDecoration(labelText: 'Outlet *', border: OutlineInputBorder()),
                                items: _outlets
                                    .map((o) => DropdownMenuItem<int>(
                                          value: NpdPlanReportUi.outletId(o),
                                          child: Text(NpdPlanReportUi.outletName(o)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _outletId = v),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _notesCtrl,
                                decoration: const InputDecoration(labelText: 'Catatan', hintText: 'Catatan opsional...', border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Text('Daftar Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                            FilledButton.icon(
                              onPressed: () => setState(() => _items.add(_ItemEditorState())),
                              style: FilledButton.styleFrom(backgroundColor: NpdPlanReportUi.primary),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_items.length, (i) => _buildItemCard(i, _items[i])),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: NpdPlanReportUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Approval Flow *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const Text('Pilih approver secara berurutan (level 1 = pertama disetujui)', style: TextStyle(fontSize: 12, color: NpdPlanReportUi.textMuted)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _approverSearchCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cari Approver',
                                  hintText: 'Nama, email, atau jabatan...',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _searchApprovers,
                              ),
                              if (_showApproverResults)
                                ..._approverResults.map((u) => ListTile(
                                      dense: true,
                                      title: Text(u.name),
                                      subtitle: Text(u.jabatan ?? u.email ?? '-'),
                                      onTap: () => setState(() {
                                        _selectedApprovers.add(u);
                                        _approverSearchCtrl.clear();
                                        _showApproverResults = false;
                                      }),
                                    )),
                              const SizedBox(height: 8),
                              if (_selectedApprovers.isEmpty)
                                const Text('Belum ada approver dipilih.', style: TextStyle(color: NpdPlanReportUi.textMuted))
                              else
                                ...List.generate(_selectedApprovers.length, (i) {
                                  final a = _selectedApprovers[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(0xFF2563EB),
                                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              if (a.jabatan != null) Text(a.jabatan!, style: const TextStyle(fontSize: 11, color: NpdPlanReportUi.textMuted)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: () => setState(() => _selectedApprovers.removeAt(i)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Batal')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(backgroundColor: NpdPlanReportUi.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: _saving
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
