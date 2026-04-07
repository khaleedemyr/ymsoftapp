import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_food_good_receive_models.dart';
import '../../services/outlet_food_good_receive_service.dart';
import '../../services/native_barcode_scanner.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class OutletFoodGoodReceiveScanScreen extends StatefulWidget {
  const OutletFoodGoodReceiveScanScreen({super.key});

  @override
  State<OutletFoodGoodReceiveScanScreen> createState() => _OutletFoodGoodReceiveScanScreenState();
}

class _OutletFoodGoodReceiveScanScreenState extends State<OutletFoodGoodReceiveScanScreen> {
  final OutletFoodGoodReceiveService _service = OutletFoodGoodReceiveService();
  final TextEditingController _barcodeController = TextEditingController();

  List<Map<String, dynamic>> _doOptions = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  int? _selectedDoId;
  OutletDeliveryOrderDetail? _doDetail;
  List<OutletDeliveryOrderItem> _items = [];

  String? _scanFeedback;
  Color _scanFeedbackColor = Colors.grey.shade700;

  bool _isSpsLoading = false;
  Map<String, dynamic>? _spsItem;

  @override
  void initState() {
    super.initState();
    _loadAvailableDOs();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDOs() async {
    setState(() {
      _isLoading = true;
    });

    final options = await _service.getAvailableDeliveryOrders();

    if (!mounted) return;
    setState(() {
      _doOptions = options;
      _isLoading = false;
    });
  }

  Future<void> _loadDoDetail(int doId) async {
    setState(() {
      _isLoading = true;
      _doDetail = null;
      _items = [];
      _scanFeedback = null;
    });

    final detail = await _service.getDeliveryOrderDetail(doId);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (detail != null) {
        _doDetail = OutletDeliveryOrderDetail.fromJson(detail);
        _items = _doDetail?.items.map((item) {
          item.qtyScan = 0;
          return item;
        }).toList() ?? [];
      }
    });
  }

  Future<void> _openScanner() async {
    try {
      final scanned = await NativeBarcodeScanner.scanBarcode();
      if (scanned != null && scanned.isNotEmpty) {
        _barcodeController.text = scanned;
        _handleBarcode(scanned);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka scanner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleBarcode(String raw) async {
    final input = raw.trim();
    if (input.isEmpty) return;

    String code = input;
    double qty = 1;

    final match = RegExp(r'^(\S+)\s+(\d+(?:\.\d+)?)$').firstMatch(input);
    if (match != null) {
      code = match.group(1) ?? code;
      qty = double.tryParse(match.group(2) ?? '1') ?? 1;
    }

    final item = _items.firstWhere(
      (i) => i.barcodes.contains(code),
      orElse: () => OutletDeliveryOrderItem(
        deliveryOrderItemId: 0,
        itemId: 0,
        itemName: '',
        qtyPackingList: 0,
        qtyScan: 0,
        barcodes: const [],
      ),
    );

    if (item.itemId == 0) {
      _setFeedback('Barcode tidak ditemukan di DO', Colors.red.shade600);
      _barcodeController.clear();
      return;
    }

    final remaining = item.qtyPackingList - item.qtyScan;
    if (remaining <= 0) {
      _setFeedback('Qty scan sudah maksimal untuk ${item.itemName}', Colors.red.shade600);
      _barcodeController.clear();
      return;
    }

    if ((item.unitType ?? '').toLowerCase() == 'kiloan') {
      final qtyInput = await _showQtyInputDialog(remaining);
      if (qtyInput == null) {
        _barcodeController.clear();
        return;
      }
      qty = qtyInput;
    }

    if (qty > remaining) {
      qty = remaining;
    }

    setState(() {
      item.qtyScan += qty;
    });

    final isExact = item.qtyScan.toStringAsFixed(2) == item.qtyPackingList.toStringAsFixed(2);
    final message = isExact
        ? 'Lengkap: ${item.itemName} (${item.qtyScan.toStringAsFixed(2)}/${item.qtyPackingList})'
        : 'Scan: ${item.itemName} (${item.qtyScan.toStringAsFixed(2)}/${item.qtyPackingList})';

    _setFeedback(message, isExact ? Colors.green.shade700 : Colors.orange.shade700);
    _barcodeController.clear();
  }

  Future<double?> _showQtyInputDialog(double remaining) async {
    final controller = TextEditingController(text: remaining.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Input Qty (Kiloan)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Qty'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value == null || value < 0.01) {
                Navigator.pop(context);
                return;
              }
              final normalized = value > remaining ? remaining : value;
              Navigator.pop(context, normalized);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return result;
  }

  void _setFeedback(String message, Color color) {
    setState(() {
      _scanFeedback = message;
      _scanFeedbackColor = color;
    });
  }

  Future<void> _submit() async {
    if (_selectedDoId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery Order belum dipilih')),
      );
      return;
    }

    final confirmed = await _showPreviewDialog();
    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    final payloadItems = _items.map((item) {
      return {
        'item_id': item.itemId,
        'qty': item.qtyPackingList,
        if (item.unitId != null) 'unit_id': item.unitId,
        'received_qty': item.qtyScan,
      };
    }).toList();

    final result = await _service.createOutletGoodReceive(
      deliveryOrderId: _selectedDoId!,
      receiveDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      items: payloadItems,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Good Receive berhasil disimpan'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool?> _showPreviewDialog() async {
    final unscannedItems = _items.where((item) => item.qtyScan == 0).toList();
    final incompleteItems = _items
        .where((item) => item.qtyScan > 0 && item.qtyScan < item.qtyPackingList)
        .toList();

    final totalItems = _items.length;
    final scannedItems = _items.where((item) => item.qtyScan > 0).length;
    final totalQty = _items.fold<double>(0, (sum, item) => sum + item.qtyScan);

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFF8FAFC),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Preview Good Receive',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_doDetail?.info != null)
                        _buildPreviewHeader(),
                      const SizedBox(height: 12),
                      _buildPreviewSummary(scannedItems, totalItems, totalQty),
                      if (unscannedItems.isNotEmpty || incompleteItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildPreviewWarning(unscannedItems.length, incompleteItems.length),
                      ],
                      const SizedBox(height: 16),
                      const Text('Daftar Item', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._items.map((item) => _buildPreviewItem(item)).toList(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewHeader() {
    final info = _doDetail!.info!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nomor DO: ${info.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Outlet: ${info.outletName ?? '-'}'),
          Text('Warehouse: ${info.warehouseOutletName ?? '-'}'),
        ],
      ),
    );
  }

  Widget _buildPreviewSummary(int scannedItems, int totalItems, double totalQty) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item discan', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text('$scannedItems / $totalItems', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total qty', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(totalQty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewWarning(int unscanned, int incomplete) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Peringatan', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (unscanned > 0) Text('Belum scan: $unscanned item'),
          if (incomplete > 0) Text('Qty kurang: $incomplete item'),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(OutletDeliveryOrderItem item) {
    final isDone = item.qtyScan >= item.qtyPackingList && item.qtyPackingList > 0;
    final isPartial = item.qtyScan > 0 && !isDone;
    final status = isDone ? 'OK' : (isPartial ? 'Kurang' : 'Belum');

    Color statusColor = Colors.grey.shade600;
    if (isDone) statusColor = Colors.green.shade700;
    if (isPartial) statusColor = Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('DO: ${item.qtyPackingList} ${item.unit ?? ''}'),
                Text('Scan: ${item.qtyScan}'),
              ],
            ),
          ),
          Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Scan Good Receive',
      body: _isLoading
          ? const AppLoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDoSelector(),
                  const SizedBox(height: 12),
                  if (_doDetail?.info != null) _buildDoInfo(),
                  if (_doDetail?.poInfo != null) ...[
                    const SizedBox(height: 12),
                    _buildPoInfo(),
                  ],
                  const SizedBox(height: 12),
                  if (_items.isNotEmpty) _buildItemsTable(),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildScanInput(),
                    const SizedBox(height: 16),
                    _buildSubmitButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDoSelector() {
    final dropdownItems = _doOptions
        .map<DropdownMenuItem<int>?>((item) {
          final rawId = item['id'];
          final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          if (id == null) return null;

          final date = item['do_date']?.toString();
          final parsedDate = date != null ? DateTime.tryParse(date) : null;
          final formattedDate = parsedDate != null
              ? DateFormat('yyyy-MM-dd').format(parsedDate)
              : (date?.isNotEmpty == true ? date! : '-');

            final outletName = item['outlet_name'] ?? '-';
            final warehouseName = item['warehouse_outlet_name'] ?? '-';
            final label =
              '$formattedDate - $outletName - $warehouseName - ${item['number'] ?? '-'}';
          return DropdownMenuItem<int>(
            value: id,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          );
        })
        .whereType<DropdownMenuItem<int>>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No Delivery Order', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedDoId,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: dropdownItems,
          selectedItemBuilder: (context) {
            return dropdownItems
                .map((item) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (item.child as Text?)?.data ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList();
          },
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedDoId = value;
            });
            _loadDoDetail(value);
          },
        ),
      ],
    );
  }

  Widget _buildDoInfo() {
    final info = _doDetail!.info!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Info Delivery Order', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Nomor DO: ${info.number}'),
            Text('Tanggal DO: ${info.createdAt ?? '-'}'),
            Text('Outlet: ${info.outletName ?? '-'}'),
            Text('Packing Number: ${info.packingNumber ?? '-'}'),
            Text('Floor Order: ${info.floorOrderNumber ?? '-'}'),
            Text('Warehouse Outlet: ${info.warehouseOutletName ?? '-'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPoInfo() {
    final po = _doDetail!.poInfo!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Info Purchase Order', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Nomor PO: ${po.poNumber ?? '-'}'),
            Text('Source Type: ${po.sourceTypeDisplay ?? po.sourceType ?? '-'}'),
            if (po.outletNames.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: po.outletNames
                    .map((name) => Chip(
                          label: Text(name),
                          backgroundColor: Colors.orange.shade100,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daftar Item', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._items.map((item) {
              final isDone = item.qtyScan >= item.qtyPackingList && item.qtyPackingList > 0;
              final isPartial = item.qtyScan > 0 && !isDone;
              final status = isDone ? 'OK' : (isPartial ? 'Kurang' : 'Belum');
                final progress = item.qtyPackingList > 0
                  ? (item.qtyScan / item.qtyPackingList).clamp(0.0, 1.0).toDouble()
                  : 0.0;

              Color chipBg;
              Color chipFg;
              if (isDone) {
                chipBg = Colors.green.shade100;
                chipFg = Colors.green.shade700;
              } else if (isPartial) {
                chipBg = Colors.orange.shade100;
                chipFg = Colors.orange.shade700;
              } else {
                chipBg = Colors.grey.shade200;
                chipFg = Colors.grey.shade700;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                            item.itemName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openSpsModal(item),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('SPS'),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chipFg),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: isDone ? Colors.green.shade600 : Colors.orange.shade600,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQtyMetric('Qty DO', '${item.qtyPackingList} ${item.unit ?? ''}'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQtyMetric('Qty Scan', item.qtyScan.toString()),
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
    );
  }

  Widget _buildQtyMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _openSpsModal(OutletDeliveryOrderItem item) async {
    if (item.itemId == 0) return;

    setState(() {
      _isSpsLoading = true;
      _spsItem = null;
    });

    final result = await _service.getItemDetail(item.itemId);

    if (!mounted) return;
    setState(() {
      _isSpsLoading = false;
      _spsItem = result != null ? (result['item'] as Map<String, dynamic>?) : null;
    });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Item (SPS)'),
        content: _isSpsLoading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : _buildSpsContent(),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Widget _buildSpsContent() {
    if (_spsItem == null) {
      return const Text('Gagal mengambil data item');
    }

    final images = (_spsItem?['images'] as List<dynamic>? ?? [])
        .map((img) => img as Map<String, dynamic>)
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_spsItem?['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Deskripsi:', style: TextStyle(color: Colors.grey.shade700)),
          Text(_spsItem?['description']?.toString().trim().isNotEmpty == true
              ? _spsItem!['description'].toString()
              : '-'),
          const SizedBox(height: 8),
          Text('Spesifikasi:', style: TextStyle(color: Colors.grey.shade700)),
          Text(_spsItem?['specification']?.toString().trim().isNotEmpty == true
              ? _spsItem!['specification'].toString()
              : '-'),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Gambar:', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: images.map((img) {
                final path = img['path']?.toString() ?? '';
                final url = path.startsWith('http')
                    ? path
                    : '${AuthService.storageUrl}/storage/$path';
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Scan Barcode', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _barcodeController,
          decoration: InputDecoration(
            hintText: 'Scan barcode di sini',
            prefixIcon: const Icon(Icons.qr_code),
            suffixIcon: IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _openScanner,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: _handleBarcode,
        ),
        if (_scanFeedback != null) ...[
          const SizedBox(height: 8),
          Text(
            _scanFeedback!,
            style: TextStyle(color: _scanFeedbackColor, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check),
        label: Text(_isSubmitting ? 'Menyimpan...' : 'Submit Good Receive'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
