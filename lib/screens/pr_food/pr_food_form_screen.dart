import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/pr_food_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class PrFoodFormScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;

  const PrFoodFormScreen({super.key, this.editData});

  @override
  State<PrFoodFormScreen> createState() => _PrFoodFormScreenState();
}

class _PrFoodFormScreenState extends State<PrFoodFormScreen> {
  final PrFoodService _service = PrFoodService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form fields
  final TextEditingController _tanggalController = TextEditingController();
  int? _selectedWarehouseId;
  int? _selectedWarehouseDivisionId;
  final TextEditingController _descriptionController = TextEditingController();

  // Options
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _warehouseDivisions = [];
  List<Map<String, dynamic>> _items = [];

  // Items list
  List<PrFoodItemForm> _formItems = [];

  // Loading states
  bool _isLoading = false;
  bool _isLoadingOptions = true;
  bool _isLoadingDivisions = false;
  bool _isSubmitting = false;

  // Item autocomplete
  Map<int, List<Map<String, dynamic>>> _itemSuggestions = {};
  Map<int, bool> _itemLoading = {};
  Map<int, bool> _itemShowDropdown = {};
  Map<int, int> _itemHighlightedIndex = {};
  Timer? _searchDebounceTimer;

  // Stock info per item
  Map<int, Map<String, dynamic>?> _itemStocks = {};

