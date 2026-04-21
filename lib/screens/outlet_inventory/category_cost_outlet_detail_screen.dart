import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import 'package:intl/intl.dart';
import '../../services/outlet_category_cost_service.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/category_cost_type_label.dart';


class CategoryCostOutletDetailScreen extends StatefulWidget {
  final int id;
  const CategoryCostOutletDetailScreen({Key? key, required this.id}) : super(key: key);

  @override
  _CategoryCostOutletDetailScreenState createState() => _CategoryCostOutletDetailScreenState();
}

class _ItemSearchDialog extends StatefulWidget {
  final OutletCategoryCostService service;
  const _ItemSearchDialog({Key? key, required this.service}) : super(key: key);

  @override
  State<_ItemSearchDialog> createState() => _ItemSearchDialogState();
}

/// Sama sumber data & perilaku pencarian dengan izin (My Attendance): GET attendance/approvers.
class _ApproverSearchDialog extends StatefulWidget {
  const _ApproverSearchDialog({Key? key}) : super(key: key);

  @override
  State<_ApproverSearchDialog> createState() => _ApproverSearchDialogState();
}

class _ApproverSearchDialogState extends State<_ApproverSearchDialog> {
  final TextEditingController _q = TextEditingController();
  final AttendanceService _attendance = AttendanceService();
  bool _loading = true;
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadApprovers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onSearchTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadApprovers);
  }

  Future<void> _loadApprovers() async {
    setState(() => _loading = true);
    try {
      final q = _q.text.trim();
      final res = await _attendance.getApprovers(
        search: q.isEmpty ? null : q,
      );
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cari Approver'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _q,
            decoration: const InputDecoration(hintText: 'Cari approver...'),
            onChanged: _onSearchTextChanged,
            onSubmitted: (_) => _loadApprovers(),
          ),
          const SizedBox(height: 8),
          _loading
              ? const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)))
              : SizedBox(
                  height: 260,
                  width: double.maxFinite,
                  child: _results.isEmpty
                      ? const Center(child: Text('Tidak ada approver tersedia'))
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final it = _results[index];
                            final name =
                                it['nama_lengkap']?.toString() ?? it['name']?.toString() ?? '';
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(it['email']?.toString() ?? ''),
                              trailing: (it['jabatan'] != null &&
                                      it['jabatan'].toString().isNotEmpty)
                                  ? Text(
                                      it['jabatan'].toString(),
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : null,
                              onTap: () {
                                final m = Map<String, dynamic>.from(it);
                                m['name'] = m['nama_lengkap'] ?? m['name'] ?? '';
                                Navigator.pop(context, m);
                              },
                            );
                          },
                        ),
                ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(onPressed: _loadApprovers, child: const Text('Cari')),
      ],
    );
  }
}

class _ItemSearchDialogState extends State<_ItemSearchDialog> {
  final TextEditingController _q = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    final res = await widget.service.searchItems(search: q, limit: 20);
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cari Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _q,
            decoration: const InputDecoration(hintText: 'Ketik nama item dan tekan cari'),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
            _loading
              ? const Center(child: AppLoadingIndicator(size: 20, color: Color(0xFF6366F1)))
              : SizedBox(
                  height: 240,
                  width: double.maxFinite,
                  child: _results.isEmpty
                      ? const Center(child: Text('No results'))
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final it = _results[index];
                            return ListTile(
                              title: Text(it['name'] ?? it['item_name'] ?? ''),
                              subtitle: Text(it['sku']?.toString() ?? ''),
                              onTap: () => Navigator.pop(context, it),
                            );
                          },
                        ),
                ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(onPressed: _search, child: const Text('Cari')),
      ],
    );
  }
}

class _CategoryCostOutletDetailScreenState extends State<CategoryCostOutletDetailScreen> {
  final _service = OutletCategoryCostService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingOutlets = true;
  bool _loadingUsageBom = false;

  // form fields
  String? _type;
  String? _status;
  String? _number;
  int? _headerId;
  DateTime _date = DateTime.now();
  int? _outletId;
  int? _warehouseOutletId;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _usageSearchController = TextEditingController();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _warehouseOutlets = [];
  final Map<String, bool> _usageExpandedByCategory = {};

  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _approvers = [];

