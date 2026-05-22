import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/asset_good_receive_service.dart';
import '../../services/native_barcode_scanner.dart';
import '../../models/asset_good_receive_models.dart';
import '../../widgets/app_scaffold.dart';

class AssetGoodReceiveFormScreen extends StatefulWidget {
  const AssetGoodReceiveFormScreen({super.key});

  @override
  State<AssetGoodReceiveFormScreen> createState() =>
      _AssetGoodReceiveFormScreenState();
}

class _AssetGoodReceiveFormScreenState
    extends State<AssetGoodReceiveFormScreen> {
  final AssetGoodReceiveService _service = AssetGoodReceiveService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final TextEditingController _receiveDateController = TextEditingController();
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  AssetPOData? _poData;
  List<_AssetItemForm> _formItems = [];

  int? _ownerOutletId;
  int? _selectedOutletId;
  int? _selectedWarehouseOutletId;

  bool _isLoadingPO = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _receiveDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  Future<void> _openQRScanner() async {
    if (_poData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'PO sudah dimuat. Buat baru jika ingin scan PO lain.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final String? scannedCode = await NativeBarcodeScanner.scanBarcode();
      if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
        setState(() {
          _poNumberController.text = scannedCode;
        });
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
          final data = result['data'] as Map<String, dynamic>;
          final poData = AssetPOData.fromJson(data);

          final itemsWithRemaining =
              poData.items.where((item) => item.qtyRemaining > 0).toList();

          if (itemsWithRemaining.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Semua item di PO ini sudah diterima sepenuhnya'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          setState(() {
            _poData = poData;
            _formItems = itemsWithRemaining
                .map((item) => _AssetItemForm(
                      poItem: item,
                      qtyRemaining: item.qtyRemaining,
                    ))
                .toList();

            final suggestedOwner = int.tryParse(
                data['suggested_owner_outlet_id']?.toString() ?? '');
            if (suggestedOwner != null && suggestedOwner > 0) {
              _ownerOutletId = suggestedOwner;
            } else if (poData.userOutletId != 1) {
              _ownerOutletId = poData.userOutletId;
            }
            if (poData.userOutletId != 1) {
              _selectedOutletId = poData.userOutletId;
            } else if (poData.outlets.isNotEmpty) {
              _selectedOutletId = int.tryParse(
                  poData.outlets.first['id_outlet']?.toString() ?? '');
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'PO berhasil dimuat (${itemsWithRemaining.length} item tersisa)'),
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

  List<Map<String, dynamic>> _getFilteredWarehouseOutlets() {
    if (_poData == null || _selectedOutletId == null) return [];
    return _poData!.warehouseOutlets
        .where((wo) =>
            wo['outlet_id']?.toString() == _selectedOutletId.toString())
        .toList();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_poData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan PO terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_ownerOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih outlet pemilik terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih lokasi outlet terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool anyReceived = false;
    for (var item in _formItems) {
      final qty = double.tryParse(item.qtyReceivedController.text) ?? 0;
      if (qty > 0) {
        anyReceived = true;
        break;
      }
    }

    if (!anyReceived) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal satu item harus memiliki Qty Received > 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final itemsData = _formItems
          .where((item) {
            final qty =
                double.tryParse(item.qtyReceivedController.text) ?? 0;
            return qty > 0;
          })
          .map((item) => {
                'po_item_id': item.poItem.id,
                'item_id': item.poItem.itemId,
                'unit_id': item.poItem.unitId,
                'qty_ordered': item.poItem.quantity,
                'qty_received':
                    double.parse(item.qtyReceivedController.text),
                'price': item.poItem.price,
                if (item.notesController.text.isNotEmpty)
                  'notes': item.notesController.text,
              })
          .toList();

      final result = await _service.createGoodReceive(
        receiveDate: _receiveDateController.text,
        poId: int.tryParse(_poData!.po['id']?.toString() ?? '0') ?? 0,
        ownerOutletId: _ownerOutletId!,
        outletId: _selectedOutletId!,
        warehouseOutletId: _selectedWarehouseOutletId,
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
              content: Text('Asset Good Receive berhasil dibuat'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  result['message'] ?? 'Gagal menyimpan Asset Good Receive'),
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
      title: 'Tambah Asset Good Receive',
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
                    _buildHeaderCard(),
                    const SizedBox(height: 20),
                    _buildPOScanCard(),
                    const SizedBox(height: 20),
                    if (_poData != null) ...[
                      _buildOutletWarehouseCard(),
                      const SizedBox(height: 20),
                      _buildItemsCard(),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
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
          colors: [Colors.teal.shade50, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Asset Good Receive',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan QR Code PO untuk memuat data',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
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
                Icon(Icons.qr_code_scanner,
                    color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Text('Scan PO',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _receiveDateController,
              decoration: InputDecoration(
                labelText: 'Tanggal Terima *',
                prefixIcon: const Icon(Icons.calendar_today),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    _receiveDateController.text =
                        DateFormat('yyyy-MM-dd').format(picked);
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) return 'Tanggal harus diisi';
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                      enabled: _poData == null,
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
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _poData == null && !_isLoadingPO ? _openQRScanner : null,
                      icon: _isLoadingPO
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    if (_poData == null && !_isLoadingPO) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _fetchPO,
                        child: const Text('Cari Manual',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (_poData != null) ...[
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
                        Icon(Icons.check_circle,
                            color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('PO Ditemukan',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(
                        'PO Number', _poData!.po['number']?.toString() ?? '-'),
                    _buildInfoRow('Supplier',
                        _poData!.supplier?['name']?.toString() ?? '-'),
                    _buildInfoRow(
                        'Tanggal PO',
                        _poData!.po['date'] != null
                            ? DateFormat('dd MMM yyyy').format(
                                DateTime.parse(
                                    _poData!.po['date'].toString()))
                            : '-'),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildOutletWarehouseCard() {
    final filteredWarehouses = _getFilteredWarehouseOutlets();
    final isHeadOffice = _poData!.userOutletId == 1;

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
                Icon(Icons.store, color: Colors.teal.shade600, size: 20),
                const SizedBox(width: 8),
                const Text('Pemilik & Lokasi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (isHeadOffice)
              DropdownButtonFormField<int>(
                value: _ownerOutletId,
                decoration: InputDecoration(
                  labelText: 'Outlet Pemilik *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _poData!.outlets.map((outlet) {
                  return DropdownMenuItem<int>(
                    value:
                        int.tryParse(outlet['id_outlet']?.toString() ?? ''),
                    child:
                        Text(outlet['nama_outlet']?.toString() ?? '-'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _ownerOutletId = value),
                validator: (value) =>
                    value == null ? 'Pilih pemilik' : null,
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _poData!.outlets.isNotEmpty
                            ? 'Pemilik: ${_poData!.outlets.firstWhere((o) => int.tryParse(o['id_outlet']?.toString() ?? '') == (_ownerOutletId ?? _poData!.userOutletId), orElse: () => _poData!.outlets.first)['nama_outlet']}'
                            : '-',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            if (isHeadOffice) const SizedBox(height: 12),
            if (isHeadOffice)
              DropdownButtonFormField<int>(
                value: _selectedOutletId,
                decoration: InputDecoration(
                  labelText: 'Lokasi Outlet *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _poData!.outlets.map((outlet) {
                  return DropdownMenuItem<int>(
                    value:
                        int.tryParse(outlet['id_outlet']?.toString() ?? ''),
                    child:
                        Text(outlet['nama_outlet']?.toString() ?? '-'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOutletId = value;
                    _selectedWarehouseOutletId = null;
                  });
                },
                validator: (value) =>
                    value == null ? 'Pilih outlet' : null,
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      _poData!.outlets.isNotEmpty
                          ? _poData!.outlets.first['nama_outlet']
                                  ?.toString() ??
                              '-'
                          : '-',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedWarehouseOutletId,
              decoration: InputDecoration(
                labelText: 'Warehouse Outlet',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('-- Pilih Warehouse Outlet --'),
                ),
                ...filteredWarehouses.map((wo) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(wo['id']?.toString() ?? ''),
                    child: Text(wo['name']?.toString() ?? '-'),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedWarehouseOutletId = value;
                });
              },
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
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          const Text(': ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
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
                Icon(Icons.list_alt,
                    color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Text('Detail Item',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_formItems.length, (index) {
              return _buildItemTile(_formItems[index], index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(_AssetItemForm item, int index) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('#${index + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.poItem.resolvedItemName ?? item.poItem.itemName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                    Text('PO Qty',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,##0.##').format(item.poItem.quantity)} ${item.poItem.unit}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sisa',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,##0.##').format(item.qtyRemaining)} ${item.poItem.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Harga',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp ',
                              decimalDigits: 0)
                          .format(item.poItem.price),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: item.qtyReceivedController,
                  decoration: InputDecoration(
                    labelText: 'Qty Received',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 14),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: item.notesController,
            decoration: InputDecoration(
              labelText: 'Catatan Item',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _AssetItemForm {
  final AssetPOItem poItem;
  final double qtyRemaining;
  final TextEditingController qtyReceivedController;
  final TextEditingController notesController;

  _AssetItemForm({
    required this.poItem,
    required this.qtyRemaining,
  })  : qtyReceivedController =
            TextEditingController(text: qtyRemaining.toString()),
        notesController = TextEditingController();
}
