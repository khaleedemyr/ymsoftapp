import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/delivery_order_service.dart';
import '../../services/native_barcode_scanner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

/// Form buat Delivery Order — alur selaras web DeliveryOrder/Form.vue.
class DeliveryOrderCreateScreen extends StatefulWidget {
  const DeliveryOrderCreateScreen({super.key});

  @override
  State<DeliveryOrderCreateScreen> createState() => _DeliveryOrderCreateScreenState();
}

class _DeliveryOrderCreateScreenState extends State<DeliveryOrderCreateScreen> {
  final DeliveryOrderService _service = DeliveryOrderService();

  static const Color _accent = Color(0xFF6366F1);
  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _serialFocus = FocusNode();

  bool _loadingMeta = true;
  String? _metaError;
  List<Map<String, dynamic>> _packingLists = [];
  List<Map<String, dynamic>> _roSupplierGRs = [];
  List<Map<String, dynamic>> _warehouseDivisions = [];

  String _divisionId = '';
  String _selectedPackingListId = '';
  bool _loadingItems = false;
  final List<Map<String, dynamic>> _items = [];

  String _scanMode = 'barcode';
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _serialCtrl = TextEditingController();
  String _scanFeedback = '';
  Color _scanFeedbackColor = Colors.transparent;

  /// item_id → daftar serial yang sudah di-scan (sama struktur ringkas web)
  final Map<int, List<Map<String, dynamic>>> _scannedSerials = {};

  bool _submitting = false;