  bool _forceEdit = false;

  bool get _canEditDraft => (_status ?? '').toUpperCase() == 'DRAFT';

  bool get _isReadOnly {
    if (widget.id == 0) return false;
    if (_canEditDraft && _forceEdit) return false;
    return true;
  }

  final List<Map<String, String>> _typeOptions = [
    {'value': 'internal_use', 'label': 'Internal Use'},
    {'value': 'spoil', 'label': 'Spoil'},
    {'value': 'waste', 'label': 'Waste'},
    {'value': 'usage', 'label': 'Usage'},
    {'value': 'r_and_d', 'label': 'R & D'},
    {'value': 'marketing', 'label': 'Marketing'},
    {'value': 'non_commodity', 'label': 'Non Commodity'},
    {'value': 'guest_supplies', 'label': 'Guest Supplies'},
    {'value': 'wrong_maker', 'label': 'Wrong Maker'},
    {'value': 'training', 'label': 'Training'},
  ];

  static const Set<String> _approvalRequiredTypes = {
    'r_and_d',
    'marketing',
    'wrong_maker',
    'training',
  };

  /// Usage: auto-fill dari item_bom.stock_cut=1 + stok outlet (sama endpoint Stock Cut web).
  bool get _isUsageAutoBom => (_type ?? '') == 'usage';

  String _usageCategory(Map<String, dynamic> item) {
    final cat = item['category_name']?.toString().trim();
    return (cat == null || cat.isEmpty) ? 'Tanpa Kategori' : cat;
  }

