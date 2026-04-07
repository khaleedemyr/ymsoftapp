import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_supplier_good_receive_models.dart';
import '../../services/outlet_supplier_good_receive_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class OutletSupplierGoodReceiveCreateScreen extends StatefulWidget {
  const OutletSupplierGoodReceiveCreateScreen({super.key});

  @override
  State<OutletSupplierGoodReceiveCreateScreen> createState() => _OutletSupplierGoodReceiveCreateScreenState();
}

class _OutletSupplierGoodReceiveCreateScreenState extends State<OutletSupplierGoodReceiveCreateScreen> {
  final OutletSupplierGoodReceiveService _service = OutletSupplierGoodReceiveService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<OutletSupplierRoOption> _roOptions = [];
  List<OutletSupplierDoOption> _doOptions = [];
  List<OutletSupplierInputItem> _items = [];
  List<TextEditingController> _qtyControllers = [];

  OutletSupplierRoOption? _selectedRo;
  OutletSupplierDoOption? _selectedDo;

  Map<String, dynamic>? _headerInfo;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _sourceType = 'do';

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadOptions();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    _disposeQtyControllers();
    super.dispose();
  }

  void _disposeQtyControllers() {
    for (final controller in _qtyControllers) {
      controller.dispose();
    }
    _qtyControllers = [];
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
    });

    final roListRaw = await _service.getAvailableROs();
    final doListRaw = await _service.getAvailableDOs();

    if (!mounted) return;

    setState(() {
      _roOptions = roListRaw.map((item) => OutletSupplierRoOption.fromJson(item)).toList();
      _doOptions = doListRaw.map((item) => OutletSupplierDoOption.fromJson(item)).toList();
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? DateTime.parse(_dateController.text)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _loadRoDetail(int roSupplierId) async {
    setState(() {
      _isLoading = true;
      _items = [];
      _headerInfo = null;
    });

    final result = await _service.getRoDetail(roSupplierId);

    if (!mounted) return;

    if (result != null) {
      final detail = OutletSupplierRoDetail.fromJson(result);
      _resetItems(detail.items);
      setState(() {
        _headerInfo = detail.header;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDoDetail(int deliveryOrderId) async {
    setState(() {
      _isLoading = true;
      _items = [];
      _headerInfo = null;
    });

    final result = await _service.getDoDetail(deliveryOrderId);

    if (!mounted) return;

    if (result != null) {
      final detail = OutletSupplierDoDetail.fromJson(result);
      _resetItems(detail.items.map((item) {
        return OutletSupplierInputItem(
          roItemId: null,
          itemId: item.itemId,
          itemName: item.itemName,
          qtyOrdered: item.qtyOrdered,
          qtyReceived: 0,
          unitId: item.unitId,
          unitName: item.unitName,
          price: item.price,
        );
      }).toList());
      setState(() {
        _headerInfo = detail.header;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetItems(List<OutletSupplierInputItem> items) {
    _disposeQtyControllers();
    _items = items.map((item) {
      return OutletSupplierInputItem(
        roItemId: item.roItemId,
        itemId: item.itemId,
        itemName: item.itemName,
        qtyOrdered: item.qtyOrdered,
        qtyReceived: item.qtyReceived,
        unitId: item.unitId,
        unitName: item.unitName,
        price: item.price,
      );
    }).toList();
    _qtyControllers = _items
        .map((item) => TextEditingController(text: _formatQty(item.qtyReceived)))
        .toList();
  }

  bool _validateItems() {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final raw = _qtyControllers[i].text.trim();

      if (raw.isEmpty) {
        _showError('Qty terima wajib diisi: ${item.itemName}');
        return false;
      }

      if (_hasTooManyDecimals(raw)) {
        _showError('Maksimal 2 angka di belakang koma: ${item.itemName}');
        return false;
      }

      if (item.qtyReceived < 0) {
        _showError('Qty terima tidak boleh negatif: ${item.itemName}');
        return false;
      }
      if (item.qtyReceived > item.qtyOrdered) {
        _showError('Qty terima tidak boleh melebihi qty order: ${item.itemName}');
        return false;
      }
    }
    return true;
  }

  bool _hasTooManyDecimals(String value) {
    final normalized = value.replaceAll(',', '.');
    final parts = normalized.split('.');
    if (parts.length < 2) return false;
    return parts.last.length > 2;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool> _showPreviewDialog() async {
    final header = _headerInfo ?? {};
    final isDo = _sourceType == 'do';
    final title = isDo ? 'Preview GR dari DO' : 'Preview GR dari RO Supplier';
    final sourceNumber = isDo
        ? (header['do_number']?.toString() ?? '-')
        : (header['ro_number']?.toString() ?? '-');
    final outletName = header['outlet_name']?.toString() ?? '-';
    final supplierName = header['supplier_name']?.toString() ?? '-';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fact_check, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreviewCard(
                        title: 'Informasi',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPreviewRow(isDo ? 'Nomor DO' : 'Nomor RO', sourceNumber),
                            _buildPreviewRow('Tanggal Terima', _dateController.text),
                            _buildPreviewRow('Outlet', outletName),
                            if (!isDo) _buildPreviewRow('Supplier', supplierName),
                            if (_notesController.text.trim().isNotEmpty)
                              _buildPreviewRow('Catatan', _notesController.text.trim()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewCard(
                        title: 'Daftar Item',
                        child: _items.isEmpty
                            ? const Text('Tidak ada item')
                            : Column(
                                children: _items
                                    .map((item) => _buildPreviewItemCard(item))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return confirmed == true;
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItemCard(OutletSupplierInputItem item) {
    final unitText = (item.unitName ?? '').trim();
    final unitDisplay = unitText.isEmpty ? '' : ' $unitText';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildPreviewQtyChip('Qty Order', item.qtyOrdered, unitDisplay)),
              const SizedBox(width: 10),
              Expanded(child: _buildPreviewQtyChip('Qty Terima', item.qtyReceived, unitDisplay)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewQtyChip(String label, double value, String unitDisplay) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '${_formatQty(value)}$unitDisplay',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      _showError('Item belum tersedia');
      return;
    }
    if (!_validateItems()) return;

    if (_sourceType == 'ro' && _selectedRo == null) {
      _showError('Pilih RO Supplier terlebih dahulu');
      return;
    }
    if (_sourceType == 'do' && _selectedDo == null) {
      _showError('Pilih Delivery Order terlebih dahulu');
      return;
    }

    final confirmed = await _showPreviewDialog();
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
    });

    final itemsPayload = _items.map((item) {
      final unitId = item.unitId ?? 1;
      final Map<String, dynamic> payload = {
        'item_id': item.itemId,
        'qty_ordered': item.qtyOrdered,
        'qty_received': item.qtyReceived,
        'unit_id': unitId,
      };

      if (_sourceType == 'ro') {
        payload['ro_item_id'] = item.roItemId;
        payload['price'] = item.price ?? 0;
      }

      return payload;
    }).toList();

    Map<String, dynamic> result;
    if (_sourceType == 'ro') {
      result = await _service.createFromRO(
        roSupplierId: _selectedRo!.id,
        receiveDate: _dateController.text,
        notes: _notesController.text,
        items: itemsPayload,
      );
    } else {
      result = await _service.createFromDO(
        deliveryOrderId: _selectedDo!.id,
        receiveDate: _dateController.text,
        items: itemsPayload,
      );
    }

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
      _showError(result['message'] ?? 'Gagal menyimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Outlet Supplier GR',
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF6F7FB), Color(0xFFEFF3F8)],
              ),
            ),
          ),
          if (_isLoading)
            const AppLoadingIndicator()
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSourceCard(),
                  const SizedBox(height: 16),
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildItemsCard(),
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ),
            ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceCard() {
    return _buildSectionCard(
      title: 'Sumber Good Receive',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Delivery Order'),
                  selected: _sourceType == 'do',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sourceType = 'do';
                        _selectedRo = null;
                        _headerInfo = null;
                        _resetItems([]);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('RO Supplier'),
                  selected: _sourceType == 'ro',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sourceType = 'ro';
                        _selectedDo = null;
                        _headerInfo = null;
                        _resetItems([]);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_sourceType == 'do')
            DropdownButtonFormField<OutletSupplierDoOption>(
              value: _selectedDo,
                    isExpanded: true,
                    selectedItemBuilder: (context) => _doOptions
                        .map((option) => _buildDropdownText('${option.doNumber} - ${option.roGrNumber ?? '-'}'))
                        .toList(),
              items: _doOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                            child: _buildDropdownText('${option.doNumber} - ${option.roGrNumber ?? '-'}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDo = value;
                });
                if (value != null) {
                  _loadDoDetail(value.id);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Pilih Delivery Order',
                border: OutlineInputBorder(),
              ),
            )
          else
            DropdownButtonFormField<OutletSupplierRoOption>(
              value: _selectedRo,
              isExpanded: true,
              selectedItemBuilder: (context) => _roOptions
                  .map((option) => _buildDropdownText('${option.roNumber} - ${option.floorOrderNumber ?? '-'}'))
                  .toList(),
              items: _roOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: _buildDropdownText('${option.roNumber} - ${option.floorOrderNumber ?? '-'}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRo = value;
                });
                if (value != null) {
                  _loadRoDetail(value.id);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Pilih RO Supplier',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _dateController,
            readOnly: true,
            onTap: () => _selectDate(context),
            decoration: const InputDecoration(
              labelText: 'Tanggal Terima',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    if (_headerInfo == null || _headerInfo!.isEmpty) {
      return _buildSectionCard(
        title: 'Info Sumber',
        child: const Text('Pilih sumber untuk melihat detail'),
      );
    }

    final header = _headerInfo!;
    final rows = <Widget>[];

    if (_sourceType == 'do') {
      rows.addAll([
        _buildInfoRow('Nomor DO', header['do_number']?.toString() ?? '-'),
        _buildInfoRow('RO GR', header['ro_gr_number']?.toString() ?? '-'),
        _buildInfoRow('RO Number', header['ro_floor_order_number']?.toString() ?? '-'),
        _buildInfoRow('Outlet', header['outlet_name']?.toString() ?? '-'),
      ]);
    } else {
      rows.addAll([
        _buildInfoRow('Nomor RO', header['ro_number']?.toString() ?? '-'),
        _buildInfoRow('Tanggal', header['tanggal']?.toString() ?? '-'),
        _buildInfoRow('Outlet', header['outlet_name']?.toString() ?? '-'),
        _buildInfoRow('Warehouse', header['warehouse_outlet_name']?.toString() ?? '-'),
        _buildInfoRow('Supplier', header['supplier_name']?.toString() ?? '-'),
      ]);
    }

    return _buildSectionCard(
      title: 'Info Sumber',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildItemsCard() {
    return _buildSectionCard(
      title: 'List Item',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_items.isEmpty)
            const Text('Belum ada item')
          else
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3E7EF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQtyChip('Qty Order', _formatQty(item.qtyOrdered), item.unitName),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _qtyControllers[index],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Qty Terima',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                              setState(() {
                                _items[index].qtyReceived = parsed;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              safeValue,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownText(String text) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildQtyChip(String label, String value, String? unitName) {
    final unitText = (unitName ?? '').trim();
    final displayUnit = unitText.isEmpty ? '' : ' $unitText';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '$value$displayUnit',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _formatQty(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      if (value % 1 == 0) return value.toInt().toString();
      return value.toString();
    }
    final raw = value.toString();
    return raw.trim().isEmpty ? '-' : raw;
  }
}