  static const List<String> _reasonOptions = [
    'Stok kurang',
    'Barang rusak',
    'Permintaan berubah',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _barcodeFocus.dispose();
    _serialFocus.dispose();
    _barcodeCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _metaError = null;
    });
    final res = await _service.getCreateData();
    if (!mounted) return;
    if (res == null || res['success'] != true) {
      setState(() {
        _loadingMeta = false;
        _metaError = res?['message']?.toString() ?? 'Gagal memuat data form';
      });
      return;
    }
    setState(() {
      _packingLists = _asMapList(res['packing_lists']);
      _roSupplierGRs = _asMapList(res['ro_supplier_grs']);
      _warehouseDivisions = _asMapList(res['warehouse_divisions']);
      _loadingMeta = false;
      _metaError = null;
    });
  }

  List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  bool get _isROSupplierGR => _selectedPackingListId.startsWith('gr_');

  List<Map<String, dynamic>> get _filteredPackingLists {
    if (_divisionId.isEmpty) return [];
    return _packingLists.where((pl) => pl['warehouse_division_id']?.toString() == _divisionId).toList();
  }

  List<Map<String, dynamic>> get _filteredROSupplierGRs {
    if (_divisionId.isEmpty) return [];
    return _roSupplierGRs.where((gr) => gr['warehouse_division_id']?.toString() == _divisionId).toList();
  }

  Map<String, dynamic>? get _selectedSource {
    final id = _selectedPackingListId;
    if (id.isEmpty) return null;
    if (_isROSupplierGR) {
      final grId = id.substring(3);
      for (final gr in _roSupplierGRs) {
        if (gr['gr_id']?.toString() == grId) return gr;
      }
      return null;
    }
    final plId = int.tryParse(id);
    if (plId == null) return null;
    for (final pl in _packingLists) {
      if (pl['id']?.toString() == plId.toString()) return pl;
    }
    return null;
  }

  bool get _readyToSubmit => _items.isNotEmpty && _items.any((i) => _num(i['qty_scan']) > 0);

  double _num(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString()) ?? 0;
  }

  double _stockAvailable(Map<String, dynamic> item) {
    final stock = item['stock'];
    final units = item['units'];
    if (stock is! Map || units is! Map) return 0;
    final unit = item['unit']?.toString() ?? '';
    final su = units['small_unit']?.toString();
    final mu = units['medium_unit']?.toString();
    final lu = units['large_unit']?.toString();
    final sc = _num(item['small_conversion_qty']) <= 0 ? 1.0 : _num(item['small_conversion_qty']);
    final mc = _num(item['medium_conversion_qty']) <= 0 ? 1.0 : _num(item['medium_conversion_qty']);

    double small = _num(stock['small']);
    double medium = _num(stock['medium']);
    double large = _num(stock['large']);

    if (unit == su) return small;
    if (unit == mu) return medium;
    if (unit == lu) return large;

    final totalSmall = small + (medium * sc) + (large * sc * mc);
    if (unit == su) return totalSmall;
    if (unit == mu) return totalSmall / sc;
    if (unit == lu) return totalSmall / (sc * mc);
    return [small, medium, large].reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic>? _findItemByBarcode(String code) {
    for (final i in _items) {
      final barcodes = i['barcodes'];
      if (barcodes is List && barcodes.any((b) => b?.toString() == code)) return i;
      if (i['barcode']?.toString() == code) return i;
    }
    return null;
  }

  void _setFeedback(String msg, Color color) {
    setState(() {
      _scanFeedback = msg;
      _scanFeedbackColor = color;
    });
  }

  void _onDivisionChanged(String? v) {
    setState(() {
      _divisionId = v ?? '';
      _selectedPackingListId = '';
      _items.clear();
      _scannedSerials.clear();
      _barcodeCtrl.clear();
      _serialCtrl.clear();
      _scanFeedback = '';
    });
  }

  Future<void> _onPackingListChanged(String? v) async {
    setState(() {
      _selectedPackingListId = v ?? '';
      _items.clear();
      _scannedSerials.clear();
      _scanFeedback = '';
    });
    if (v == null || v.isEmpty) return;

    setState(() => _loadingItems = true);
    final res = await _service.getPackingListItems(v);
    if (!mounted) return;
    setState(() => _loadingItems = false);

    if (res == null) {
      _setFeedback('Gagal memuat item', Colors.red);
      return;
    }
    final raw = res['items'];
    if (raw is! List) {
      _setFeedback('Format response tidak valid', Colors.red);
      return;
    }
    setState(() {
      _items.clear();
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          m['qty_scan'] = 0.0;
          _items.add(m);
        }
      }
      _scanFeedback = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scanMode == 'barcode') {
        _barcodeFocus.requestFocus();
      } else {
        _serialFocus.requestFocus();
      }
    });
  }

  Future<void> _openCameraBarcode() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan kamera tersedia di aplikasi Android/iOS. Di web gunakan input manual / scanner HID.')),
      );
      return;
    }
    try {
      final scanned = await NativeBarcodeScanner.scanBarcode();
      if (!mounted) return;
      if (scanned != null && scanned.isNotEmpty) {
        _barcodeCtrl.text = scanned;
        await _onScanBarcode(scanned);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka scanner: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openCameraSerial() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan kamera tersedia di aplikasi Android/iOS. Di web gunakan input manual / scanner HID.')),
      );
      return;
    }
    try {
      final scanned = await NativeBarcodeScanner.scanBarcode();
      if (!mounted) return;
      if (scanned != null && scanned.isNotEmpty) {
        _serialCtrl.text = scanned;
        await _onScanSerial(scanned);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka scanner: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onScanBarcode([String? raw]) async {
    final input = (raw ?? _barcodeCtrl.text).trim();
    if (input.isEmpty) return;
    String code = input;
    double? qty;
    final match = RegExp(r'^(\S+)\s+(\d+(?:\.\d+)?)$').firstMatch(input);
    if (match != null) {
      code = match.group(1)!;
      qty = double.tryParse(match.group(2)!);
    }

    final item = _findItemByBarcode(code);
    if (item == null) {
      _setFeedback('Barcode tidak ditemukan di Packing List!', Colors.red);
      _barcodeCtrl.clear();
      return;
    }

    final maxQty = _num(item['qty']);
    final currentScan = _num(item['qty_scan']);
    final stock = _stockAvailable(item);

    if (stock <= 0) {
      _setFeedback('Stok tidak tersedia', Colors.red);
      _barcodeCtrl.clear();
      return;
    }

    final addQty = qty ?? 0.0;
    if (qty != null) {
      if (currentScan + addQty > maxQty) {
        _setFeedback('Qty scan tidak boleh lebih dari $maxQty (sisa: ${maxQty - currentScan})', Colors.red);
        _barcodeCtrl.clear();
        return;
      }
      if (currentScan + addQty > stock) {
        _setFeedback('Qty scan tidak boleh melebihi stock ($stock)', Colors.red);
        _barcodeCtrl.clear();
        return;
      }
      setState(() {
        item['qty_scan'] = currentScan + addQty;
      });
      _setFeedback('Berhasil scan $addQty ${item['unit']}', Colors.green.shade700);
      _barcodeCtrl.clear();
      return;
    }

    if (currentScan + 0.01 > stock) {
      _setFeedback('Qty scan tidak boleh melebihi stock ($stock)', Colors.red);
      _barcodeCtrl.clear();
      return;
    }

    _barcodeCtrl.clear();
    final remaining = maxQty - currentScan;
    final initialQty = remaining > 0 ? remaining : 0.01;
    if (!mounted) return;
    final ctrl = TextEditingController(text: _trimDecimal(initialQty));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input Qty Scan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: ${item['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Qty Packing List: $maxQty'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qty scan', border: OutlineInputBorder()),
              autofocus: true,
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final inputQty = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
    ctrl.dispose();
    if (inputQty <= 0) {
      _setFeedback('Qty tidak valid', Colors.red);
      return;
    }

    if (stock < currentScan + inputQty) {
      _setFeedback('Qty scan tidak boleh melebihi stock (sisa: ${stock - currentScan})', Colors.red);
      return;
    }
    if (currentScan + inputQty > maxQty) {
      _setFeedback('Qty scan tidak boleh lebih dari $maxQty (sisa: ${maxQty - currentScan})', Colors.red);
      return;
    }

    if (inputQty < maxQty - 1e-9) {
      if (!mounted) return;
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Pilih Alasan Qty Kurang'),
          children: [
            ..._reasonOptions.map(
              (r) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, r),
                child: Text(r, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
          ],
        ),
      );
      if (reason == null || !mounted) return;
      setState(() {
        item['qty_scan'] = inputQty;
      });
      _setFeedback('${item['name']} ($inputQty/$maxQty) - $reason', Colors.orange.shade800);
      return;
    }

    setState(() {
      item['qty_scan'] = inputQty;
    });
    _setFeedback('${item['name']} ($inputQty/$maxQty)', Colors.green.shade700);
  }

  String _trimDecimal(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-9) return v.round().toString();
    return v.toString();
  }

  Future<void> _onScanSerial([String? raw]) async {
    final input = (raw ?? _serialCtrl.text).trim();
    if (input.isEmpty) return;
    if (_selectedPackingListId.isEmpty) return;
    for (final list in _scannedSerials.values) {
      for (final s in list) {
        if (s['serial_number']?.toString() == input) {
          _setFeedback('Nomor seri sudah di-scan sebelumnya!', Colors.red);
          _serialCtrl.clear();
          return;
        }
      }
    }

    final pl = _selectedSource;
    final warehouseId = int.tryParse(pl?['warehouse_id']?.toString() ?? '') ?? 1;
    final itemIds = _items.map((i) => int.tryParse((i['item_id'] ?? i['id'])?.toString() ?? '') ?? 0).where((id) => id > 0).toList();

    final res = await _service.validateSerial(
      serialNumber: input,
      packingListId: _selectedPackingListId,
      warehouseId: warehouseId,
      itemIds: itemIds,
    );
    if (!mounted) return;
    _serialCtrl.clear();

    if (res['valid'] != true) {
      _setFeedback(res['message']?.toString() ?? 'Serial tidak valid', Colors.red);
      return;
    }

    final serial = res['serial'];
    if (serial is! Map) {
      _setFeedback('Response serial tidak valid', Colors.red);
      return;
    }
    final sm = Map<String, dynamic>.from(serial);
    final itemId = int.tryParse(sm['item_id']?.toString() ?? '') ?? 0;
    Map<String, dynamic>? matched;
    for (final i in _items) {
      final iid = int.tryParse((i['item_id'] ?? i['id'])?.toString() ?? '') ?? 0;
      if (iid == itemId) {
        matched = i;
        break;
      }
    }
    if (matched == null) {
      _setFeedback('Item tidak ditemukan di Packing List!', Colors.red);
      return;
    }
    final hit = matched;

    final effectiveQty = _num(sm['effective_qty']) <= 0 ? 1.0 : _num(sm['effective_qty']);
    _scannedSerials.putIfAbsent(itemId, () => []);
    _scannedSerials[itemId]!.add({
      'serial_number': input,
      'effective_qty': effectiveQty,
      'repack_unit_name': sm['repack_unit_name'],
      'repack_qty': sm['repack_qty'],
      'unit_name': sm['unit_name'],
    });
    setState(() {
      hit['qty_scan'] = _num(hit['qty_scan']) + effectiveQty;
      final conv = sm['repack_unit_name'] != null
          ? ' (1 ${sm['repack_unit_name']} = ${_fmtQty4(sm['repack_qty'])} ${sm['unit_name']})'
          : '';
      _setFeedback('${sm['item_name'] ?? ''} - $input$conv (+$effectiveQty)', Colors.green.shade700);
    });
  }

  String _fmtQty4(dynamic v) {
    if (v == null) return '';
    final n = double.tryParse(v.toString());
    if (n == null) return v.toString();
    return n.toString();
  }

  void _removeSerial(Map<String, dynamic> item, int idx) {
    final itemId = int.tryParse((item['item_id'] ?? item['id'])?.toString() ?? '') ?? 0;
    final list = _scannedSerials[itemId];
    if (list == null || idx < 0 || idx >= list.length) return;
    final removed = list.removeAt(idx);
    final eq = _num(removed['effective_qty']) <= 0 ? 1.0 : _num(removed['effective_qty']);
    setState(() {
      item['qty_scan'] = (_num(item['qty_scan']) - eq).clamp(0.0, 1e18);
      if (list.isEmpty) _scannedSerials.remove(itemId);
    });
  }

  List<Map<String, dynamic>> _buildItemsPayload() {
    return _items.map((item) {
      dynamic barcodeField = item['barcode'];
      List<dynamic> barcodeList;
      if (barcodeField is List && barcodeField.isNotEmpty) {
        barcodeList = List<dynamic>.from(barcodeField);
      } else if (barcodeField != null && barcodeField.toString().isNotEmpty) {
        barcodeList = [barcodeField];
      } else {
        final bc = item['barcodes'];
        barcodeList = bc is List ? List<dynamic>.from(bc) : <dynamic>[];
      }
      return {
        'id': item['id'],
        'barcode': barcodeList,
        'qty': item['qty'],
        'qty_scan': item['qty_scan'],
        'unit': item['unit'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildScannedSerialsPayload() {
    if (_scanMode != 'serial') return [];
    final out = <Map<String, dynamic>>[];
    _scannedSerials.forEach((itemId, serials) {
      if (serials.isEmpty) return;
      out.add({
        'item_id': itemId,
        'serial_numbers': serials.map((s) => s['serial_number']?.toString() ?? '').where((s) => s.isNotEmpty).toList(),
      });
    });
    return out;
  }

  Future<void> _confirmSubmit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Submit'),
        content: const Text('Yakin ingin submit Delivery Order ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    await _submitDO();
  }

  Future<void> _submitDO() async {
    if (_selectedPackingListId.isEmpty) return;
    setState(() => _submitting = true);
    final pl = _selectedSource;
    final outletId = int.tryParse(pl?['outlet_id']?.toString() ?? '');
    final warehouseOutletId = int.tryParse(pl?['warehouse_outlet_id']?.toString() ?? '');

    final res = await _service.store(
      packingListId: _selectedPackingListId,
      scanMode: _scanMode,
      outletId: outletId,
      warehouseOutletId: warehouseOutletId,
      items: _buildItemsPayload(),
      scannedSerials: _buildScannedSerialsPayload(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sukses'),
          content: Text(res['message']?.toString() ?? 'Delivery Order berhasil disimpan!'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  String _fmtDateShort(dynamic v) {
    if (v == null) return '-';
    final dt = DateTime.tryParse(v.toString());
    if (dt != null) return DateFormat('d/M/y').format(dt);
    return v.toString();
  }

  Color _statusColor(Map<String, dynamic> item) {
    final q = _num(item['qty']);
    final qs = _num(item['qty_scan']);
    if ((qs - q).abs() < 1e-6) return Colors.green.shade50;
    if (qs > q) return Colors.red.shade50;
    if (qs > 0) return Colors.amber.shade50;
    return Colors.transparent;
  }

  String _statusLabel(Map<String, dynamic> item) {
    final q = _num(item['qty']);
    final qs = _num(item['qty_scan']);
    if (qs == 0) return 'Belum Scan';
    if ((qs - q).abs() < 1e-6) return 'OK';
    if (qs > q) return 'Lebih';
    return 'Kurang';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) {
      return AppScaffold(
        title: 'Delivery Order (Scan)',
        showDrawer: false,
        body: Center(child: AppLoadingIndicator(size: 32, color: _accent)),
      );
    }
    if (_metaError != null) {
      return AppScaffold(
        title: 'Delivery Order (Scan)',
        showDrawer: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_metaError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadMeta, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
      );
    }

    final src = _selectedSource;

    return AppScaffold(
      title: 'Delivery Order (Scan Barang)',
      showDrawer: false,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Warehouse Division', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _divisionId,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Semua Warehouse Division')),
                        ..._warehouseDivisions.map((d) {
                          final id = d['id']?.toString() ?? '';
                          return DropdownMenuItem(value: id, child: Text(d['name']?.toString() ?? id));
                        }),
                      ],
                      onChanged: (v) => _onDivisionChanged(v),
                    ),
                    const SizedBox(height: 14),
                    const Text('Pilih Sumber', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 8),
                    if (_divisionId.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Pilih Warehouse Division dulu',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedPackingListId.isEmpty ? '' : _selectedPackingListId,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Pilih Packing List atau RO Supplier GR...')),
                          ..._filteredPackingLists.map((pl) {
                            final id = pl['id']?.toString() ?? '';
                            final label =
                                '${_fmtDateShort(pl['created_at'])} - ${pl['nama_outlet'] ?? '-'} - ${pl['division_name'] ?? '-'} - ${pl['packing_number'] ?? ''}';
                            return DropdownMenuItem(value: id, child: Text('PL: $label', overflow: TextOverflow.ellipsis));
                          }),
                          ..._filteredROSupplierGRs.map((gr) {
                            final id = 'gr_${gr['gr_id']}';
                            final label =
                                '${_fmtDateShort(gr['created_at'])} - ${gr['nama_outlet'] ?? '-'} - ${gr['division_name'] ?? '-'} - ${gr['packing_number'] ?? ''} (${gr['supplier_name'] ?? ''})';
                            return DropdownMenuItem(value: id, child: Text('GR: $label', overflow: TextOverflow.ellipsis));
                          }),
                        ],
                        onChanged: _onPackingListChanged,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (src != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _accent.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isROSupplierGR ? 'Info RO Supplier GR' : 'Info Packing List',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _accent, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text('Outlet: ${src['nama_outlet'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text('WH Outlet: ${src['warehouse_outlet_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text('Divisi: ${src['division_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text('Gudang: ${src['warehouse_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text('Floor Order: ${_fmtDateShort(src['floor_order_date'])} · ${src['floor_order_number'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      if (_isROSupplierGR) ...[
                        Text('Supplier: ${src['supplier_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                        Text('GR: ${_fmtDateShort(src['created_at'])} · ${src['packing_number'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                        Text('User GR: ${src['creator_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      ] else ...[
                        Text('Packing: ${_fmtDateShort(src['created_at'])} · ${src['packing_number'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                        Text('User: ${src['creator_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_loadingItems)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    AppLoadingIndicator(size: 36, color: _accent),
                    const SizedBox(height: 8),
                    const Text('Memuat item…'),
                  ],
                ),
              ),
            ),
          if (_items.isNotEmpty && !_loadingItems) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text('Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    Text('(${_items.length})', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildItemCard(_items[index]),
                  ),
                  childCount: _items.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _scanMode = 'barcode');
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _barcodeFocus.requestFocus();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: _scanMode == 'barcode' ? _accent : null,
                          foregroundColor: _scanMode == 'barcode' ? Colors.white : _accent,
                          side: BorderSide(color: _scanMode == 'barcode' ? _accent : const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('Barcode'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _scanMode = 'serial');
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _serialFocus.requestFocus();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: _scanMode == 'serial' ? Colors.deepPurple : null,
                          foregroundColor: _scanMode == 'serial' ? Colors.white : Colors.deepPurple,
                          side: BorderSide(color: _scanMode == 'serial' ? Colors.deepPurple : const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('Nomor Seri'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scanMode == 'barcode' ? 'Scan barcode' : 'Scan nomor seri',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _scanMode == 'barcode' ? _accent : Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scanMode == 'barcode'
                            ? 'Gunakan scanner bluetooth (fokus di kolom) atau tombol kamera.'
                            : 'Scanner atau kamera — satu nomor per entri.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      if (_scanMode == 'barcode')
                        TextField(
                          controller: _barcodeCtrl,
                          focusNode: _barcodeFocus,
                          decoration: InputDecoration(
                            hintText: 'Tap di sini lalu scan — atau "KODE 2.5" untuk qty',
                            prefixIcon: const Icon(Icons.qr_code_rounded, color: _accent),
                            suffixIcon: IconButton(
                              tooltip: 'Scan pakai kamera',
                              icon: const Icon(Icons.camera_alt_rounded, color: _accent),
                              onPressed: _openCameraBarcode,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _onScanBarcode(),
                        )
                      else
                        TextField(
                          controller: _serialCtrl,
                          focusNode: _serialFocus,
                          decoration: InputDecoration(
                            hintText: 'Tap di sini lalu scan serial',
                            prefixIcon: const Icon(Icons.tag_rounded, color: Colors.deepPurple),
                            suffixIcon: IconButton(
                              tooltip: 'Scan pakai kamera',
                              icon: const Icon(Icons.camera_alt_rounded, color: Colors.deepPurple),
                              onPressed: _openCameraSerial,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _onScanSerial(),
                        ),
                      if (_scanFeedback.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _scanFeedback,
                            key: ValueKey<String>(_scanFeedback),
                            style: TextStyle(fontWeight: FontWeight.w600, color: _scanFeedbackColor, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_scanMode == 'serial' && _scannedSerials.values.any((l) => l.isNotEmpty))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Serial tersimpan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._items.map((item) {
                        final itemId = int.tryParse((item['item_id'] ?? item['id'])?.toString() ?? '') ?? 0;
                        final list = _scannedSerials[itemId];
                        if (list == null || list.isEmpty) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.deepPurple.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['name']} (${list.length})', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple.shade900, fontSize: 13)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (var i = 0; i < list.length; i++)
                                    InputChip(
                                      label: Text(
                                        '${list[i]['serial_number']}${list[i]['repack_unit_name'] != null ? ' (+${list[i]['effective_qty']})' : ''}',
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                      onDeleted: () => _removeSerial(item, i),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            child: FilledButton.icon(
              onPressed: (!_readyToSubmit || _submitting) ? null : _confirmSubmit,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Menyimpan…' : 'Submit Delivery Order'),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Material(
      color: _statusColor(item),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (_scanMode == 'barcode') {
            _barcodeFocus.requestFocus();
          } else {
            _serialFocus.requestFocus();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (item['units'] is Map && item['stock'] is Map) ...[
                const SizedBox(height: 4),
                _stockLine(item, 'small'),
                _stockLine(item, 'medium'),
                _stockLine(item, 'large'),
              ] else
                const Text('Stok: Tidak tersedia', style: TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Qty PL: ${item['qty']}', style: const TextStyle(fontSize: 13)),
                  Text('Unit: ${item['unit'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                  Text('Qty scan: ${item['qty_scan']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(_statusLabel(item), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockLine(Map<String, dynamic> item, String tier) {
    final units = item['units'] as Map;
    final stock = item['stock'] as Map;
    final uKey = '${tier}_unit';
    final sKey = tier;
    final un = units[uKey]?.toString();
    if (un == null || un.isEmpty) return const SizedBox.shrink();
    final q = _num(stock[sKey]);
    final red = q == 0;
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(text: '${tier[0].toUpperCase()}${tier.substring(1)}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(
            text: '$q',
            style: TextStyle(color: red ? Colors.red : null, fontWeight: red ? FontWeight.bold : null),
          ),
          TextSpan(text: ' $un'),
        ],
      ),
    );
  }
}
