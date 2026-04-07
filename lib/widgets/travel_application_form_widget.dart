import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TravelApplicationFormWidget extends StatefulWidget {
  final List<int> travelOutletIds;
  final List<Map<String, dynamic>> travelItems;
  final List<Map<String, dynamic>> outletOptions;
  final Function(List<int>) onTravelOutletsChanged;
  final Function(List<Map<String, dynamic>>) onTravelItemsChanged;
  final Function(double) onTotalChanged;

  const TravelApplicationFormWidget({
    super.key,
    required this.travelOutletIds,
    required this.travelItems,
    required this.outletOptions,
    required this.onTravelOutletsChanged,
    required this.onTravelItemsChanged,
    required this.onTotalChanged,
  });

  @override
  State<TravelApplicationFormWidget> createState() => _TravelApplicationFormWidgetState();
}

class _TravelApplicationFormWidgetState extends State<TravelApplicationFormWidget> {
  // Controllers cache untuk mencegah rebuild yang menyebabkan kehilangan focus
  final Map<String, TextEditingController> _controllers = {};
  
  @override
  void initState() {
    super.initState();
    _calculateTotal();
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
  
  TextEditingController _getController(String key, String initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
    // Don't update controller text if it exists - let user's input persist
    // This prevents focus loss when widget rebuilds
    return _controllers[key]!;
  }

  void _calculateTotal() {
    double total = 0;
    for (var item in widget.travelItems) {
      total += (item['subtotal'] as num).toDouble();
    }
    widget.onTotalChanged(total);
  }

  void _calculateTravelItemSubtotal(int itemIdx) {
    final item = widget.travelItems[itemIdx];
    final qty = (item['qty'] as num).toDouble();
    final unitPrice = (item['unit_price'] as num).toDouble();
    item['subtotal'] = qty * unitPrice;
    setState(() {});
    _calculateTotal();
  }

  void _addTravelOutlet() {
    setState(() {
      widget.travelOutletIds.add(0);
    });
    widget.onTravelOutletsChanged(widget.travelOutletIds);
  }

  void _removeTravelOutlet(int index) {
    if (widget.travelOutletIds.length <= 1) return;
    setState(() {
      widget.travelOutletIds.removeAt(index);
    });
    widget.onTravelOutletsChanged(widget.travelOutletIds);
  }

  void _addTravelItem() {
    setState(() {
      widget.travelItems.add({
        'item_type': 'transport',
        'item_name': '',
        'qty': 0.0,
        'unit': '',
        'unit_price': 0.0,
        'subtotal': 0.0,
        'allowance_recipient_name': null,
        'allowance_account_number': null,
        'others_notes': null,
      });
    });
    widget.onTravelItemsChanged(widget.travelItems);
  }

  void _removeTravelItem(int index) {
    if (widget.travelItems.length <= 1) return;
    setState(() {
      widget.travelItems.removeAt(index);
    });
    widget.onTravelItemsChanged(widget.travelItems);
    _calculateTotal();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Travel Destinations
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.shade200, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.map, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Outlet Tujuan Perjalanan Dinas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...widget.travelOutletIds.asMap().entries.map((entry) {
                return _buildTravelOutletRow(entry.key);
              }),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addTravelOutlet,
                icon: const Icon(Icons.add),
                label: const Text('Add Outlet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade700,
                  side: BorderSide(color: Colors.purple.shade300),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Travel Items
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.shade200, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.list, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Items Perjalanan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...widget.travelItems.asMap().entries.map((entry) {
                return _buildTravelItemCard(entry.key);
              }),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addTravelItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade700,
                  side: BorderSide(color: Colors.purple.shade300),
                ),
              ),
              const SizedBox(height: 16),
              // Total
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatCurrency(
                        widget.travelItems.fold(0.0, (sum, item) => sum + (item['subtotal'] as num).toDouble()),
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTravelOutletRow(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildSearchableDropdown<int>(
              label: 'Outlet Tujuan *',
              value: widget.travelOutletIds[index] == 0 ? null : widget.travelOutletIds[index],
              items: widget.outletOptions,
              getValue: (item) => item['id_outlet'] as int?,
              getLabel: (item) => item['nama_outlet'] ?? '',
              onChanged: (value) {
                setState(() {
                  widget.travelOutletIds[index] = value ?? 0;
                });
                widget.onTravelOutletsChanged(widget.travelOutletIds);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: widget.travelOutletIds.length > 1 ? () => _removeTravelOutlet(index) : null,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            padding: EdgeInsets.zero,
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableDropdown<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required T? Function(Map<String, dynamic>) getValue,
    required String Function(Map<String, dynamic>) getLabel,
    required void Function(T?) onChanged,
  }) {
    final selectedItem = value != null
        ? items.firstWhere(
            (item) => getValue(item) == value,
            orElse: () => <String, dynamic>{},
          )
        : null;

    return InkWell(
      onTap: () => _showSearchableDialog<T>(
        label: label,
        value: value,
        items: items,
        getValue: getValue,
        getLabel: getLabel,
        onChanged: onChanged,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          selectedItem != null ? getLabel(selectedItem) : 'Tap to search',
          style: TextStyle(
            color: selectedItem != null ? Colors.black87 : Colors.grey.shade600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Future<void> _showSearchableDialog<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required T? Function(Map<String, dynamic>) getValue,
    required String Function(Map<String, dynamic>) getLabel,
    required void Function(T?) onChanged,
  }) async {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredItems = List.from(items);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(label),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (query) {
                      setDialogState(() {
                        if (query.isEmpty) {
                          filteredItems = List.from(items);
                        } else {
                          filteredItems = items.where((item) {
                            final label = getLabel(item);
                            return label.toLowerCase().contains(query.toLowerCase());
                          }).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final itemValue = getValue(item);
                        final itemLabel = getLabel(item);
                        final isSelected = itemValue == value;

                        return ListTile(
                          title: Text(itemLabel),
                          selected: isSelected,
                          selectedTileColor: Colors.purple.shade50,
                          onTap: () {
                            onChanged(itemValue);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTravelItemCard(int itemIdx) {
    final item = widget.travelItems[itemIdx];
    final itemType = item['item_type'] ?? 'transport';
    
    // Auto-set item_name if not set or if type changed
    if (itemType == 'transport' && (item['item_name'] == null || item['item_name'] == '' || item['item_name'] != 'Transport')) {
      item['item_name'] = 'Transport';
    } else if (itemType == 'allowance' && (item['item_name'] == null || item['item_name'] == '' || item['item_name'] != 'Allowance')) {
      item['item_name'] = 'Allowance';
    }
    
    // Use controller cache to prevent focus loss
    final qtyKey = 'qty_$itemIdx';
    final unitKey = 'unit_$itemIdx';
    final priceKey = 'price_$itemIdx';
    final allowanceNameKey = 'allowance_name_$itemIdx';
    final allowanceAccountKey = 'allowance_account_$itemIdx';
    final othersNotesKey = 'others_notes_$itemIdx';
    final itemNameKey = 'item_name_$itemIdx';
    
    // Get or create controllers from cache
    final qtyController = _getController(qtyKey, item['qty']?.toString() ?? '');
    final unitController = _getController(unitKey, item['unit'] ?? '');
    
    // For price, handle empty/null values better
    final priceValue = item['unit_price'];
    final priceText = priceValue != null && priceValue != 0.0 
        ? (priceValue is double ? priceValue.toStringAsFixed(priceValue.truncateToDouble() == priceValue ? 0 : 2) : priceValue.toString())
        : '';
    final priceController = _getController(priceKey, priceText);
    
    final allowanceNameController = _getController(allowanceNameKey, item['allowance_recipient_name'] ?? '');
    final allowanceAccountController = _getController(allowanceAccountKey, item['allowance_account_number'] ?? '');
    final othersNotesController = _getController(othersNotesKey, item['others_notes'] ?? '');
    final itemNameController = _getController(itemNameKey, item['item_name'] ?? '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete button
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${itemIdx + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text(
                  _formatCurrency((item['subtotal'] as num).toDouble()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.travelItems.length > 1 ? () => _removeTravelItem(itemIdx) : null,
                tooltip: 'Delete Item',
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Item Type
          DropdownButtonFormField<String>(
            value: itemType,
            decoration: InputDecoration(
              labelText: 'Tipe Item *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
            iconSize: 24,
            isExpanded: true,
            items: const [
              DropdownMenuItem<String>(
                value: 'transport',
                child: Text('Transport', style: TextStyle(color: Colors.black87)),
              ),
              DropdownMenuItem<String>(
                value: 'allowance',
                child: Text('Allowance', style: TextStyle(color: Colors.black87)),
              ),
              DropdownMenuItem<String>(
                value: 'others',
                child: Text('Others', style: TextStyle(color: Colors.black87)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                item['item_type'] = value;
                // Auto-set item_name based on type
                if (value == 'transport') {
                  item['item_name'] = 'Transport';
                } else if (value == 'allowance') {
                  item['item_name'] = 'Allowance';
                }
                // For 'others', keep existing item_name or empty
              });
              widget.onTravelItemsChanged(widget.travelItems);
            },
          ),
          
          // Item Name - only show for 'others' type
          if (itemType == 'others') ...[
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('item_name_$itemIdx'),
              controller: itemNameController,
              decoration: InputDecoration(
                labelText: 'Item Name *',
                hintText: 'Enter item name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: (value) {
                item['item_name'] = value;
                widget.onTravelItemsChanged(widget.travelItems);
              },
            ),
          ],
          
          // Show item name as read-only for transport and allowance
          if (itemType == 'transport' || itemType == 'allowance') ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: itemType == 'transport' ? 'Transport' : 'Allowance',
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Allowance Fields
          if (itemType == 'allowance')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.yellow.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.yellow.shade800, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Allowance Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey('allowance_name_$itemIdx'),
                    controller: allowanceNameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Penerima Allowance *',
                      hintText: 'Enter recipient name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) {
                      item['allowance_recipient_name'] = value;
                      widget.onTravelItemsChanged(widget.travelItems);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey('allowance_account_$itemIdx'),
                    controller: allowanceAccountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'No. Rekening *',
                      hintText: 'Enter account number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) {
                      item['allowance_account_number'] = value;
                      widget.onTravelItemsChanged(widget.travelItems);
                    },
                  ),
                ],
              ),
            ),
          
          // Others Notes
          if (itemType == 'others')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, color: Colors.blue.shade800, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Others Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: othersNotesController,
                    decoration: InputDecoration(
                      labelText: 'Notes Others *',
                      hintText: 'Enter notes for this item',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 16),
                    maxLines: 4,
                    onChanged: (value) {
                      item['others_notes'] = value;
                      widget.onTravelItemsChanged(widget.travelItems);
                    },
                  ),
                ],
              ),
            ),
          
          if (itemType == 'allowance' || itemType == 'others')
            const SizedBox(height: 16),
          
          // Qty and Unit Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('qty_$itemIdx'),
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity *',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                  onChanged: (value) {
                    // Handle empty value
                    if (value.isEmpty) {
                      item['qty'] = 0.0;
                      _calculateTravelItemSubtotal(itemIdx);
                      return;
                    }
                    // Remove non-numeric characters except decimal point
                    final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');
                    // Prevent multiple decimal points
                    final parts = sanitized.split('.');
                    final finalValue = parts.length > 2 
                        ? '${parts[0]}.${parts.sublist(1).join('')}'
                        : sanitized;
                    
                    // Update controller text if it changed
                    if (qtyController.text != finalValue) {
                      final cursorPos = qtyController.selection.base.offset;
                      qtyController.value = TextEditingValue(
                        text: finalValue,
                        selection: TextSelection.collapsed(
                          offset: cursorPos > finalValue.length ? finalValue.length : cursorPos,
                        ),
                      );
                    }
                    
                    final qty = double.tryParse(finalValue) ?? 0.0;
                    item['qty'] = qty;
                    _calculateTravelItemSubtotal(itemIdx);
                    // Don't call setState here - let parent widget handle UI updates
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey('unit_$itemIdx'),
                  controller: unitController,
                  decoration: InputDecoration(
                    labelText: 'Unit *',
                    hintText: 'pcs, kg, etc',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                  onChanged: (value) {
                    item['unit'] = value;
                    widget.onTravelItemsChanged(widget.travelItems);
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Unit Price (Full Width)
          TextFormField(
            key: ValueKey('price_$itemIdx'),
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Unit Price *',
              hintText: '0',
              prefixText: 'Rp ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              // Handle empty value
              if (value.isEmpty) {
                item['unit_price'] = 0.0;
                _calculateTravelItemSubtotal(itemIdx);
                return;
              }
              // Remove non-numeric characters except decimal point
              final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');
              // Prevent multiple decimal points
              final parts = sanitized.split('.');
              final finalValue = parts.length > 2 
                  ? '${parts[0]}.${parts.sublist(1).join('')}'
                  : sanitized;
              
              // Update controller text if it changed
              if (priceController.text != finalValue) {
                final cursorPos = priceController.selection.base.offset;
                priceController.value = TextEditingValue(
                  text: finalValue,
                  selection: TextSelection.collapsed(
                    offset: cursorPos > finalValue.length ? finalValue.length : cursorPos,
                  ),
                );
              }
              
              final price = double.tryParse(finalValue) ?? 0.0;
              item['unit_price'] = price;
              _calculateTravelItemSubtotal(itemIdx);
              // Don't call setState here - let parent widget handle UI updates
            },
          ),
        ],
      ),
    );
  }
}

