import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/packing_list_service.dart';
import '../../models/packing_list_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class PackingListFormScreen extends StatefulWidget {
  const PackingListFormScreen({super.key});

  @override
  State<PackingListFormScreen> createState() => _PackingListFormScreenState();
}

class _PackingListFormScreenState extends State<PackingListFormScreen> {
  final PackingListService _service = PackingListService();

  // Step 1: RO Selection
  final TextEditingController _searchROController = TextEditingController();
  DateTime? _arrivalDateFilter;
  final TextEditingController _arrivalDateController = TextEditingController();
  List<FloorOrder> _floorOrders = [];
  FloorOrder? _selectedRO;
  bool _isLoadingROs = false;
  String _roError = '';
  String _viewMode = 'cards'; // 'cards' or 'list'

  // Step 2: Warehouse Division
  int? _selectedDivisionId;
  List<WarehouseDivision> _warehouseDivisions = [];

  // Step 3: Items
  List<AvailableItem> _items = [];
  bool _isLoadingItems = false;
  String _itemsError = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Set default tanggal kedatangan ke hari ini
    final today = DateTime.now();
    _arrivalDateFilter = today;
    _arrivalDateController.text = DateFormat('yyyy-MM-dd').format(today);
    // Load data dengan tanggal hari ini
    _loadFloorOrders(arrivalDate: DateFormat('yyyy-MM-dd').format(today));
  }

  @override
  void dispose() {
    _searchROController.dispose();
    _arrivalDateController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorOrders({String? arrivalDate}) async {
    setState(() {
      _isLoadingROs = true;
      _roError = '';
    });

    try {
      final result = await _service.getFloorOrders(
        arrivalDate: arrivalDate,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _floorOrders = result['floorOrders'] ?? [];
          _warehouseDivisions = result['warehouseDivisions'] ?? [];
          _isLoadingROs = false;
          _roError = '';
        });
      } else if (mounted) {
        final errorMessage = result['error'] ?? 'Gagal memuat data RO';
        setState(() {
          _isLoadingROs = false;
          _roError = errorMessage;
          _floorOrders = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = 'Failed to load floor orders: ${e.toString()}';
        setState(() {
          _isLoadingROs = false;
          _roError = errorMessage;
          _floorOrders = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exception: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadAvailableItems() async {
    if (_selectedRO == null || _selectedDivisionId == null) return;

    setState(() {
      _isLoadingItems = true;
      _itemsError = '';
      _items = [];
    });

    try {
      final result = await _service.getAvailableItems(
        foId: _selectedRO!.id,
        divisionId: _selectedDivisionId!,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _items = result['items'] ?? [];
          _isLoadingItems = false;
        });
      } else if (mounted) {
        setState(() {
          _itemsError = result['error'] ?? 'Gagal memuat data item.';
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _itemsError = 'Gagal memuat data item.';
          _isLoadingItems = false;
        });
      }
    }
  }

  List<FloorOrder> _getFilteredROs() {
    List<FloorOrder> filtered = _floorOrders;

    if (_searchROController.text.isNotEmpty) {
      final search = _searchROController.text.toLowerCase();
      filtered = filtered.where((ro) {
        return (ro.outlet?.namaOutlet.toLowerCase().contains(search) ?? false) ||
            (ro.orderNumber?.toLowerCase().contains(search) ?? false) ||
            (ro.requester?.namaLengkap.toLowerCase().contains(search) ?? false) ||
            (ro.tanggal != null && DateFormat('dd/MM/yyyy').format(ro.tanggal!).toLowerCase().contains(search));
      }).toList();
    }

    if (_arrivalDateFilter != null) {
      filtered = filtered.where((ro) {
        if (ro.arrivalDate == null) return false;
        final roArrivalDate = DateFormat('yyyy-MM-dd').format(ro.arrivalDate!);
        final filterDate = DateFormat('yyyy-MM-dd').format(_arrivalDateFilter!);
        return roArrivalDate == filterDate;
      }).toList();
    }

    return filtered;
  }

  void _selectRO(FloorOrder ro) {
    setState(() {
      _selectedRO = ro;
      _selectedDivisionId = null;
      _items = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedRO = null;
      _selectedDivisionId = null;
      _items = [];
    });
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _fillItemQuantity(AvailableItem item) {
    setState(() {
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        // Isi inputQty dengan qtyOrder (atau qty jika qtyOrder tidak ada)
        double qtyToFill;
        if (item.qtyOrder != null && item.qtyOrder! > 0) {
          qtyToFill = item.qtyOrder!;
        } else if (item.qty > 0) {
          qtyToFill = item.qty;
        } else {
          qtyToFill = 0.0;
        }
        
        _items[index] = AvailableItem(
          id: item.id,
          itemId: item.itemId,
          floorOrderId: item.floorOrderId,
          qty: item.qty,
          qtyOrder: item.qtyOrder,
          unit: item.unit,
          stock: item.stock,
          item: item.item,
          checked: item.checked,
          inputQty: qtyToFill,
          source: item.source,
          reason: item.reason,
        );
      }
    });
  }

  Map<String, List<AvailableItem>> _getItemsByCategory() {
    final map = <String, List<AvailableItem>>{};
    for (var item in _items) {
      final catName = item.item?.category?.name ?? 'Tanpa Kategori';
      if (!map.containsKey(catName)) {
        map[catName] = [];
      }
      map[catName]!.add(item);
    }
    return map;
  }

  Future<void> _showSummaryAndSubmit() async {
    if (_selectedRO == null || _selectedDivisionId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih RO dan Warehouse Division terlebih dahulu!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedItems = _items.where((i) => i.checked).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu item untuk di-packing!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final invalidItems = selectedItems.where((item) => item.inputQty == null || item.inputQty! <= 0).toList();
    if (invalidItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua item yang dipilih harus memiliki quantity yang valid!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final div = _warehouseDivisions.where((d) => d.id == _selectedDivisionId).toList();
    final divisionName = div.isEmpty ? '-' : div.first.name;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2, color: Colors.blue.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konfirmasi Packing List',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ringkasan
              Text(
                'Ringkasan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow(Icons.store, 'Outlet', _selectedRO!.outlet?.namaOutlet ?? '-'),
                    _buildSummaryRow(Icons.receipt_long, 'Nomor RO', _selectedRO!.orderNumber ?? '-'),
                    _buildSummaryRow(Icons.calendar_today, 'Tanggal', _selectedRO!.tanggal != null ? DateFormat('dd/MM/yyyy').format(_selectedRO!.tanggal!) : '-'),
                    _buildSummaryRow(Icons.category, 'Warehouse Division', divisionName),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Total & daftar item
              Row(
                children: [
                  Text(
                    'Item yang akan di-packing',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${selectedItems.length} item',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: selectedItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isLast = index == selectedItems.length - 1;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.item?.name ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.inputQty} ${item.unit}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(height: 1, indent: 52, endIndent: 14, color: Colors.grey.shade200),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: Colors.grey.shade400),
            ),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Ya, Buat Packing List', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _submitPackingList();
    }
  }

  Future<void> _submitPackingList() async {
    if (_selectedRO == null || _selectedDivisionId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final selectedItems = _items.where((i) => i.checked).toList();
      final itemsData = selectedItems.map((item) => item.toJson()).toList();

      final result = await _service.createPackingList(
        foodFloorOrderId: _selectedRO!.id,
        warehouseDivisionId: _selectedDivisionId!,
        items: itemsData,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Packing List berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Gagal membuat Packing List.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat Packing List',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1: RO Selection
            const Text(
              '1. Pilih Request Order (RO)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Search and Filter
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _searchROController,
                      decoration: InputDecoration(
                        labelText: 'Cari RO',
                        hintText: 'Outlet, nomor RO, atau tanggal...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Date Filter
                    TextFormField(
                      controller: _arrivalDateController,
                      decoration: InputDecoration(
                        labelText: 'Tanggal Kedatangan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _arrivalDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() {
                            _arrivalDateFilter = date;
                            _arrivalDateController.text = DateFormat('yyyy-MM-dd').format(date);
                          });
                          _loadFloorOrders(arrivalDate: DateFormat('yyyy-MM-dd').format(date));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Clear Filters Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchROController.clear();
                            _arrivalDateFilter = null;
                            _arrivalDateController.clear();
                          });
                          // Reload data setelah clear filter
                          final today = DateTime.now();
                          _arrivalDateFilter = today;
                          _arrivalDateController.text = DateFormat('yyyy-MM-dd').format(today);
                          _loadFloorOrders(arrivalDate: DateFormat('yyyy-MM-dd').format(today));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Clear Filters'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // RO List
            if (_isLoadingROs)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_roError.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _roError,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _loadFloorOrders(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_getFilteredROs().isEmpty)
              Card(
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Tidak ada RO ditemukan'),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RO Tersedia (${_getFilteredROs().length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => setState(() => _viewMode = 'cards'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _viewMode == 'cards' ? Colors.blue : Colors.grey,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Cards', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => setState(() => _viewMode = 'list'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _viewMode == 'list' ? Colors.blue : Colors.grey,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('List', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_viewMode == 'cards')
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _getFilteredROs().length,
                      itemBuilder: (context, index) {
                        final ro = _getFilteredROs()[index];
                        final isSelected = _selectedRO?.id == ro.id;
                        return InkWell(
                          onTap: () => _selectRO(ro),
                          child: Card(
                            color: isSelected ? Colors.blue.shade50 : null,
                            borderOnForeground: true,
                            elevation: isSelected ? 4 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected 
                                  ? BorderSide(color: Colors.blue, width: 2)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header dengan title dan status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ro.outlet?.namaOutlet ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: ro.status == 'approved'
                                              ? Colors.green.shade100
                                              : Colors.yellow.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          ro.status ?? '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: ro.status == 'approved'
                                                ? Colors.green.shade700
                                                : Colors.yellow.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // RO Number
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long, size: 12, color: Colors.blue),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          ro.orderNumber ?? '-',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Tanggal
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          ro.tanggal != null 
                                              ? DateFormat('dd/MM/yyyy').format(ro.tanggal!)
                                              : '-',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Kedatangan
                                  Row(
                                    children: [
                                      const Icon(Icons.local_shipping, size: 12, color: Colors.grey),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          'Kedatangan: ${ro.arrivalDate != null ? DateFormat('dd/MM/yyyy').format(ro.arrivalDate!) : '-'}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Person/Pemohon
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 12, color: Colors.grey),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          ro.requester?.namaLengkap ?? '-',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Items count
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2, size: 12, color: Colors.blue),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${ro.items?.length ?? 0} items',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Outlet')),
                            DataColumn(label: Text('RO')),
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('Kedatangan')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: _getFilteredROs().map((ro) {
                            return DataRow(
                              selected: _selectedRO?.id == ro.id,
                              onSelectChanged: (selected) {
                                if (selected == true) {
                                  _selectRO(ro);
                                }
                              },
                              cells: [
                                DataCell(Text(ro.outlet?.namaOutlet ?? 'Unknown')),
                                DataCell(Text(
                                  ro.orderNumber ?? '',
                                  style: const TextStyle(fontFamily: 'monospace'),
                                )),
                                DataCell(Text(
                                  ro.tanggal != null
                                      ? DateFormat('dd/MM/yyyy').format(ro.tanggal!)
                                      : '-',
                                )),
                                DataCell(Text(
                                  ro.arrivalDate != null
                                      ? DateFormat('dd/MM/yyyy').format(ro.arrivalDate!)
                                      : '-',
                                )),
                                DataCell(Text(ro.status ?? '')),
                                DataCell(
                                  TextButton(
                                    onPressed: () => _selectRO(ro),
                                    child: const Text('Pilih'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            // Selected RO Details
            if (_selectedRO != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RO Terpilih',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Outlet: ${_selectedRO!.outlet?.namaOutlet ?? '-'}'),
                                Text('Nomor RO: ${_selectedRO!.orderNumber ?? '-'}'),
                                Text('Tanggal: ${_selectedRO!.tanggal != null ? DateFormat('dd/MM/yyyy').format(_selectedRO!.tanggal!) : '-'}'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kedatangan: ${_selectedRO!.arrivalDate != null ? DateFormat('dd/MM/yyyy').format(_selectedRO!.arrivalDate!) : '-'}'),
                                Text('Status: ${_selectedRO!.status ?? '-'}'),
                                Text('Items: ${_selectedRO!.items?.length ?? 0}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _clearSelection,
                        child: const Text('Pilih RO Lain'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Step 2: Warehouse Division
            if (_selectedRO != null) ...[
              const SizedBox(height: 32),
              const Text(
                '2. Pilih Warehouse Division',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail RO',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Outlet: ${_selectedRO!.outlet?.namaOutlet ?? '-'}'),
                      if (_selectedRO!.warehouseOutlet != null)
                        Text('Warehouse Outlet: ${_selectedRO!.warehouseOutlet!.name}'),
                      Text('Tanggal: ${_selectedRO!.tanggal != null ? DateFormat('dd/MM/yyyy').format(_selectedRO!.tanggal!) : '-'}'),
                      if (_selectedRO!.arrivalDate != null)
                        Text('Kedatangan: ${DateFormat('dd/MM/yyyy').format(_selectedRO!.arrivalDate!)}'),
                      Text('RO Mode: ${_selectedRO!.foMode ?? '-'}'),
                      Text('Nomor: ${_selectedRO!.orderNumber ?? '-'}'),
                      Text('Creator: ${_selectedRO!.requester?.namaLengkap ?? '-'}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedDivisionId,
                decoration: InputDecoration(
                  labelText: 'Warehouse Division',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _warehouseDivisions.map((div) {
                  return DropdownMenuItem<int>(
                    value: div.id,
                    child: Text(div.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDivisionId = value;
                    _items = [];
                  });
                  if (value != null) {
                    _loadAvailableItems();
                  }
                },
              ),
            ],
            // Step 3: Items Selection
            if (_selectedRO != null && _selectedDivisionId != null) ...[
              const SizedBox(height: 32),
              const Text(
                '3. Pilih Items untuk Packing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isLoadingItems)
                const Center(child: CircularProgressIndicator())
              else if (_itemsError.isNotEmpty)
                Center(
                  child: Text(
                    _itemsError,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else if (_items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Semua item di warehouse division ini sudah di-packing.'),
                  ),
                )
              else ...[
                Text('Total items: ${_items.where((i) => i.checked).length} dari ${_items.length}'),
                const SizedBox(height: 16),
                ..._getItemsByCategory().entries.map((entry) {
                  final categoryName = entry.key;
                  final categoryItems = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categoryItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final item = categoryItems[idx];
                            final qtyOrderDisplay = item.qtyOrder != null && item.qtyOrder! > 0
                                ? item.qtyOrder!
                                : (item.qty > 0 ? item.qty : 0.0);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris 1: Checkbox + Nama Item
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: item.checked,
                                        onChanged: (value) {
                                          setState(() {
                                            final itemIndex = _items.indexWhere((i) => i.id == item.id);
                                            if (itemIndex != -1) {
                                              _items[itemIndex] = AvailableItem(
                                                id: item.id,
                                                itemId: item.itemId,
                                                floorOrderId: item.floorOrderId,
                                                qty: item.qty,
                                                qtyOrder: item.qtyOrder,
                                                unit: item.unit,
                                                stock: item.stock,
                                                item: item.item,
                                                checked: value ?? false,
                                                inputQty: item.inputQty,
                                                source: item.source,
                                                reason: item.reason,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Text(
                                            item.item?.name ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Baris 2: Qty Order + Unit
                                  Padding(
                                    padding: const EdgeInsets.only(left: 48, bottom: 8),
                                    child: Row(
                                      children: [
                                        Text('Qty Order: ', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                        Text('$qtyOrderDisplay', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                        const SizedBox(width: 12),
                                        Text('Unit: ', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                        Text(item.unit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  // Baris 3: Input Qty (full width) + tombol =
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          key: ValueKey('${item.id}_${item.inputQty}'),
                                          initialValue: item.inputQty?.toString() ?? '',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: 'Input Qty',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                          onChanged: (value) {
                                            final qty = double.tryParse(value);
                                            setState(() {
                                              final itemIndex = _items.indexWhere((i) => i.id == item.id);
                                              if (itemIndex != -1) {
                                                _items[itemIndex] = AvailableItem(
                                                  id: item.id,
                                                  itemId: item.itemId,
                                                  floorOrderId: item.floorOrderId,
                                                  qty: item.qty,
                                                  qtyOrder: item.qtyOrder,
                                                  unit: item.unit,
                                                  stock: item.stock,
                                                  item: item.item,
                                                  checked: item.checked,
                                                  inputQty: qty,
                                                  source: item.source,
                                                  reason: item.reason,
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Isi otomatis qty = qty order',
                                        child: Material(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          child: InkWell(
                                            onTap: () => _fillItemQuantity(item),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              child: const Text(
                                                '=',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _showSummaryAndSubmit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Submit Packing List'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