  Map<String, List<int>> _groupedUsageIndices() {
    final q = _usageSearchController.text.trim().toLowerCase();
    final groups = <String, List<int>>{};
    for (var i = 0; i < _items.length; i++) {
      final itemName = (_items[i]['item_name'] ?? '').toString();
      if (q.isNotEmpty && !itemName.toLowerCase().contains(q)) continue;
      final cat = _usageCategory(_items[i]);
      groups.putIfAbsent(cat, () => <int>[]).add(i);
    }
    final sortedKeys = groups.keys.toList()..sort();
    final sorted = <String, List<int>>{};
    for (final key in sortedKeys) {
      sorted[key] = groups[key]!;
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _loadForm();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _usageSearchController.dispose();
    for (final it in _items) {
      (it['qtyController'] as TextEditingController?)?.dispose();
      (it['noteController'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() {
      _isLoadingOutlets = true;
      _isLoading = true;
    });

    try {
      _outlets = await _service.getOutlets();

      // If outlets empty, try to set user's outlet from auth data
      if ((_outlets.isEmpty) ) {
        try {
          final auth = AuthService();
          final user = await auth.getUserData();
          final rawOutletId = user?['id_outlet'];
          final userOutletId = rawOutletId is int ? rawOutletId : int.tryParse('$rawOutletId');
          if (userOutletId != null) {
            _outletId = userOutletId;
            // attempt to load warehouse outlets for user's outlet
            _warehouseOutlets = await _service.getWarehouseOutlets(outletId: _outletId);
          }
        } catch (e) {
          // ignore
        }
      }

      if (widget.id != 0) {
        final resp = await _service.getDetail(widget.id);
        if (resp != null) {
          final data = resp['data'] ?? resp;
          _headerId = data['id'] is int ? data['id'] : int.tryParse('${data['id'] ?? ''}');
          _type = data['type']?.toString();
          if (_type == 'stock_cut') _type = 'usage'; // legacy → Usage
          _status = data['status']?.toString();
          _number = data['number']?.toString();
          _notesController.text = data['notes']?.toString() ?? '';
          if (data['date'] != null) {
            _date = DateTime.parse(data['date']);
          }
          _outletId = (data['outlet_id'] is int) ? data['outlet_id'] : int.tryParse('${data['outlet_id'] ?? ''}');
          _warehouseOutletId = (data['warehouse_outlet_id'] is int) ? data['warehouse_outlet_id'] : int.tryParse('${data['warehouse_outlet_id'] ?? ''}');
          final itemsRaw = (resp['items'] ?? data['items'] ?? []) as List;
          _items.clear();
          for (final raw in itemsRaw) {
            final m = Map<String, dynamic>.from(raw);
            final qtyCtrl = TextEditingController(text: '${m['qty'] ?? ''}');
            final noteCtrl = TextEditingController(text: '${m['note'] ?? ''}');
            _items.add({
              'item_id': m['item_id'] ?? m['id'] ?? m['item']?['id'],
              'item_name': m['item_name'] ?? m['name'] ?? m['item']?['name'] ?? '',
              'unit_id': m['unit_id'] ?? m['unit'] ?? '',
              'unit_name': m['unit_name'] ?? m['unit']?['name'] ?? '',
              'qtyController': qtyCtrl,
              'noteController': noteCtrl,
              'unitOptions': <Map<String, dynamic>>[],
            });
          }
          if ((_type ?? '') == 'usage') {
            for (final it in _items) {
              final uid = it['unit_id'];
              final un = (it['unit_name'] ?? '').toString();
              if (uid != null && '$uid'.isNotEmpty) {
                final idNum = uid is int ? uid : int.tryParse('$uid');
                it['unitOptions'] = [
                  {'id': idNum, 'name': un},
                ];
              }
            }
          }
        }
      } else {
        // default: one empty item
        _type ??= 'internal_use';
        _addEmptyItem();
      }
      if (_outletId != null) {
        _warehouseOutlets = await _service.getWarehouseOutlets(outletId: _outletId);
      }
      if (widget.id != 0 &&
          (_type ?? '') == 'usage' &&
          _outletId != null &&
          _warehouseOutletId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _refreshStockForAllItems();
        });
      }
    } catch (e) {
      print('Error loading form: $e');
    } finally {
      setState(() {
        _isLoadingOutlets = false;
        _isLoading = false;
      });
    }
  }

  void _disposeAllItemRows() {
    for (final it in _items) {
      (it['qtyController'] as TextEditingController?)?.dispose();
      (it['noteController'] as TextEditingController?)?.dispose();
    }
    _items.clear();
  }

  Future<void> _loadUsageBomItems() async {
    if (!_isUsageAutoBom) return;
    if (_outletId == null || _warehouseOutletId == null) return;

    setState(() => _loadingUsageBom = true);
    try {
      final rows = await _service.getStockCutItems(
        outletId: _outletId!,
        warehouseOutletId: _warehouseOutletId!,
      );
      _disposeAllItemRows();
      _usageExpandedByCategory.clear();
      for (final row in rows) {
        final itemId = row['item_id'];
        final uid = row['unit_id'];
        final uname = row['unit_name']?.toString() ?? '';
        final stock = row['stock'];
        final categoryName = row['category_name']?.toString() ?? 'Tanpa Kategori';
        final qtyCtrl = TextEditingController();
        final noteCtrl = TextEditingController();
        final idNum = uid is int ? uid : int.tryParse('$uid');
        _items.add({
          'item_id': itemId,
          'item_name': row['item_name']?.toString() ?? '',
          'category_name': categoryName,
          'unit_id': idNum ?? uid,
          'unit_name': uname,
          'qtyController': qtyCtrl,
          'noteController': noteCtrl,
          'stock': stock,
          'unitOptions': idNum != null || uid != null
              ? <Map<String, dynamic>>[
                  {'id': idNum ?? uid, 'name': uname},
                ]
              : <Map<String, dynamic>>[],
        });
        _usageExpandedByCategory[categoryName] = true;
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingUsageBom = false);
    }
  }

  void _addEmptyItem() {
    _items.add({
      'item_id': null,
      'item_name': '',
      'unit_id': null,
      'qtyController': TextEditingController(text: '1'),
      'noteController': TextEditingController(),
      'stock': null,
      'unitOptions': <Map<String, dynamic>>[],
    });
  }

  void _removeItem(int idx) {
    if (idx < 0 || idx >= _items.length) return;
    final it = _items.removeAt(idx);
    (it['qtyController'] as TextEditingController?)?.dispose();
    (it['noteController'] as TextEditingController?)?.dispose();
    setState(() {});
  }

  Future<void> _openItemSearch(int idx) async {
    if (_isUsageAutoBom) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _ItemSearchDialog(service: _service);
      },
    );

