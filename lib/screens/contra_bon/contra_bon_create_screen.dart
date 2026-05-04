import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/contra_bon_service.dart';

class ContraBonCreateScreen extends StatefulWidget {
  const ContraBonCreateScreen({super.key});

  @override
  State<ContraBonCreateScreen> createState() => _ContraBonCreateScreenState();
}

class _ContraBonCreateScreenState extends State<ContraBonCreateScreen> {
  final _service = ContraBonService();
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  int _step = 0;
  String? _sourceType;

  bool _loadingSources = false;
  List<Map<String, dynamic>> _sourceDocs = [];
  List<Map<String, dynamic>> _selectedSources = [];
  Set<String> _selectedDocKeys = <String>{};
  String? _selectedSupplierKey;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<bool> _itemSelected = [];
  List<TextEditingController> _priceCtrl = [];
  List<TextEditingController> _qtyCtrl = [];

  DateTime _date = DateTime.now();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _invoiceCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _priceCtrl) c.dispose();
    for (final c in _qtyCtrl) c.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    setState(() {
      _sourceType = type;
      _step = 1;
      _sourceDocs = [];
      _selectedSources = [];
      _selectedDocKeys.clear();
      _selectedSupplierKey = null;
      _searchCtrl.clear();
    });
    _loadSources();
  }

  Future<void> _loadSources({String? search}) async {
    setState(() => _loadingSources = true);
    try {
      if (_sourceType == 'purchase_order') {
        final resp = await _service.getPoWithGr(search: search);
        final list = (resp?['data'] as List<dynamic>?) ?? [];
        setState(() => _sourceDocs = list.cast<Map<String, dynamic>>().map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'purchase_order';
          return m;
        }).toList());
      } else if (_sourceType == 'retail_food') {
        final list = await _service.getRetailFoodSources(search: search);
        setState(() => _sourceDocs = (list ?? []).cast<Map<String, dynamic>>().map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'retail_food';
          return m;
        }).toList());
      } else if (_sourceType == 'warehouse_retail_food') {
        final list = await _service.getWarehouseRetailFoodSources(search: search);
        setState(() => _sourceDocs = (list ?? []).cast<Map<String, dynamic>>().map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'warehouse_retail_food';
          return m;
        }).toList());
      } else if (_sourceType == 'retail_non_food') {
        final resp = await _service.getRetailNonFoodSources(search: search);
        final list = (resp?['data'] as List<dynamic>?) ?? [];
        setState(() => _sourceDocs = list.cast<Map<String, dynamic>>().map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'retail_non_food';
          return m;
        }).toList());
      } else if (_sourceType == 'mixed') {
        final results = await Future.wait([
          _service.getPoWithGr(search: search),
          _service.getRetailFoodSources(search: search),
          _service.getWarehouseRetailFoodSources(search: search),
          _service.getRetailNonFoodSources(search: search),
        ]);

        final poResp = results[0] as Map<String, dynamic>?;
        final poDocs = ((poResp?['data'] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>()
            .map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'purchase_order';
          return m;
        });

        final retailFoodDocs = ((results[1] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'retail_food';
          return m;
        });

        final warehouseRetailFoodDocs = ((results[2] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'warehouse_retail_food';
          return m;
        });

        final rnfResp = results[3] as Map<String, dynamic>?;
        final retailNonFoodDocs = ((rnfResp?['data'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((e) {
          final m = Map<String, dynamic>.from(e);
          m['source_type'] = 'retail_non_food';
          return m;
        });

        setState(() {
          _sourceDocs = [
            ...poDocs,
            ...retailFoodDocs,
            ...warehouseRetailFoodDocs,
            ...retailNonFoodDocs,
          ];
        });
      }
    } finally {
      setState(() => _loadingSources = false);
    }
  }

  String _docSourceType(Map<String, dynamic> doc) {
    return (doc['source_type'] ?? _sourceType ?? '').toString();
  }

  String _docKey(Map<String, dynamic> doc) {
    final sourceType = _docSourceType(doc);
    if (sourceType == 'purchase_order') {
      return 'po_${doc['po_id']}_gr_${doc['gr_id']}';
    }

    final id = doc['retail_food_id'] ??
        doc['warehouse_retail_food_id'] ??
        doc['retail_non_food_id'] ??
        doc['id'];
    if (id != null && id.toString().isNotEmpty && id.toString().toLowerCase() != 'null') {
      return '${sourceType}_id_$id';
    }

    final docNo = (doc['retail_number'] ?? doc['gr_number'] ?? doc['po_number'] ?? '').toString().trim();
    final supplier = (doc['supplier_id'] ?? doc['supplier_name'] ?? '').toString().trim();
    final outlet = (doc['outlet_id'] ?? doc['warehouse_outlet_id'] ?? doc['outlet_name'] ?? doc['warehouse_outlet_name'] ?? '')
        .toString()
        .trim();

    if (docNo.isNotEmpty) {
      return '${sourceType}_no_${docNo}_sup_${supplier}_out_${outlet}';
    }

    return '${sourceType}_fallback_${doc.hashCode}';
  }

  String _supplierKey(Map<String, dynamic> doc) {
    final supplierId = doc['supplier_id']?.toString();
    if (supplierId != null && supplierId.isNotEmpty) return supplierId;
    return (doc['supplier_name'] ?? '').toString().trim().toLowerCase();
  }

  int? _sourceIdFromDoc(Map<String, dynamic> doc) {
    final srcId = doc['retail_food_id'] ??
        doc['warehouse_retail_food_id'] ??
        doc['retail_non_food_id'] ??
        doc['id'];
    if (srcId is int) return srcId;
    if (srcId is String) return int.tryParse(srcId);
    return null;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  void _toggleSourceSelection(Map<String, dynamic> doc) {
    final key = _docKey(doc);
    final supplierKey = _supplierKey(doc);
    setState(() {
      if (_selectedDocKeys.contains(key)) {
        _selectedDocKeys.remove(key);
        _selectedSources.removeWhere((s) => _docKey(s) == key);
        if (_selectedSources.isEmpty) {
          _selectedSupplierKey = null;
        }
      } else {
        if (_selectedSupplierKey != null && _selectedSupplierKey != supplierKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hanya bisa campur dokumen dengan supplier yang sama')),
          );
          return;
        }
        _selectedSupplierKey ??= supplierKey;
        _selectedDocKeys.add(key);
        _selectedSources.add(doc);
      }
    });
  }

  Future<void> _continueToItemsStep() async {
    if (_selectedSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu dokumen sumber')),
      );
      return;
    }

    setState(() {
      _step = 2;
      _items = [];
      _itemSelected = [];
    });

    final items = <Map<String, dynamic>>[];
    for (final doc in _selectedSources) {
      final docSourceType = _docSourceType(doc);
      if (docSourceType == 'purchase_order') {
        for (final i in (doc['items'] as List<dynamic>?) ?? []) {
          final m = Map<String, dynamic>.from(i as Map);
          m['_grItemId'] = m['id'];
          m['_sourceType'] = 'purchase_order';
          m['_sourceId'] = doc['po_id'];
          m['_poId'] = doc['po_id'];
          m['_grId'] = doc['gr_id'];
          items.add(m);
        }
      } else if (docSourceType == 'retail_food') {
        for (final i in (doc['items'] as List<dynamic>?) ?? []) {
          final m = Map<String, dynamic>.from(i as Map);
          m['_rfItemId'] = m['id'];
          m['quantity'] = m['qty'];
          m['_sourceType'] = 'retail_food';
          m['_sourceId'] = _sourceIdFromDoc(doc);
          items.add(m);
        }
      } else if (docSourceType == 'warehouse_retail_food') {
        for (final i in (doc['items'] as List<dynamic>?) ?? []) {
          final m = Map<String, dynamic>.from(i as Map);
          m['_wrfItemId'] = m['id'];
          m['quantity'] = m['qty'];
          m['_sourceType'] = 'warehouse_retail_food';
          m['_sourceId'] = _sourceIdFromDoc(doc);
          items.add(m);
        }
      } else if (docSourceType == 'retail_non_food') {
        final id = _sourceIdFromDoc(doc);
        if (id != null) {
          final resp = await _service.getRetailNonFoodItems(id);
          for (final i in (resp?['data'] as List<dynamic>?) ?? []) {
            final m = Map<String, dynamic>.from(i as Map);
            m['_rnfItemId'] = m['id'];
            m['_sourceType'] = 'retail_non_food';
            m['_sourceId'] = id;
            items.add(m);
          }
        }
      }
    }

    for (final c in _priceCtrl) c.dispose();
    for (final c in _qtyCtrl) c.dispose();

    _priceCtrl = items.map((item) {
      final price = (item['po_price'] ?? item['price'] ?? 0).toString().replaceAll('.0', '');
      return TextEditingController(text: price);
    }).toList();
    _qtyCtrl = items.map((item) {
      final qty = (item['qty_received'] ?? item['quantity'] ?? item['qty'] ?? 0).toString().replaceAll('.0', '');
      return TextEditingController(text: qty);
    }).toList();

    setState(() {
      _items = items;
      _itemSelected = List<bool>.filled(items.length, true);
    });
  }

  double get _totalAmount {
    double total = 0;
    for (int i = 0; i < _items.length; i++) {
      if (!_itemSelected[i]) continue;
      final qty = double.tryParse(_qtyCtrl[i].text) ?? 0;
      final price = double.tryParse(_priceCtrl[i].text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  Future<void> _submit() async {
    if (_selectedSources.isEmpty) return;
    final selectedItems = <Map<String, dynamic>>[];
    for (int i = 0; i < _items.length; i++) {
      if (!_itemSelected[i]) continue;
      final item = _items[i];
      final qty = double.tryParse(_qtyCtrl[i].text) ?? 0;
      final price = double.tryParse(_priceCtrl[i].text) ?? 0;
      if (qty <= 0 || price <= 0) continue;

      final Map<String, dynamic> entry = {
        'quantity': qty,
        'price': price,
        'discount_percent': 0,
        'discount_amount': 0,
        'notes': null,
        'source_type': item['_sourceType'],
      };

      if (item['_sourceType'] == 'purchase_order') {
        entry['gr_item_id'] = item['_grItemId'];
        entry['item_id'] = item['item_id'];
        entry['unit_id'] = item['unit_id'];
        entry['item_name'] = item['item_name'];
        entry['unit_name'] = item['unit_name'];
        entry['po_item_id'] = item['po_item_id'];
      } else if (item['_sourceType'] == 'retail_food') {
        entry['retail_food_item_id'] = item['_rfItemId'];
        entry['item_id'] = item['item_id'];
        entry['unit_id'] = item['unit_id'];
        entry['item_name'] = item['item_name'];
        entry['unit_name'] = item['unit_name'];
      } else if (item['_sourceType'] == 'warehouse_retail_food') {
        entry['warehouse_retail_food_item_id'] = item['_wrfItemId'];
        entry['item_id'] = item['item_id'];
        entry['unit_id'] = item['unit_id'];
        entry['item_name'] = item['item_name'];
        entry['unit_name'] = item['unit_name'];
      } else if (item['_sourceType'] == 'retail_non_food') {
        entry['retail_non_food_item_id'] = item['_rnfItemId'];
        entry['item_name'] = item['item_name'];
        entry['unit_name'] = item['unit_name'] ?? '';
      }
      selectedItems.add(entry);
    }

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu item')),
      );
      return;
    }

    setState(() => _submitting = true);

    final payload = <String, dynamic>{
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'notes': _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      'supplier_invoice_number': _invoiceCtrl.text.isNotEmpty ? _invoiceCtrl.text : null,
      'items': selectedItems,
    };

    final firstSource = _selectedSources.first;
    final firstSourceType = _docSourceType(firstSource);
    payload['source_type'] = firstSourceType;
    if (firstSourceType == 'purchase_order') {
      payload['po_id'] = firstSource['po_id'];
      payload['gr_id'] = firstSource['gr_id'];
      payload['sources'] = _selectedSources
          .map((doc) => {
                'source_type': _docSourceType(doc),
                'source_id': _docSourceType(doc) == 'purchase_order' ? doc['po_id'] : _sourceIdFromDoc(doc),
                'po_id': doc['po_id'],
                'gr_id': doc['gr_id'],
              })
          .toList();
    } else {
      final firstSrcId = _sourceIdFromDoc(firstSource);
      payload['source_id'] = firstSrcId;
      payload['sources'] = _selectedSources
          .map((doc) => {
                'source_type': _docSourceType(doc),
                'source_id': _docSourceType(doc) == 'purchase_order' ? doc['po_id'] : _sourceIdFromDoc(doc),
                'po_id': _docSourceType(doc) == 'purchase_order' ? doc['po_id'] : null,
                'gr_id': _docSourceType(doc) == 'purchase_order' ? doc['gr_id'] : null,
              })
          .toList();
    }

    try {
      final result = await _service.createContraBon(payload);
      setState(() => _submitting = false);
      if (!mounted) return;
      if (result?['success'] == true) {
        final number = result?['data']?['number'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contra Bon $number berhasil dibuat')),
        );
        Navigator.pop(context, true);
      } else {
        final msg = result?['message'] ?? 'Gagal membuat Contra Bon';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Contra Bon'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_submitting) return const Center(child: CircularProgressIndicator());
    switch (_step) {
      case 0:
        return _buildTypeStep();
      case 1:
        return _buildSourceStep();
      case 2:
        return _buildItemsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTypeStep() {
    final types = [
      {'key': 'purchase_order', 'label': 'Purchase Order / Good Receive', 'icon': Icons.receipt_long, 'color': const Color(0xFF1565C0)},
      {'key': 'retail_food', 'label': 'Retail Food', 'icon': Icons.restaurant, 'color': const Color(0xFF2E7D32)},
      {'key': 'warehouse_retail_food', 'label': 'Warehouse Retail Food', 'icon': Icons.warehouse, 'color': const Color(0xFFE65100)},
      {'key': 'retail_non_food', 'label': 'Retail Non Food', 'icon': Icons.shopping_bag, 'color': const Color(0xFF6A1B9A)},
      {'key': 'mixed', 'label': 'Campur Source Type (supplier sama)', 'icon': Icons.layers, 'color': const Color(0xFF37474F)},
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilih Jenis Sumber', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Pilih tipe dokumen sumber untuk Contra Bon', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final t = types[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectType(t['key'] as String),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (t['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(t['icon'] as IconData, color: t['color'] as Color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(t['label'] as String,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _sourceTypeLabel {
    switch (_sourceType) {
      case 'purchase_order': return 'PO / Good Receive';
      case 'retail_food': return 'Retail Food';
      case 'warehouse_retail_food': return 'Warehouse Retail Food';
      case 'retail_non_food': return 'Retail Non Food';
      case 'mixed': return 'Semua Source Type';
      default: return '';
    }
  }

  Widget _buildSourceStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari $_sourceTypeLabel...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _loadSources();
                      },
                    )
                  : null,
            ),
            onSubmitted: (v) => _loadSources(search: v),
            onChanged: (v) { if (v.isEmpty) _loadSources(); },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Text(
                '${_selectedSources.length} dokumen dipilih',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedSources.isEmpty ? null : _continueToItemsStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Lanjut'),
              ),
            ],
          ),
        ),
        if (_loadingSources)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_sourceDocs.isEmpty)
          const Expanded(child: Center(child: Text('Tidak ada dokumen tersedia')))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _sourceDocs.length,
              itemBuilder: (context, i) => _buildSourceCard(_sourceDocs[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildSourceCard(Map<String, dynamic> doc) {
    final key = _docKey(doc);
    final selected = _selectedDocKeys.contains(key);
    final sourceType = _docSourceType(doc);
    String title, subtitle, amount;

    if (sourceType == 'purchase_order') {
      title = doc['gr_number'] ?? '';
      subtitle = '${doc['po_number'] ?? ''} · ${doc['supplier_name'] ?? ''}';
      final outlets = (doc['outlet_names'] as List<dynamic>?)?.join(', ') ?? '';
      if (outlets.isNotEmpty) subtitle += '\n$outlets';
      amount = '';
    } else {
      title = doc['retail_number'] ?? '';
      subtitle = '${doc['supplier_name'] ?? ''} · ${doc['outlet_name'] ?? doc['warehouse_outlet_name'] ?? ''}';
      amount = _currency.format(_asDouble(doc['total_amount']));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? const Color(0xFFE3F2FD) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleSourceSelection(doc),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => _toggleSourceSelection(doc),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    if (amount.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(amount, style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                    ],
                    if (_sourceType == 'mixed') ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEFF1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          sourceType.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF455A64)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? const Color(0xFF1565C0) : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 12),
              _buildItemsCard(),
            ],
          ),
        ),
        _buildSubmitBar(),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Header', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceCtrl,
              decoration: const InputDecoration(
                labelText: 'No. Invoice Supplier (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text('${_itemSelected.where((s) => s).length}/${_items.length} dipilih',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const Divider(),
            ..._items.asMap().entries.map((entry) => _buildItemRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int i, Map<String, dynamic> item) {
    final itemName = (item['item_name'] ?? '').toString();
    final unitName = (item['unit_name'] ?? item['unit'] ?? '').toString();

    return Column(
      children: [
        CheckboxListTile(
          value: _itemSelected[i],
          onChanged: (v) => setState(() => _itemSelected[i] = v ?? false),
          contentPadding: EdgeInsets.zero,
          title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: unitName.isNotEmpty ? Text(unitName, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
        ),
        if (_itemSelected[i])
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl[i],
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl[i],
                    decoration: const InputDecoration(
                      labelText: 'Harga',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(_currency.format(_totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1565C0))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Buat Contra Bon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
