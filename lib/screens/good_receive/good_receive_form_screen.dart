import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/good_receive_service.dart';
import '../../services/native_barcode_scanner.dart';
import '../../models/good_receive_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class GoodReceiveFormScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;

  const GoodReceiveFormScreen({super.key, this.editData});

  @override
  State<GoodReceiveFormScreen> createState() => _GoodReceiveFormScreenState();
}

class _GoodReceiveFormScreenState extends State<GoodReceiveFormScreen> {
  final GoodReceiveService _service = GoodReceiveService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form fields
  final TextEditingController _receiveDateController = TextEditingController();
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // PO Data
  PurchaseOrderFood? _purchaseOrder;
  List<POFoodItemForm> _formItems = [];

  // Loading states
  bool _isLoadingPO = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _receiveDateController.dispose();
    _poNumberController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    for (var item in _formItems) {
      item.qtyReceivedController.dispose();
      item.notesController.dispose();
    }
    super.dispose();
  }

  void _initializeForm() {
    if (widget.editData != null) {
      // Edit mode - load existing data
      // TODO: Implement edit mode if needed
    } else {
      // Create mode
      _receiveDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  Future<void> _openQRScanner() async {
    if (_purchaseOrder != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PO sudah dimuat. Batal dan buat baru jika ingin scan PO lain.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Scan barcode menggunakan native camera
      final String? scannedCode = await NativeBarcodeScanner.scanBarcode();
      
      if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
        setState(() {
          _poNumberController.text = scannedCode;
        });

        // Auto fetch PO after scan
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          await _fetchPO();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membuka scanner: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchPO() async {
    if (_poNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nomor PO terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingPO = true;
    });

    try {
      final result = await _service.fetchPO(_poNumberController.text);

      if (mounted) {
        setState(() {
          _isLoadingPO = false;
        });

        if (result != null && result['success'] == true) {
          final data = result['data'];
          setState(() {
            _purchaseOrder = PurchaseOrderFood.fromJson(data['po']);
            _formItems = (data['items'] as List)
                .map<POFoodItemForm>((item) => POFoodItemForm(
                      poItem: POFoodItem.fromJson(item),
                      qtyOrdered: (item['qty'] as num?)?.toDouble() ?? 0.0,
                      qtyReceived: (item['qty'] as num?)?.toDouble() ?? 0.0,
                    ))
                .toList();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PO berhasil dimuat'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['message'] ?? 'Gagal memuat PO'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPO = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_purchaseOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan PO terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all items have qty_received
    bool allItemsValid = true;
    for (var item in _formItems) {
      final qtyReceived = double.tryParse(item.qtyReceivedController.text);
      if (qtyReceived == null || qtyReceived <= 0) {
        allItemsValid = false;
        break;
      }
    }

    if (!allItemsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua item harus memiliki Qty Received > 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final itemsData = _formItems.map((item) {
        return {
          'po_item_id': item.poItem.id,
          'item_id': item.poItem.itemId,
          'unit_id': item.poItem.unitId,
          'qty_ordered': item.qtyOrdered,
          'qty_received': double.parse(item.qtyReceivedController.text),
          if (item.notesController.text.isNotEmpty) 'notes': item.notesController.text,
        };
      }).toList();

      Map<String, dynamic> result;
      result = await _service.createGoodReceive(
        receiveDate: _receiveDateController.text,
        poId: _purchaseOrder!.id,
        supplierId: _purchaseOrder!.supplierId,
        notes: _notesController.text,
        items: itemsData,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Good Receive berhasil dibuat'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menyimpan Good Receive'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tambah Good Receive',
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    _buildHeaderCard(),
                    const SizedBox(height: 20),

                    // PO Scan Card
                    _buildPOScanCard(),
                    const SizedBox(height: 20),

                    // Items Card (shown after PO is loaded)
                    if (_purchaseOrder != null) ...[
                      _buildItemsCard(),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
            // Submit buttons
            _buildSubmitButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Good Receive',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan PO untuk memuat data',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOScanCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Text('Scan PO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _receiveDateController,
              decoration: InputDecoration(
                labelText: 'Tanggal Terima *',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _receiveDateController.text.isNotEmpty
                      ? DateTime.parse(_receiveDateController.text)
                      : DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _receiveDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Tanggal harus diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _poNumberController,
                    decoration: InputDecoration(
                      labelText: 'Nomor PO *',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                      enabled: _purchaseOrder == null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nomor PO harus diisi';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _purchaseOrder == null && !_isLoadingPO ? _openQRScanner : null,
                  icon: _isLoadingPO
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan PO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ],
            ),
            if (_purchaseOrder != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('PO Ditemukan', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('PO Number', _purchaseOrder!.number),
                    _buildInfoRow('Supplier', _purchaseOrder!.supplierName),
                    _buildInfoRow('Order Date', DateFormat('dd MMM yyyy').format(DateTime.parse(_purchaseOrder!.orderDate))),
                    if (_purchaseOrder!.deliveryDate != null)
                      _buildInfoRow('Delivery Date', DateFormat('dd MMM yyyy').format(DateTime.parse(_purchaseOrder!.deliveryDate!))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Catatan',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          const Text(': ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_formItems.length, (index) {
              final item = _formItems[index];
              return _buildItemTile(item, index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(POFoodItemForm item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('#${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.poItem.itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qty Ordered', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('${NumberFormat('#,##0.##').format(item.qtyOrdered)} ${item.poItem.unitName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item.qtyReceivedController,
                  decoration: InputDecoration(
                    labelText: 'Qty Received *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Wajib diisi';
                    }
                    final qty = double.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return 'Harus > 0';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          if (item.poItem.warehouseDivisionName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(item.poItem.warehouseDivisionName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: item.notesController,
            decoration: InputDecoration(
              labelText: 'Catatan Item',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class POFoodItemForm {
  final POFoodItem poItem;
  final double qtyOrdered;
  final double qtyReceived;
  final TextEditingController qtyReceivedController;
  final TextEditingController notesController;

  POFoodItemForm({
    required this.poItem,
    required this.qtyOrdered,
    required this.qtyReceived,
  })  : qtyReceivedController = TextEditingController(text: qtyReceived.toString()),
        notesController = TextEditingController();

  void dispose() {
    qtyReceivedController.dispose();
    notesController.dispose();
  }
}