    if (selected != null) {
      final rawUnits = await _service.getItemUnits(selected['id']);
      final units = _dedupeUnits(rawUnits);
      setState(() {
        _items[idx]['item_id'] = selected['id'];
        _items[idx]['item_name'] = selected['name'];
        _items[idx]['unitOptions'] = units;
        if (units.isNotEmpty) {
          _items[idx]['unit_id'] = units.first['id'];
          _items[idx]['unit_name'] = units.first['name'];
        } else {
          _items[idx]['unit_id'] = null;
          _items[idx]['unit_name'] = '';
        }
        _items[idx]['stock'] = null;
      });

      await _loadStockForItem(idx);
    }
  }

  Future<void> _loadStockForItem(int idx) async {
    if (_outletId == null || _warehouseOutletId == null) return;
    final itemId = _items[idx]['item_id'];
    if (itemId == null) return;

    final stock = await _service.getStock(
      itemId: int.tryParse('$itemId') ?? 0,
      outletId: _outletId!,
      warehouseOutletId: _warehouseOutletId!,
    );

    if (!mounted) return;
    setState(() {
      _items[idx]['stock'] = stock;
    });
  }

  Future<void> _refreshStockForAllItems() async {
    for (var i = 0; i < _items.length; i++) {
      await _loadStockForItem(i);
    }
  }

  List<Map<String, dynamic>> _dedupeUnits(List<Map<String, dynamic>> units) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final u in units) {
      final key = (u['id'] ?? '').toString();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      result.add(u);
    }
    return result;
  }

  Color _itemAccentColor(int index) {
    const accents = [
      Color(0xFF10B981),
      Color(0xFF6366F1),
      Color(0xFFF59E0B),
      Color(0xFF0EA5E9),
    ];
    return accents[index % accents.length];
  }

  String _formatStock(Map<String, dynamic>? stock) {
    if (stock == null) return 'Stok: pilih outlet & warehouse';
    if (stock['success'] == false) {
      final msg = stock['message']?.toString();
      return msg == null || msg.isEmpty ? 'Stok: tidak tersedia' : msg;
    }
    final small = stock['qty_small'] ?? 0;
    final medium = stock['qty_medium'] ?? 0;
    final large = stock['qty_large'] ?? 0;
    final unitSmall = stock['unit_small'] ?? '';
    final unitMedium = stock['unit_medium'] ?? '';
    final unitLarge = stock['unit_large'] ?? '';

    final parts = <String>[];
    if (small != 0 || unitSmall.toString().isNotEmpty) parts.add('$small $unitSmall'.trim());
    if (medium != 0 || unitMedium.toString().isNotEmpty) parts.add('$medium $unitMedium'.trim());
    if (large != 0 || unitLarge.toString().isNotEmpty) parts.add('$large $unitLarge'.trim());
    if (parts.isEmpty) return 'Stok: 0';
    return 'Stok: ${parts.join(' | ')}';
  }

  bool _requiresApproval(String? type) {
    if (type == null || type.isEmpty) return false;
    return _approvalRequiredTypes.contains(type);
  }

  Future<void> _openApproverSearch() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return const _ApproverSearchDialog();
      },
    );

    if (selected != null && selected['id'] != null) {
      final exists = _approvers.any((a) => a['id'].toString() == selected['id'].toString());
      if (!exists) {
        setState(() => _approvers.add(selected));
      }
    }
  }

  void _removeApprover(int idx) {
    if (idx < 0 || idx >= _approvers.length) return;
    setState(() => _approvers.removeAt(idx));
  }

  void _moveApprover(int from, int to) {
    if (from < 0 || from >= _approvers.length) return;
    if (to < 0 || to >= _approvers.length) return;
    setState(() {
      final item = _approvers.removeAt(from);
      _approvers.insert(to, item);
    });
  }
  
  void _showPreview({VoidCallback? onConfirm, String confirmLabel = 'Submit'}) {
    final items = _items
        .where((it) => (it['item_id'] != null) && ((it['qtyController'] as TextEditingController).text.trim().isNotEmpty))
        .toList();
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Preview Category Cost', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreviewRow('Type', _typeLabel(_type)),
                      _buildPreviewRow('Date', DateFormat('yyyy-MM-dd').format(_date)),
                      _buildPreviewRow('Outlet', _findOutletName(_outletId)),
                      _buildPreviewRow('Warehouse', _findWarehouseName(_warehouseOutletId)),
                      _buildPreviewRow('Notes', _notesController.text.isEmpty ? '-' : _notesController.text),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text('Belum ada item')
                else
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final it = items[index];
                        final accent = _itemAccentColor(index);
                        final qtyText = (it['qtyController'] as TextEditingController).text;
                        final unitName = it['unit_name']?.toString().isNotEmpty == true
                            ? it['unit_name']
                            : _findUnitName(it);
                        final noteText = (it['noteController'] as TextEditingController).text.trim();
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(left: BorderSide(color: accent, width: 3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it['item_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Qty: $qtyText ${unitName ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              if (noteText.isNotEmpty)
                                Text('Note: $noteText', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (onConfirm != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onConfirm();
                          },
                          child: Text(confirmLabel),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startDraftEdit() {
    if (!_canEditDraft) return;
    setState(() => _forceEdit = true);
  }

  Future<void> _save({bool submit = false}) async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_outletId == null) {
      _showMessage('Pilih outlet terlebih dahulu');
      return;
    }
    if (_warehouseOutletId == null) {
      _showMessage('Pilih warehouse outlet terlebih dahulu');
      return;
    }

    if (submit && _requiresApproval(_type) && _approvers.isEmpty) {
      _showMessage('Tipe ini wajib memiliki minimal 1 approver');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final it in _items) {
      final qty = double.tryParse((it['qtyController'] as TextEditingController).text.replaceAll(',', '')) ?? 0;
      if (it['item_id'] == null) {
        _showMessage('Isi item terlebih dahulu');
        return;
      }
      if (qty <= 0) {
        _showMessage('Qty harus lebih dari 0');
        return;
      }
      itemsPayload.add({
        'item_id': it['item_id'],
        'qty': qty,
        'unit_id': it['unit_id'],
        'note': (it['noteController'] as TextEditingController?)?.text.trim().isEmpty == true
            ? null
            : (it['noteController'] as TextEditingController).text.trim(),
      });
    }

    final payload = {
      if (_headerId != null) 'header_id': _headerId,
      'type': _type,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'outlet_id': _outletId,
      'warehouse_outlet_id': _warehouseOutletId,
      'notes': _notesController.text,
      'items': itemsPayload,
      'approvers': _approvers.map((a) => a['id']).toList(),
    };

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? result;
      if (submit) {
        result = await _service.storeAndSubmit(payload);
      } else {
        result = await _service.save(payload);
      }

      if (result != null && (result['success'] == true || result['message']?.toString().toLowerCase().contains('berhasil') == true)) {
        _showMessage(submit ? 'Dikirim untuk approval' : 'Disimpan', success: true);
        Navigator.pop(context, true);
      } else {
        _showMessage(result?['message']?.toString() ?? 'Gagal menyimpan data');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, {bool success = false}) {
    if (!success) {
      _showErrorDialog(msg);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gagal'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _buildReadOnlyDetail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildReadOnlyItems(),
              ],
            ),
          ),
          if (_canEditDraft && !_forceEdit) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startDraftEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Lanjutkan Draft'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _number?.isNotEmpty == true ? _number! : 'Detail Category Cost',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              _buildStatusChip(_status),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoTile(Icons.category, 'Type', _typeLabel(_type)),
          _buildInfoTile(Icons.event, 'Date', DateFormat('yyyy-MM-dd').format(_date)),
          _buildInfoTile(Icons.store, 'Outlet', _findOutletName(_outletId)),
          _buildInfoTile(Icons.warehouse, 'Warehouse', _findWarehouseName(_warehouseOutletId)),
          _buildInfoTile(Icons.notes, 'Notes', _notesController.text.isEmpty ? '-' : _notesController.text),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    final label = (status ?? '-').toUpperCase();
    Color bg;
    Color fg;
    if (label == 'DRAFT') {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFF9A3412);
    } else if (label == 'SUBMITTED') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (label == 'APPROVED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (label == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFE2E8F0);
      fg = const Color(0xFF334155);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyItems() {
    if (_items.isEmpty) {
      return const Center(child: Text('No items'));
    }

    return Column(
      children: List.generate(_items.length, (index) {
        final it = _items[index];
        final accent = _itemAccentColor(index);
        final qtyText = (it['qtyController'] as TextEditingController?)?.text ?? '-';
        final unitName = it['unit_name']?.toString().isNotEmpty == true
            ? it['unit_name']
            : _findUnitName(it);
        final noteText = (it['noteController'] as TextEditingController?)?.text ?? '';
        return Padding(
          padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: accent, width: 4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.inventory_2, size: 16, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        it['item_name'] ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Qty: $qtyText ${unitName ?? ''}'.trim(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                if (noteText.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Note: $noteText',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.id == 0 ? 'Input Category Cost Outlet' : 'Edit Category Cost Outlet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            const Text('Informasi Utama', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isNarrow = maxWidth < 520;
              final twoColumnWidth = maxWidth > 600 ? (maxWidth - 12) / 2 : maxWidth;
              final fieldWidth = isNarrow
                  ? maxWidth
                  : min(maxWidth, min(320.0, max(220.0, twoColumnWidth)));
              final dateWidth = isNarrow ? maxWidth : min(maxWidth, min(200.0, twoColumnWidth));

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      items: _typeOptions
                          .map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!)))
                          .toList(),
                      onChanged: (v) async {
                        final prev = _type;
                        setState(() => _type = v);
                        if (v == 'usage') {
                          _usageSearchController.clear();
                          await _loadUsageBomItems();
                        } else if (prev == 'usage' && v != 'usage' && widget.id == 0) {
                          _disposeAllItemRows();
                          _addEmptyItem();
                          _usageSearchController.clear();
                          _usageExpandedByCategory.clear();
                          setState(() {});
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Type'),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib dipilih' : null,
                    ),
                  ),
                  SizedBox(
                    width: dateWidth,
                    child: _buildReadOnlyField('Date', DateFormat('yyyy-MM-dd').format(_date), onTap: _pickDate),
                  ),
                ],
              );
            },
            ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isNarrow = maxWidth < 520;
              final twoColumnWidth = maxWidth > 600 ? (maxWidth - 12) / 2 : maxWidth;
              final fieldWidth = isNarrow
                  ? maxWidth
                  : min(maxWidth, min(320.0, max(220.0, twoColumnWidth)));

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int>(
                      value: _outlets.any((o) => (o['id_outlet'] ?? o['id'])?.toString() == _outletId?.toString())
                          ? _outletId
                          : null,
                      items: _outlets.map((o) {
                        final id = o['id_outlet'] ?? o['id'];
                        final name = o['nama_outlet'] ?? o['name'] ?? o['outlet_name'];
                        return DropdownMenuItem(value: int.tryParse('$id'), child: Text(name ?? ''));
                      }).toList(),
                      onChanged: (v) async {
                        setState(() {
                          _outletId = v;
                          _warehouseOutletId = null;
                          _warehouseOutlets = [];
                          for (final it in _items) {
                            it['stock'] = null;
                          }
                          if (_isUsageAutoBom) {
                            _disposeAllItemRows();
                            _usageSearchController.clear();
                            _usageExpandedByCategory.clear();
                          }
                        });
                        if (v != null) {
                          final w = await _service.getWarehouseOutlets(outletId: v);
                          setState(() => _warehouseOutlets = w);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Outlet'),
                      validator: (v) => v == null ? 'Wajib dipilih' : null,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int>(
                      value: _warehouseOutlets.any((w) => w['id']?.toString() == _warehouseOutletId?.toString())
                          ? _warehouseOutletId
                          : null,
                      items: _warehouseOutlets.map((w) {
                        return DropdownMenuItem(value: int.tryParse('${w['id']}'), child: Text(w['name'] ?? ''));
                      }).toList(),
                      onChanged: (v) async {
                        setState(() => _warehouseOutletId = v);
                        if (_isUsageAutoBom && v != null) {
                          await _loadUsageBomItems();
                        } else {
                          await _refreshStockForAllItems();
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Warehouse Outlet'),
                      validator: (v) => v == null ? 'Wajib dipilih' : null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildItemsSection(),
          if (_requiresApproval(_type)) ...[
            const SizedBox(height: 16),
            _buildApprovalSection(),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _save(submit: false),
                  child: _isLoading
                      ? const AppLoadingIndicator(size: 18, color: Colors.white)
                      : const Text('Simpan Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _showPreview(onConfirm: () => _save(submit: true), confirmLabel: 'Submit'),
                  child: _isLoading
                      ? const AppLoadingIndicator(size: 18, color: Colors.white)
                      : const Text('Simpan & Submit'),
                ),
              ),
            ],
          ),
          if (widget.id != 0 && _canEditDraft) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _forceEdit = false),
                icon: const Icon(Icons.visibility),
                label: const Text('Kembali ke Detail'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final usageGroups = _isUsageAutoBom ? _groupedUsageIndices() : const <String, List<int>>{};
    final usageVisibleCount = usageGroups.values.fold<int>(0, (sum, idxs) => sum + idxs.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(
              onPressed: _isUsageAutoBom ? null : () => setState(() => _addEmptyItem()),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Item'),
            ),
          ],
        ),
        if (_isUsageAutoBom && _loadingUsageBom) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(
            'Memuat item BOM (stock cut)…',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
        if (_isUsageAutoBom) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usageSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Cari item usage',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Menampilkan $usageVisibleCount item', style: const TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (final key in usageGroups.keys) {
                                _usageExpandedByCategory[key] = true;
                              }
                            });
                          },
                          child: const Text('Expand All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (final key in usageGroups.keys) {
                                _usageExpandedByCategory[key] = false;
                              }
                            });
                          },
                          child: const Text('Collapse All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        _isUsageAutoBom
            ? (usageGroups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _items.isEmpty
                            ? 'Tidak ada material BOM (stock cut) dengan stok di outlet & warehouse ini.'
                            : 'Tidak ada item yang cocok dengan pencarian.',
                      ),
                    ),
                  )
                : Column(
                    children: usageGroups.entries.map((entry) {
                      final category = entry.key;
                      final isOpen = _usageExpandedByCategory[category] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ExpansionTile(
                          key: ValueKey('usage-cat-$category'),
                          initiallyExpanded: isOpen,
                          onExpansionChanged: (expanded) {
                            _usageExpandedByCategory[category] = expanded;
                          },
                          title: Text('$category (${entry.value.length})'),
                          children: entry.value.map((idx) => _buildItemCard(idx)).toList(),
                        ),
                      );
                    }).toList(),
                  ))
            : _items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Belum ada item',
                  ),
                ),
              )
            : Column(
                children: List.generate(_items.length, (index) => _buildItemCard(index)),
              ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _isUsageAutoBom ? null : () => setState(() => _addEmptyItem()),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Item'),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final it = _items[index];
    final accent = _itemAccentColor(index);
    final rawUnitOptions = it['unitOptions'] as List? ?? [];
    final unitOptions = _dedupeUnits(rawUnitOptions.cast<Map<String, dynamic>>());
    final unitValue = unitOptions.any((u) => '${u['id']}' == '${it['unit_id']}')
        ? int.tryParse('${it['unit_id']}')
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Text('Item #${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: (_items.length <= 1 || _isUsageAutoBom) ? null : () => _removeItem(index),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Hapus'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isUsageAutoBom)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Item'),
              child: Text(
                (it['item_name'] ?? '').toString().isEmpty ? '-' : '${it['item_name']}',
                style: const TextStyle(color: Color(0xFF0F172A)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openItemSearch(index),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Item'),
                      child: Text(
                        (it['item_name'] ?? '').toString().isEmpty ? 'Pilih item' : it['item_name'],
                        style: TextStyle(
                          color: (it['item_name'] ?? '').toString().isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _openItemSearch(index),
                  icon: const Icon(Icons.search),
                  tooltip: 'Cari Item',
                ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.inventory, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatStock(it['stock']),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: it['qtyController'] as TextEditingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty'),
                  validator: (v) {
                    final val = double.tryParse(v ?? '0') ?? 0;
                    if (val <= 0) return '>0';
                    return null;
                  },
                ),
              ),
              if (_isUsageAutoBom)
                SizedBox(
                  width: 220,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Unit (terkecil)'),
                    child: Text(
                      unitOptions.isNotEmpty
                          ? '${unitOptions.first['name'] ?? ''}'
                          : (it['unit_name'] ?? '').toString(),
                      style: const TextStyle(color: Color(0xFF0F172A)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int>(
                    value: unitValue,
                    items: unitOptions
                        .map<DropdownMenuItem<int>>((u) => DropdownMenuItem(
                              value: int.tryParse('${u['id']}'),
                              child: Text(u['name'] ?? ''),
                            ))
                        .toList(),
                    onChanged: unitOptions.isEmpty
                        ? null
                        : (v) {
                            setState(() {
                              it['unit_id'] = v;
                              final match = unitOptions.firstWhere(
                                (u) => '${u['id']}' == '${v ?? ''}',
                                orElse: () => {},
                              );
                              it['unit_name'] = match['name'] ?? it['unit_name'];
                            });
                          },
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: it['noteController'] as TextEditingController,
            decoration: const InputDecoration(labelText: 'Note'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Approval Flow', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _openApproverSearch,
                icon: const Icon(Icons.person_add),
                label: const Text('Tambah Approver'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_approvers.isEmpty)
            const Text('Wajib menambahkan minimal 1 approver untuk tipe ini.')
          else
            Column(
              children: List.generate(_approvers.length, (index) {
                final approver = _approvers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: index > 0 ? () => _moveApprover(index, index - 1) : null,
                            icon: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          IconButton(
                            onPressed: index < _approvers.length - 1 ? () => _moveApprover(index, index + 1) : null,
                            icon: const Icon(Icons.arrow_downward, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Level ${index + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(approver['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if ((approver['email'] ?? '').toString().isNotEmpty)
                              Text(approver['email'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            if ((approver['jabatan'] ?? '').toString().isNotEmpty)
                              Text(approver['jabatan'], style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeApprover(index),
                        icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String? value) {
    for (final t in _typeOptions) {
      if (t['value'] == value) {
        return t['label'] ?? categoryCostTypeLabel(value);
      }
    }
    return categoryCostTypeLabel(value);
  }

  String _findOutletName(int? id) {
    if (id == null) return '-';
    final match = _outlets.firstWhere(
      (o) => (o['id_outlet'] ?? o['id'])?.toString() == id.toString(),
      orElse: () => {},
    );
    return (match['nama_outlet'] ?? match['name'] ?? match['outlet_name'] ?? '-').toString();
  }

  String _findWarehouseName(int? id) {
    if (id == null) return '-';
    final match = _warehouseOutlets.firstWhere(
      (w) => w['id']?.toString() == id.toString(),
      orElse: () => {},
    );
    return (match['name'] ?? '-').toString();
  }

  String _findUnitName(Map<String, dynamic> item) {
    final unitId = item['unit_id'];
    final list = item['unitOptions'] as List? ?? [];
    final match = list.firstWhere(
      (u) => u['id']?.toString() == unitId?.toString(),
      orElse: () => {},
    );
    return (match['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.id == 0 ? 'Buat Category Cost' : 'Detail Category Cost'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: _isLoadingOutlets && _outlets.isEmpty
          ? const Center(child: AppLoadingIndicator(size: 24, color: Color(0xFF6366F1)))
          : Form(
              key: _formKey,
              child: _isReadOnly ? _buildReadOnlyDetail() : _buildEditForm(),
            ),
    );
  }
}