  @override
  void initState() {
    super.initState();
    // Check schedule for create mode
    if (widget.editData == null && !_service.isWithinPrFoodsSchedule()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Jadwal PR Foods'),
            content: const Text('PR Foods hanya bisa dibuat di luar jam 10:00 - 15:00'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
      return;
    }
    _initializeForm();
    _loadOptions();
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    _searchDebounceTimer?.cancel();
    for (var item in _formItems) {
      item.itemNameController.dispose();
      item.qtyController.dispose();
      item.unitController.dispose();
      item.noteController.dispose();
      item.arrivalDateController.dispose();
    }
    super.dispose();
  }

  void _initializeForm() {
    if (widget.editData != null) {
      // Edit mode
      final prFood = widget.editData!;
      _tanggalController.text = prFood['tanggal'] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(prFood['tanggal']))
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedWarehouseId = prFood['warehouse_id'];
      _selectedWarehouseDivisionId = prFood['warehouse_division_id'];
      _descriptionController.text = prFood['description'] ?? '';

      if (prFood['items'] != null) {
        _formItems = (prFood['items'] as List).map((item) {
          return PrFoodItemForm(
            itemId: item['item_id'],
            itemName: item['item']?['name'] ?? item['item_name'] ?? '',
            qty: item['qty']?.toString() ?? '',
            unit: item['unit'] ?? '',
            note: item['note'] ?? '',
            arrivalDate: item['arrival_date'] != null
                ? DateFormat('yyyy-MM-dd').format(DateTime.parse(item['arrival_date']))
                : '',
          );
        }).toList();
      }
    } else {
      // Create mode
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _formItems = [
        PrFoodItemForm(),
      ];
    }
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final warehouses = await _service.getWarehouses();
      final items = await _service.getItems();

      if (mounted) {
        setState(() {
          _warehouses = warehouses;
          _items = items;
        });

        // Load warehouse divisions if warehouse is already selected (edit mode)
        if (_selectedWarehouseId != null) {
          await _loadWarehouseDivisions(_selectedWarehouseId!);
        }

        // If edit mode, load full data from API
        if (widget.editData != null && widget.editData!['id'] != null) {
          await _loadEditData(widget.editData!['id']);
        }

        if (mounted) {
          setState(() {
            _isLoadingOptions = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading options: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadEditData(int id) async {
    try {
      final prFood = await _service.getPrFood(id);
      if (prFood != null && mounted) {
        // Update form with fresh data from API
        _tanggalController.text = prFood['tanggal'] != null
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(prFood['tanggal']))
            : DateFormat('yyyy-MM-dd').format(DateTime.now());
        _selectedWarehouseId = prFood['warehouse_id'];
        _selectedWarehouseDivisionId = prFood['warehouse_division_id'];
        _descriptionController.text = prFood['description'] ?? '';

        if (prFood['items'] != null) {
          _formItems = (prFood['items'] as List).map((item) {
            return PrFoodItemForm(
              itemId: item['item_id'],
              itemName: item['item']?['name'] ?? item['item_name'] ?? '',
              qty: item['qty']?.toString() ?? '',
              unit: item['unit'] ?? '',
              note: item['note'] ?? '',
              arrivalDate: item['arrival_date'] != null
                  ? DateFormat('yyyy-MM-dd').format(DateTime.parse(item['arrival_date']))
                  : '',
            );
          }).toList();

          // Load warehouse divisions first
          if (_selectedWarehouseId != null) {
            await _loadWarehouseDivisions(_selectedWarehouseId!);
          }

          // Then load stock for each item
          if (mounted) {
            setState(() {});
            for (int i = 0; i < _formItems.length; i++) {
              if (_formItems[i].itemId != null && _selectedWarehouseId != null) {
                _fetchStock(i);
              }
            }
          }
        } else {
          // Load warehouse divisions if no items
          if (_selectedWarehouseId != null) {
            await _loadWarehouseDivisions(_selectedWarehouseId!);
          }
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      print('Error loading edit data: $e');
    }
  }

  Future<void> _loadWarehouseDivisions(int warehouseId) async {
    setState(() {
      _isLoadingDivisions = true;
    });

    try {
      final divisions = await _service.getWarehouseDivisions(warehouseId: warehouseId);

      if (mounted) {
        setState(() {
          _warehouseDivisions = divisions;
          _isLoadingDivisions = false;
        });

        // Fetch stock for all items when warehouse changes
        for (int i = 0; i < _formItems.length; i++) {
          if (_formItems[i].itemId != null) {
            _fetchStock(i);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDivisions = false;
        });
      }
    }
  }

  Future<void> _fetchStock(int index) async {
    final item = _formItems[index];
    if (item.itemId == null || _selectedWarehouseId == null) {
      print('Cannot fetch stock: itemId=${item.itemId}, warehouseId=$_selectedWarehouseId');
      return;
    }

    try {
      // Call inventory stock API via service
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        print('Cannot fetch stock: No token');
        return;
      }

      // Use the correct endpoint - check if it's in approval-app group or direct
      final url = Uri.parse('${PrFoodService.baseUrl}/api/approval-app/inventory/stock').replace(
        queryParameters: {
          'item_id': item.itemId.toString(),
          'warehouse_id': _selectedWarehouseId.toString(),
        },
      );

      print('Fetching stock from: $url');
      print('Parameters: item_id=${item.itemId}, warehouse_id=$_selectedWarehouseId');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Stock response status: ${response.statusCode}');
      print('Stock response body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        print('Stock data received (raw): $data');
        print('Stock data type: ${data.runtimeType}');
        
        // Handle different response formats
        Map<String, dynamic>? stockData;
        if (data is Map) {
          stockData = Map<String, dynamic>.from(data as Map);
          print('Stock data parsed as Map: $stockData');
        } else if (data is List && data.isNotEmpty && data[0] is Map) {
          stockData = Map<String, dynamic>.from(data[0] as Map);
          print('Stock data parsed from List: $stockData');
        } else {
          print('Stock data format not recognized, setting to null');
          stockData = null;
        }

        if (stockData != null) {
          print('Stock values: qty_small=${stockData['qty_small']}, qty_medium=${stockData['qty_medium']}, qty_large=${stockData['qty_large']}');
          print('Stock units: unit_small=${stockData['unit_small']}, unit_medium=${stockData['unit_medium']}, unit_large=${stockData['unit_large']}');
        }

        setState(() {
          _itemStocks[index] = stockData;
        });
        print('Stock saved for index $index: ${_itemStocks[index]}');
      } else {
        print('Stock API error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _itemStocks[index] = null;
          });
        }
      }
    } catch (e) {
      print('Error fetching stock: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _itemStocks[index] = null;
        });
      }
    }
  }

  String _formatStock(int index) {
    final stock = _itemStocks[index];
    if (stock == null) return 'Stok: 0';

    // Format number: if whole number, show as integer, else show 2 decimal places
    String formatNumber(dynamic val) {
      if (val == null) return '0';
      final numValue = val is num ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
      if (numValue % 1 == 0) {
        return numValue.toInt().toString();
      }
      return NumberFormat('#,###.##').format(numValue);
    }

    final qtySmall = stock['qty_small'] ?? 0;
    final qtyMedium = stock['qty_medium'] ?? 0;
    final qtyLarge = stock['qty_large'] ?? 0;
    final unitSmall = stock['unit_small'] ?? '';
    final unitMedium = stock['unit_medium'] ?? '';
    final unitLarge = stock['unit_large'] ?? '';

    final parts = <String>[];
    
    // Helper function to check if value > 0
    bool isGreaterThanZero(dynamic value) {
      if (value == null) return false;
      if (value is num) return value > 0;
      final parsed = double.tryParse(value.toString());
      return parsed != null && parsed > 0;
    }
    
    if (isGreaterThanZero(qtySmall)) {
      parts.add('${formatNumber(qtySmall)} $unitSmall');
    }
    if (isGreaterThanZero(qtyMedium)) {
      parts.add('${formatNumber(qtyMedium)} $unitMedium');
    }
    if (isGreaterThanZero(qtyLarge)) {
      parts.add('${formatNumber(qtyLarge)} $unitLarge');
    }

    return 'Stok: ${parts.isEmpty ? '0' : parts.join(' | ')}';
  }

  Future<void> _submitForm() async {
    // Check schedule for create mode
    if (widget.editData == null && !_service.isWithinPrFoodsSchedule()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PR Foods hanya bisa dibuat di luar jam 10:00 - 15:00'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate items
    bool hasValidItem = false;
    for (var item in _formItems) {
      if (item.itemId != null && item.qtyController.text.isNotEmpty) {
        hasValidItem = true;
        break;
      }
    }

    if (!hasValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare items data
      final itemsData = _formItems
          .where((item) => item.itemId != null && item.qtyController.text.isNotEmpty)
          .map((item) {
        return {
          'item_id': item.itemId,
          'qty': double.parse(item.qtyController.text),
          'unit': item.unitController.text,
          'note': item.noteController.text,
          if (item.arrivalDateController.text.isNotEmpty)
            'arrival_date': item.arrivalDateController.text,
        };
      }).toList();

      Map<String, dynamic> result;
      if (widget.editData != null) {
        result = await _service.updatePrFood(
          id: widget.editData!['id'],
          tanggal: _tanggalController.text,
          warehouseId: _selectedWarehouseId!,
          warehouseDivisionId: _selectedWarehouseDivisionId,
          description: _descriptionController.text,
          items: itemsData,
        );
      } else {
        result = await _service.createPrFood(
          tanggal: _tanggalController.text,
          warehouseId: _selectedWarehouseId!,
          warehouseDivisionId: _selectedWarehouseDivisionId,
          description: _descriptionController.text,
          items: itemsData,
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.editData != null
                  ? 'PR Food berhasil diupdate'
                  : 'PR Food berhasil dibuat'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menyimpan PR Food'),
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

  void _onWarehouseChanged(int? warehouseId) {
    setState(() {
      _selectedWarehouseId = warehouseId;
      _selectedWarehouseDivisionId = null;
      _warehouseDivisions = [];
    });

    if (warehouseId != null) {
      _loadWarehouseDivisions(warehouseId);
      // Fetch stock for all items when warehouse changes
      for (int i = 0; i < _formItems.length; i++) {
        if (_formItems[i].itemId != null) {
          _fetchStock(i);
        }
      }
    }
  }

  void _addItem() {
    print('_addItem called, current items: ${_formItems.length}');
    setState(() {
      _formItems.add(PrFoodItemForm());
      // Initialize item state maps for new item
      final newIndex = _formItems.length - 1;
      _itemSuggestions[newIndex] = [];
      _itemLoading[newIndex] = false;
      _itemShowDropdown[newIndex] = false;
      _itemHighlightedIndex[newIndex] = 0;
      print('New item added, total items: ${_formItems.length}');
    });
    
    // Scroll to bottom after adding item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeItem(int index) {
    if (_formItems.length <= 1) return;
    setState(() {
      _formItems[index].dispose();
      _formItems.removeAt(index);
      _itemSuggestions.remove(index);
      _itemLoading.remove(index);
      _itemShowDropdown.remove(index);
      _itemHighlightedIndex.remove(index);
      _itemStocks.remove(index);
    });
  }

  Future<void> _searchItems(int index, String query) async {
    if (query.length < 2) {
      setState(() {
        _itemSuggestions[index] = [];
        _itemShowDropdown[index] = false;
      });
      return;
    }

    setState(() {
      _itemLoading[index] = true;
    });

    try {
      // Use API endpoint for search (same as web version)
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        print('Search items error: No token');
        setState(() {
          _itemLoading[index] = false;
          _itemSuggestions[index] = [];
        });
        return;
      }

      final uri = Uri.parse('${PrFoodService.baseUrl}/api/items/search-for-pr').replace(
        queryParameters: {'q': query},
      );

      print('Searching items: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Search response status: ${response.statusCode}');
      print('Search response body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> suggestions = [];
        
        if (data is List) {
          suggestions = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] != null) {
          suggestions = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['items'] != null) {
          suggestions = List<Map<String, dynamic>>.from(data['items']);
        }
        
        print('Found ${suggestions.length} suggestions');
        
        // Add available_units to each suggestion (same as web version)
        suggestions = suggestions.map((item) {
          return {
            ...item,
            'available_units': [
              if (item['unit_small'] != null) item['unit_small'],
              if (item['unit_medium'] != null) item['unit_medium'],
              if (item['unit_large'] != null) item['unit_large'],
            ].whereType<String>().toList(),
          };
        }).toList();

        setState(() {
          _itemSuggestions[index] = suggestions;
          _itemLoading[index] = false;
          _itemShowDropdown[index] = suggestions.isNotEmpty;
          _itemHighlightedIndex[index] = 0;
        });
      } else {
        print('Search items error: ${response.statusCode} - ${response.body}');
        setState(() {
          _itemLoading[index] = false;
          _itemSuggestions[index] = [];
        });
      }
    } catch (e) {
      print('Search items exception: $e');
      if (mounted) {
        setState(() {
          _itemLoading[index] = false;
          _itemSuggestions[index] = [];
        });
      }
    }
  }

  void _selectItem(int index, Map<String, dynamic> item) {
    setState(() {
      _formItems[index].itemId = item['id'];
      _formItems[index].itemNameController.text = item['name'] ?? '';
      // Use unit_small as default, fallback to unit
      final defaultUnit = item['unit_small'] ?? item['unit'] ?? '';
      _formItems[index].unitController.text = defaultUnit;
      // Remove duplicates from availableUnits
      final units = <String>[];
      if (item['unit_small'] != null && item['unit_small'].toString().isNotEmpty) {
        units.add(item['unit_small'].toString());
      }
      if (item['unit_medium'] != null && item['unit_medium'].toString().isNotEmpty) {
        final unit = item['unit_medium'].toString();
        if (!units.contains(unit)) units.add(unit);
      }
      if (item['unit_large'] != null && item['unit_large'].toString().isNotEmpty) {
        final unit = item['unit_large'].toString();
        if (!units.contains(unit)) units.add(unit);
      }
      _formItems[index].availableUnits = units;
      _itemSuggestions[index] = [];
      _itemShowDropdown[index] = false;
    });

    // Fetch stock
    if (_selectedWarehouseId != null) {
      _fetchStock(index);
    }
  }

  Future<void> _showItemSearchModal(int index) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemSearchModal(
        onItemSelected: (item) {
          _selectItem(index, item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.editData != null ? 'Edit PR Foods' : 'Tambah PR Foods',
      body: _isLoadingOptions
          ? const AppLoadingIndicator()
          : Form(
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.blue.shade100,
                                ],
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
                                  child: Icon(
                                    widget.editData != null
                                        ? Icons.edit_document
                                        : Icons.add_circle_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.editData != null
                                            ? 'Edit PR Foods'
                                            : 'Tambah PR Foods',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.editData != null
                                            ? 'Ubah informasi PR Foods'
                                            : 'Buat PR Foods baru',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                  color: Colors.blue.shade700,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Form Information Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Informasi PR Foods',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Form fields
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _tanggalController,
                                          decoration: InputDecoration(
                                            labelText: 'Tanggal *',
                                            prefixIcon: const Icon(Icons.calendar_today),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                          ),
                                          readOnly: true,
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _tanggalController.text.isNotEmpty
                                                  ? DateTime.parse(_tanggalController.text)
                                                  : DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _tanggalController.text =
                                                    DateFormat('yyyy-MM-dd').format(picked);
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
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _isLoadingOptions
                                            ? TextFormField(
                                                decoration: InputDecoration(
                                                  labelText: 'Warehouse *',
                                                  prefixIcon: const Icon(Icons.warehouse),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  suffixIcon: const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: Padding(
                                                      padding: EdgeInsets.all(12),
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                readOnly: true,
                                                controller: TextEditingController(text: 'Memuat warehouse...'),
                                                style: const TextStyle(color: Colors.grey),
                                              )
                                            : _warehouses.isEmpty
                                                ? TextFormField(
                                                    decoration: InputDecoration(
                                                      labelText: 'Warehouse *',
                                                      prefixIcon: const Icon(Icons.warehouse),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      suffixIcon: IconButton(
                                                        icon: const Icon(Icons.refresh),
                                                        onPressed: () {
                                                          _loadOptions();
                                                        },
                                                      ),
                                                    ),
                                                    readOnly: true,
                                                    controller: TextEditingController(text: 'Tidak ada warehouse tersedia'),
                                                    style: const TextStyle(color: Colors.grey),
                                                  )
                                                : DropdownButtonFormField<int>(
                                                value: _selectedWarehouseId,
                                                decoration: InputDecoration(
                                                  labelText: 'Warehouse *',
                                                  prefixIcon: const Icon(Icons.warehouse),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                                iconEnabledColor: Colors.black87,
                                                iconDisabledColor: Colors.grey,
                                                isExpanded: true,
                                                menuMaxHeight: 200,
                                                dropdownColor: Colors.white,
                                                items: _warehouses.map((warehouse) {
                                                  return DropdownMenuItem<int>(
                                                    value: warehouse['id'],
                                                    child: Text(
                                                      warehouse['name'] ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: _onWarehouseChanged,
                                                validator: (value) {
                                                  if (value == null) {
                                                    return 'Warehouse harus dipilih';
                                                  }
                                                  return null;
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _selectedWarehouseId == null
                                      ? TextFormField(
                                          decoration: InputDecoration(
                                            labelText: 'Warehouse Division',
                                            prefixIcon: const Icon(Icons.business),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            suffixIcon: const Icon(Icons.arrow_drop_down),
                                          ),
                                          readOnly: true,
                                          controller: TextEditingController(text: 'Pilih warehouse terlebih dahulu'),
                                          style: const TextStyle(color: Colors.grey),
                                        )
                                      : _isLoadingDivisions
                                          ? TextFormField(
                                              decoration: InputDecoration(
                                                labelText: 'Warehouse Division',
                                                prefixIcon: const Icon(Icons.business),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                suffixIcon: const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              readOnly: true,
                                              controller: TextEditingController(text: 'Memuat...'),
                                              style: const TextStyle(color: Colors.grey),
                                            )
                                          : _warehouseDivisions.isEmpty
                                              ? TextFormField(
                                                  decoration: InputDecoration(
                                                    labelText: 'Warehouse Division',
                                                    prefixIcon: const Icon(Icons.business),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    suffixIcon: const Icon(Icons.arrow_drop_down),
                                                  ),
                                                  readOnly: true,
                                                  controller: TextEditingController(text: 'Tidak ada division tersedia'),
                                                  style: const TextStyle(color: Colors.grey),
                                                )
                                              : DropdownButtonFormField<int>(
                                                  value: _selectedWarehouseDivisionId,
                                                  decoration: InputDecoration(
                                                    labelText: 'Warehouse Division',
                                                    prefixIcon: const Icon(Icons.business),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                  iconEnabledColor: Colors.black87,
                                                  iconDisabledColor: Colors.grey,
                                                  isExpanded: true,
                                                  menuMaxHeight: 200,
                                                  dropdownColor: Colors.white,
                                                  items: _warehouseDivisions.map((division) {
                                                    return DropdownMenuItem<int>(
                                                      value: division['id'],
                                                      child: Text(
                                                        division['name'] ?? '',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedWarehouseDivisionId = value;
                                                    });
                                                  },
                                                ),
                                  const SizedBox(height: 16),
                                  // Description
                                  TextFormField(
                                    controller: _descriptionController,
                                    decoration: InputDecoration(
                                      labelText: 'Keterangan',
                                      prefixIcon: const Icon(Icons.description),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Items Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.list_alt,
                                        color: Colors.orange.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Detail Item',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: _formItems.length,
                                      itemBuilder: (context, index) {
                                        final item = _formItems[index];
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
                                              // Header with item number and delete button
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Item ${index + 1}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                  ),
                                                  if (_formItems.length > 1)
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                      onPressed: () => _removeItem(index),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Item selection field
                                              InkWell(
                                                onTap: () => _showItemSearchModal(index),
                                                child: TextFormField(
                                                  controller: item.itemNameController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Item *',
                                                    hintText: 'Klik untuk pilih item...',
                                                    prefixIcon: const Icon(Icons.inventory_2, size: 20),
                                                    suffixIcon: const Icon(Icons.search, size: 20),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                  ),
                                                  style: const TextStyle(fontSize: 14),
                                                  enabled: false,
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) {
                                                      return 'Item harus diisi';
                                                    }
                                                    if (item.itemId == null) {
                                                      return 'Pilih item';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              // Stock display
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4, left: 4),
                                                child: Text(
                                                  _formatStock(index),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _itemStocks[index] != null 
                                                        ? Colors.grey.shade600 
                                                        : Colors.grey.shade400,
                                                    fontStyle: _itemStocks[index] == null 
                                                        ? FontStyle.italic 
                                                        : FontStyle.normal,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              // Qty and Unit in a row
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextFormField(
                                                      controller: item.qtyController,
                                                      decoration: InputDecoration(
                                                        labelText: 'Qty *',
                                                        prefixIcon: const Icon(Icons.numbers, size: 20),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        filled: true,
                                                        fillColor: Colors.white,
                                                      ),
                                                      style: const TextStyle(fontSize: 14),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      validator: (value) {
                                                        if (value == null || value.isEmpty) {
                                                          return 'Qty harus diisi';
                                                        }
                                                        final qty = double.tryParse(value);
                                                        if (qty == null || qty <= 0) {
                                                          return 'Qty harus > 0';
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    flex: 2,
                                                    child: item.availableUnits.isNotEmpty
                                                        ? DropdownButtonFormField<String>(
                                                            value: item.unitController.text.isNotEmpty
                                                                ? item.unitController.text
                                                                : null,
                                                            decoration: InputDecoration(
                                                              labelText: 'Unit *',
                                                              prefixIcon: const Icon(Icons.scale, size: 20),
                                                              border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              filled: true,
                                                              fillColor: Colors.white,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.black87,
                                                            ),
                                                            iconEnabledColor: Colors.black87,
                                                            iconDisabledColor: Colors.grey,
                                                            isExpanded: true,
                                                            menuMaxHeight: 200,
                                                            dropdownColor: Colors.white,
                                                            items: item.availableUnits.map((unit) {
                                                              return DropdownMenuItem<String>(
                                                                value: unit,
                                                                child: Text(
                                                                  unit,
                                                                  style: const TextStyle(
                                                                    fontSize: 14,
                                                                    color: Colors.black87,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              );
                                                            }).toList(),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                item.unitController.text = value ?? '';
                                                              });
                                                            },
                                                            validator: (value) {
                                                              if (value == null || value.isEmpty) {
                                                                return 'Unit harus diisi';
                                                              }
                                                              return null;
                                                            },
                                                          )
                                                        : TextFormField(
                                                            controller: item.unitController,
                                                            decoration: InputDecoration(
                                                              labelText: 'Unit *',
                                                              prefixIcon: const Icon(Icons.scale, size: 20),
                                                              border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              filled: true,
                                                              fillColor: Colors.white,
                                                            ),
                                                            style: const TextStyle(fontSize: 14),
                                                            validator: (value) {
                                                              if (value == null || value.isEmpty) {
                                                                return 'Unit harus diisi';
                                                              }
                                                              return null;
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Note field
                                              TextFormField(
                                                controller: item.noteController,
                                                decoration: InputDecoration(
                                                  labelText: 'Note',
                                                  prefixIcon: const Icon(Icons.note, size: 20),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                                style: const TextStyle(fontSize: 14),
                                                maxLines: 2,
                                              ),
                                              const SizedBox(height: 12),
                                              // Arrival date field
                                              TextFormField(
                                                controller: item.arrivalDateController,
                                                decoration: InputDecoration(
                                                  labelText: 'Tgl Kedatangan',
                                                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                                style: const TextStyle(fontSize: 14),
                                                readOnly: true,
                                                onTap: () async {
                                                  final picked = await showDatePicker(
                                                    context: context,
                                                    initialDate: item.arrivalDateController.text.isNotEmpty
                                                        ? DateTime.parse(item.arrivalDateController.text)
                                                        : DateTime.now(),
                                                    firstDate: DateTime(2020),
                                                    lastDate: DateTime(2100),
                                                  );
                                                  if (picked != null) {
                                                    setState(() {
                                                      item.arrivalDateController.text =
                                                          DateFormat('yyyy-MM-dd').format(picked);
                                                    });
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              key: const Key('tambah_item_button'),
                              onPressed: () {
                                print('Tambah Item button clicked');
                                _addItem();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Tambah Item'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade100,
                                foregroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Submit buttons
                  Container(
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(widget.editData != null
                                  ? 'Simpan Perubahan'
                                  : 'Simpan'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ItemSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onItemSelected;

  const _ItemSearchModal({required this.onItemSelected});

  @override
  State<_ItemSearchModal> createState() => _ItemSearchModalState();
}

class _ItemSearchModalState extends State<_ItemSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadItems('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadItems(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${PrFoodService.baseUrl}/api/items/search-for-pr').replace(
          queryParameters: {'q': query},
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> items = [];
        
        if (data is List) {
          items = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] != null) {
          items = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['items'] != null) {
          items = List<Map<String, dynamic>>.from(data['items']);
        }

        if (mounted) {
          setState(() {
            _items = items;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _items = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading items for modal: $e');
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pilih Item',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari nama item atau SKU...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                _searchTimer?.cancel();
                setState(() {
                  _isLoading = true;
                });
                _searchTimer = Timer(const Duration(milliseconds: 500), () {
                  _loadItems(value);
                });
              },
            ),
          ),
          // Items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada item ditemukan',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, itemIndex) {
                          final item = _items[itemIndex];
                          return InkWell(
                            onTap: () {
                              widget.onItemSelected(item);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] ?? '-',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (item['sku'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'SKU: ${item['sku']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (item['unit_small'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item['unit_small'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
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
}

class PrFoodItemForm {
  int? itemId;
  final TextEditingController itemNameController;
  final TextEditingController qtyController;
  final TextEditingController unitController;
  final TextEditingController noteController;
  final TextEditingController arrivalDateController;
  List<String> availableUnits = [];

  PrFoodItemForm({
    this.itemId,
    String itemName = '',
    String qty = '',
    String unit = '',
    String note = '',
    String arrivalDate = '',
  })  : itemNameController = TextEditingController(text: itemName),
        qtyController = TextEditingController(text: qty),
        unitController = TextEditingController(text: unit),
        noteController = TextEditingController(text: note),
        arrivalDateController = TextEditingController(text: arrivalDate);

  void dispose() {
    itemNameController.dispose();
    qtyController.dispose();
    unitController.dispose();
    noteController.dispose();
    arrivalDateController.dispose();
  }
}

