import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../services/purchase_requisition_service.dart';
import 'app_loading_indicator.dart';

class PROpsFormWidget extends StatefulWidget {
  final List<Map<String, dynamic>> outlets;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> outletOptions;
  final Function(List<Map<String, dynamic>>) onOutletsChanged;
  final Function(double) onTotalChanged;
  final Function(Map<int, List<File>>)? onAttachmentsChanged;

  const PROpsFormWidget({
    super.key,
    required this.outlets,
    required this.categories,
    required this.outletOptions,
    required this.onOutletsChanged,
    required this.onTotalChanged,
    this.onAttachmentsChanged,
  });

  @override
  State<PROpsFormWidget> createState() => _PROpsFormWidgetState();
}

class _PROpsFormWidgetState extends State<PROpsFormWidget> {
  final PurchaseRequisitionService _service = PurchaseRequisitionService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Budget info cache
  Map<String, Map<String, dynamic>> _budgetInfoCache = {};
  // Budget info loading state
  Map<String, bool> _budgetInfoLoading = {};
  
  // Attachments per outlet
  Map<int, List<File>> _outletAttachments = {};
  
  // Controllers cache untuk mencegah rebuild yang menyebabkan kehilangan focus
  final Map<String, TextEditingController> _controllers = {};
  
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

  List<Map<String, dynamic>> _getFilteredCategories() {
    // Filter out categories containing "transport" and "kasbon" for pr_ops and purchase_payment modes
    return widget.categories.where((cat) {
      final name = (cat['name'] ?? cat['nama'] ?? '').toString().toLowerCase();
      return !name.contains('transport') && !name.contains('kasbon');
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _calculateTotal();
  }

  void _calculateTotal() {
    double total = 0;
    for (var outlet in widget.outlets) {
      final categories = outlet['categories'] as List;
      for (var category in categories) {
        final categoryMap = category as Map<String, dynamic>;
        final items = categoryMap['items'] as List;
        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          total += (itemMap['subtotal'] as num).toDouble();
        }
      }
    }
    widget.onTotalChanged(total);
  }

  void _calculateSubtotal(int outletIdx, int categoryIdx, int itemIdx) {
    final item = widget.outlets[outletIdx]['categories'][categoryIdx]['items'][itemIdx] as Map<String, dynamic>;
    final qty = item['qty'] != null ? (item['qty'] as num).toDouble() : 0.0;
    final unitPrice = item['unit_price'] != null ? (item['unit_price'] as num).toDouble() : 0.0;
    item['subtotal'] = qty * unitPrice;
    // Don't call setState here - let parent widget handle UI updates
    _calculateTotal();
    // Refresh budget info when item changes (async, won't cause immediate rebuild)
    _loadBudgetInfo(outletIdx, categoryIdx, forceRefresh: true);
  }

  Future<void> _loadBudgetInfo(int outletIdx, int categoryIdx, {bool forceRefresh = false}) async {
    final outlet = widget.outlets[outletIdx];
    final category = outlet['categories'][categoryIdx];
    
    final outletId = outlet['outlet_id'];
    final categoryId = category['category_id'];
    
    return _loadBudgetInfoWithIds(outletIdx, categoryIdx, outletId, categoryId, forceRefresh: forceRefresh);
  }

  Future<void> _loadBudgetInfoWithIds(int outletIdx, int categoryIdx, int? outletId, int? categoryId, {bool forceRefresh = false}) async {
    print('🔍 _loadBudgetInfoWithIds called: outletId=$outletId, categoryId=$categoryId');
    
    if (outletId == null || categoryId == null) {
      print('❌ Missing outletId or categoryId');
      return;
    }
    
    final outlet = widget.outlets[outletIdx];
    final category = outlet['categories'][categoryIdx];
    
    final key = '$outletId-$categoryId';
    
    // If already cached and not forcing refresh, skip
    if (!forceRefresh && _budgetInfoCache.containsKey(key)) {
      print('✅ Budget info already cached for $key');
      return;
    }
    
    // Set loading state
    setState(() {
      _budgetInfoLoading[key] = true;
    });
    
    try {
      // Calculate current amount for this outlet-category
      double currentAmount = 0;
      for (var item in category['items']) {
        currentAmount += (item['subtotal'] as num).toDouble();
      }
      
      print('📊 Loading budget info: categoryId=$categoryId, outletId=$outletId, currentAmount=$currentAmount');
      
      final budgetInfo = await _service.getBudgetInfo(
        categoryId: categoryId,
        outletId: outletId,
        currentAmount: currentAmount,
      );
      
      print('📥 Budget info response: $budgetInfo');
      
      if (mounted) {
        setState(() {
          if (budgetInfo != null && budgetInfo.isNotEmpty) {
            // Store the budget info (service already handles parsing)
            _budgetInfoCache[key] = budgetInfo;
            print('✅ Budget info cached for $key: ${budgetInfo.keys}');
          } else {
            // Remove from cache if failed
            _budgetInfoCache.remove(key);
            print('❌ Budget info is null or empty, removed from cache');
          }
          _budgetInfoLoading[key] = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading budget info: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _budgetInfoLoading[key] = false;
        });
      }
    }
  }

  void _addOutlet() {
    setState(() {
      widget.outlets.add({
        'outlet_id': null,
        'categories': [
          {
            'category_id': null,
            'items': [
              {
                'item_name': '',
                'qty': null,
                'unit': '',
                'unit_price': null,
                'subtotal': 0.0,
              }
            ],
          }
        ],
      });
    });
    widget.onOutletsChanged(widget.outlets);
  }

  void _removeOutlet(int outletIdx) {
    if (widget.outlets.length <= 1) return;
    setState(() {
      final outletId = widget.outlets[outletIdx]['outlet_id'];
      if (outletId != null) {
        _outletAttachments.remove(outletId);
      }
      widget.outlets.removeAt(outletIdx);
    });
    widget.onOutletsChanged(widget.outlets);
    _calculateTotal();
  }

  void _addCategory(int outletIdx) {
    setState(() {
      widget.outlets[outletIdx]['categories'].add({
        'category_id': null,
        'items': [
          {
            'item_name': '',
            'qty': 0.0,
            'unit': '',
            'unit_price': 0.0,
            'subtotal': 0.0,
          }
        ],
      });
    });
    widget.onOutletsChanged(widget.outlets);
  }

  void _removeCategory(int outletIdx, int categoryIdx) {
    if (widget.outlets[outletIdx]['categories'].length <= 1) return;
    setState(() {
      widget.outlets[outletIdx]['categories'].removeAt(categoryIdx);
    });
    widget.onOutletsChanged(widget.outlets);
    _calculateTotal();
  }

  void _addItem(int outletIdx, int categoryIdx) {
    setState(() {
      final outlet = widget.outlets[outletIdx] as Map<String, dynamic>;
      final categories = outlet['categories'] as List;
      final category = categories[categoryIdx] as Map<String, dynamic>;
      
      // Get current items and create a new mutable list
      final currentItems = category['items'] as List;
      final newItems = List.from(currentItems);
      
      // Add new item as Map<String, dynamic>
      newItems.add(<String, dynamic>{
        'item_name': '',
        'qty': null,
        'unit': '',
        'unit_price': null,
        'subtotal': 0.0,
      });
      
      // Update category with new items list
      category['items'] = newItems;
    });
    widget.onOutletsChanged(widget.outlets);
    // Refresh budget info when item is added
    _loadBudgetInfo(outletIdx, categoryIdx, forceRefresh: true);
  }

  void _removeItem(int outletIdx, int categoryIdx, int itemIdx) {
    final items = widget.outlets[outletIdx]['categories'][categoryIdx]['items'];
    if (items.length <= 1) return;
    setState(() {
      items.removeAt(itemIdx);
    });
    widget.onOutletsChanged(widget.outlets);
    _calculateTotal();
    // Refresh budget info when item is removed
    _loadBudgetInfo(outletIdx, categoryIdx, forceRefresh: true);
  }

  Future<void> _uploadOutletAttachment(int outletIdx) async {
    final outlet = widget.outlets[outletIdx];
    final outletId = outlet['outlet_id'];
    
    if (outletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an outlet first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (!_outletAttachments.containsKey(outletId)) {
          _outletAttachments[outletId] = [];
        }
        _outletAttachments[outletId]!.add(File(picked.path));
        print('📎 Added attachment for outlet $outletId: ${picked.path}');
        print('📎 Total attachments for outlet $outletId: ${_outletAttachments[outletId]!.length}');
      });
      // Notify parent about attachment changes
      print('📎 Calling onAttachmentsChanged callback with ${_outletAttachments.length} outlets');
      widget.onAttachmentsChanged?.call(_outletAttachments);
    }
  }

  void _removeOutletAttachment(int outletId, int index) {
    print('📎 Removing attachment for outlet $outletId at index $index');
    setState(() {
      _outletAttachments[outletId]?.removeAt(index);
      if (_outletAttachments[outletId]?.isEmpty ?? false) {
        _outletAttachments.remove(outletId);
      }
      print('📎 Remaining attachments for outlet $outletId: ${_outletAttachments[outletId]?.length ?? 0}');
    });
    // Notify parent about attachment changes
    print('📎 Calling onAttachmentsChanged callback after removal');
    widget.onAttachmentsChanged?.call(_outletAttachments);
  }

  List<File> _getOutletAttachments(int? outletId) {
    if (outletId == null) return [];
    return _outletAttachments[outletId] ?? [];
  }

  // Public method to get all outlet attachments
  Map<int, List<File>> getOutletAttachments() {
    return Map<int, List<File>>.from(_outletAttachments);
  }

  Map<String, dynamic>? _getBudgetInfo(int outletIdx, int categoryIdx) {
    final outlet = widget.outlets[outletIdx];
    final category = outlet['categories'][categoryIdx];
    
    final outletId = outlet['outlet_id'];
    final categoryId = category['category_id'];
    
    if (outletId == null || categoryId == null) {
      return null;
    }
    
    final key = '$outletId-$categoryId';
    return _budgetInfoCache[key];
  }

  double _getOutletTotal(int outletIdx) {
    double total = 0;
    for (var category in widget.outlets[outletIdx]['categories']) {
      for (var item in category['items']) {
        total += (item['subtotal'] as num).toDouble();
      }
    }
    return total;
  }

  double _getCategoryTotal(int outletIdx, int categoryIdx) {
    double total = 0;
    final items = widget.outlets[outletIdx]['categories'][categoryIdx]['items'] as List;
    for (var item in items) {
      final itemMap = item as Map<String, dynamic>;
      total += (itemMap['subtotal'] as num).toDouble();
    }
    return total;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  // Helper function to safely parse numeric values from API response
  double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outlets
        ...widget.outlets.asMap().entries.map((entry) {
          return _buildOutletCard(entry.key);
        }),
        
        // Add Outlet Button
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ElevatedButton.icon(
            onPressed: _addOutlet,
            icon: const Icon(Icons.add),
            label: const Text('Add Outlet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutletCard(int outletIdx) {
    final outlet = widget.outlets[outletIdx];
    final outletId = outlet['outlet_id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outlet Header - Full Width
          SizedBox(
            width: double.infinity,
            child: _buildSearchableDropdown<int>(
              label: 'Outlet *',
              value: outletId,
              items: widget.outletOptions,
              getValue: (item) => item['id_outlet'] as int?,
              getLabel: (item) => item['nama_outlet'] ?? '',
              onChanged: (value) {
                setState(() {
                  outlet['outlet_id'] = value;
                  if (value != null && !_outletAttachments.containsKey(value)) {
                    _outletAttachments[value] = [];
                  }
                });
                widget.onOutletsChanged(widget.outlets);
              },
              isLoading: widget.outletOptions.isEmpty,
            ),
          ),
          const SizedBox(height: 12),
          
          // Total and Delete Button Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Total: ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _formatCurrency(_getOutletTotal(outletIdx)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.outlets.length > 1 ? () => _removeOutlet(outletIdx) : null,
                tooltip: 'Delete Outlet',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Attachments Section
          if (outletId != null) _buildAttachmentsSection(outletIdx, outletId),
          
          const SizedBox(height: 16),
          
          // Categories
          ...outlet['categories'].asMap().entries.map((entry) {
            return _buildCategoryCard(outletIdx, entry.key);
          }),
          
          // Add Category Button
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () => _addCategory(outletIdx),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Category'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(int outletIdx, int outletId) {
    final attachments = _getOutletAttachments(outletId);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 18),
              const SizedBox(width: 8),
              Text(
                'Attachments (${attachments.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _uploadOutletAttachment(outletIdx),
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Upload Files'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...attachments.asMap().entries.map((entry) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.file_present, size: 20),
                title: Text(
                  entry.value.path.split('/').last,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => _removeOutletAttachment(outletId, entry.key),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryCard(int outletIdx, int categoryIdx) {
    final outlet = widget.outlets[outletIdx];
    final category = outlet['categories'][categoryIdx];
    final categoryId = category['category_id'];
    final budgetInfo = _getBudgetInfo(outletIdx, categoryIdx);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header - Full Width
          SizedBox(
            width: double.infinity,
            child: _buildSearchableDropdown<int>(
              label: 'Category *',
              value: categoryId,
              items: _getFilteredCategories(),
              getValue: (item) => item['id'] as int?,
              getLabel: (item) {
                final division = item['division'] ?? item['division_name'] ?? '';
                final categoryName = item['name'] ?? '';
                return division.isNotEmpty 
                    ? '[$division] - $categoryName'
                    : categoryName;
              },
              onChanged: (value) {
                final oldCategoryId = category['category_id'];
                final outletId = outlet['outlet_id'];
                
                // Create a new category map with updated category_id
                final updatedCategory = <String, dynamic>{
                  'category_id': value,
                  'items': category['items'],
                };
                
                // Create a new categories list with updated category
                final updatedCategories = List<Map<String, dynamic>>.from(
                  (outlet['categories'] as List).asMap().entries.map((entry) {
                    if (entry.key == categoryIdx) {
                      return updatedCategory;
                    }
                    return Map<String, dynamic>.from(entry.value);
                  })
                );
                
                // Create a new outlet map with updated categories
                final updatedOutlet = <String, dynamic>{
                  'outlet_id': outlet['outlet_id'],
                  'categories': updatedCategories,
                };
                
                // Update the outlets list
                final updatedOutlets = List<Map<String, dynamic>>.from(
                  widget.outlets.asMap().entries.map((entry) {
                    if (entry.key == outletIdx) {
                      return updatedOutlet;
                    }
                    return Map<String, dynamic>.from(entry.value);
                  })
                );
                
                // Update state
                setState(() {
                  // Replace outlets with updated structure
                  widget.outlets.clear();
                  widget.outlets.addAll(updatedOutlets);
                  
                  // Clear budget info cache for old outlet-category combination
                  if (outletId != null && oldCategoryId != null) {
                    final oldKey = '$outletId-$oldCategoryId';
                    _budgetInfoCache.remove(oldKey);
                    _budgetInfoLoading.remove(oldKey);
                  }
                });
                widget.onOutletsChanged(widget.outlets);
                
                // Load budget info when category is selected
                // Use value directly instead of reading from category object
                if (value != null && outletId != null) {
                  print('🔄 Category changed to $value, loading budget info...');
                  print('🔄 outletId=$outletId, categoryId=$value');
                  // Use Future.microtask to ensure setState completes first
                  Future.microtask(() {
                    _loadBudgetInfoWithIds(outletIdx, categoryIdx, outletId, value);
                  });
                } else {
                  print('⚠️ Cannot load budget info: value=$value, outletId=$outletId');
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          
          // Total and Delete Button Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Total: ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _formatCurrency(_getCategoryTotal(outletIdx, categoryIdx)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: outlet['categories'].length > 1
                    ? () => _removeCategory(outletIdx, categoryIdx)
                    : null,
                tooltip: 'Delete Category',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          
          // Budget Info
          _buildBudgetInfoSection(outletIdx, categoryIdx),
          
          const SizedBox(height: 16),
          
          // Items Table
          _buildItemsTable(outletIdx, categoryIdx),
          
          // Add Item Button
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _addItem(outletIdx, categoryIdx),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetInfoSection(int outletIdx, int categoryIdx) {
    final outlet = widget.outlets[outletIdx];
    final category = outlet['categories'][categoryIdx];
    final outletId = outlet['outlet_id'];
    final categoryId = category['category_id'];
    
    print('🔍 _buildBudgetInfoSection: outletIdx=$outletIdx, categoryIdx=$categoryIdx');
    print('🔍 _buildBudgetInfoSection: outletId=$outletId, categoryId=$categoryId');
    print('🔍 _buildBudgetInfoSection: outlet=${outlet.keys}, category=${category.keys}');
    
    if (outletId == null || categoryId == null) {
      print('🔍 _buildBudgetInfoSection: Missing outletId or categoryId - returning empty');
      // Return empty widget - this is normal when outlet/category not yet selected
      return const SizedBox.shrink();
    }
    
    final key = '$outletId-$categoryId';
    final isLoading = _budgetInfoLoading[key] == true;
    final budgetInfo = _budgetInfoCache[key];
    
    print('🔍 _buildBudgetInfoSection: key=$key, isLoading=$isLoading, budgetInfo=${budgetInfo != null}');
    if (budgetInfo != null) {
      print('🔍 _buildBudgetInfoSection: budgetInfo keys=${budgetInfo.keys}');
    }
    
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: AppLoadingIndicator(size: 20, strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading budget information...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (budgetInfo == null) {
      print('🔍 _buildBudgetInfoSection: budgetInfo is null, returning empty');
      return const SizedBox.shrink();
    }
    
    print('✅ _buildBudgetInfoSection: Building budget info widget');
    return _buildBudgetInfo(budgetInfo);
  }

  Widget _buildBudgetInfo(Map<String, dynamic> budgetInfo) {
    final exceedsBudget = budgetInfo['exceeds_budget'] == true;
    final budgetType = budgetInfo['budget_type'] ?? 'GLOBAL';
    final isGlobalBudget = budgetType == 'GLOBAL';
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: exceedsBudget ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: exceedsBudget ? Colors.red.shade300 : Colors.green.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exceedsBudget ? Icons.warning : Icons.info_outline,
                color: exceedsBudget ? Colors.red.shade700 : Colors.green.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: exceedsBudget ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
              // Budget Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGlobalBudget ? Colors.blue.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isGlobalBudget ? Colors.blue.shade300 : Colors.orange.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  isGlobalBudget ? 'GLOBAL' : 'PER OUTLET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isGlobalBudget ? Colors.blue.shade900 : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Budget info in vertical layout (each item on separate row)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget row - use outlet_budget for PER OUTLET, category_budget for GLOBAL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    _formatCurrency(_parseDouble(
                      isGlobalBudget 
                        ? (budgetInfo['category_budget'] ?? 0)
                        : (budgetInfo['outlet_budget'] ?? budgetInfo['category_budget'] ?? 0)
                    )),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Used row - use outlet_used_amount for PER OUTLET, category_used_amount for GLOBAL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Used:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    _formatCurrency(_parseDouble(
                      isGlobalBudget
                        ? (budgetInfo['category_used_amount'] ?? 0)
                        : (budgetInfo['outlet_used_amount'] ?? budgetInfo['category_used_amount'] ?? 0)
                    )),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // After row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'After Input:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    _formatCurrency(_parseDouble(budgetInfo['total_with_current'])),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: exceedsBudget ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (exceedsBudget)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠ Budget exceeded!',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(int outletIdx, int categoryIdx) {
    final items = widget.outlets[outletIdx]['categories'][categoryIdx]['items'];
    
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            'No items yet. Click "Add Item" to add one.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Items (${items.length})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        // Items as Cards
        ...items.asMap().entries.map((entry) {
          return _buildItemCard(outletIdx, categoryIdx, entry.key);
        }),
      ],
    );
  }

  Widget _buildItemCard(int outletIdx, int categoryIdx, int itemIdx) {
    final item = widget.outlets[outletIdx]['categories'][categoryIdx]['items'][itemIdx] as Map<String, dynamic>;
    
    // Use cached controllers to prevent focus loss
    final itemNameKey = 'item_name_${outletIdx}_${categoryIdx}_${itemIdx}';
    final qtyKey = 'qty_${outletIdx}_${categoryIdx}_${itemIdx}';
    final unitKey = 'unit_${outletIdx}_${categoryIdx}_${itemIdx}';
    final priceKey = 'price_${outletIdx}_${categoryIdx}_${itemIdx}';
    
    final itemNameController = _getController(itemNameKey, item['item_name'] ?? '');
    final qtyController = _getController(qtyKey, item['qty'] != null && item['qty'] != 0 ? item['qty'].toString() : '');
    final unitController = _getController(unitKey, item['unit'] ?? '');
    
    // For price, handle empty/null values better
    final priceValue = item['unit_price'];
    final priceText = priceValue != null && priceValue != 0.0 
        ? (priceValue is double ? priceValue.toStringAsFixed(priceValue.truncateToDouble() == priceValue ? 0 : 2) : priceValue.toString())
        : '';
    final priceController = _getController(priceKey, priceText);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  _formatCurrency((item['subtotal'] as num).toDouble()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: (widget.outlets[outletIdx]['categories'][categoryIdx]['items'] as List).length > 1 
                    ? () => _removeItem(outletIdx, categoryIdx, itemIdx) 
                    : null,
                tooltip: 'Delete Item',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Item Name (Full Width)
          TextFormField(
            key: ValueKey('item_name_${outletIdx}_${categoryIdx}_${itemIdx}'),
            controller: itemNameController,
            textDirection: ui.TextDirection.ltr,
            textAlign: TextAlign.left,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-_.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Item Name *',
              hintText: 'Enter item name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(
              fontSize: 16,
              textBaseline: TextBaseline.alphabetic,
            ),
            onChanged: (value) {
              item['item_name'] = value;
              widget.onOutletsChanged(widget.outlets);
            },
          ),
          const SizedBox(height: 16),
          
          // Qty and Unit Row
          Row(
            children: [
              // Quantity
              Expanded(
                child: TextFormField(
                  key: ValueKey('qty_${outletIdx}_${categoryIdx}_${itemIdx}'),
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: ui.TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Quantity *',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      item['qty'] = null;
                    } else {
                      final qty = double.tryParse(value);
                      item['qty'] = qty;
                    }
                    _calculateSubtotal(outletIdx, categoryIdx, itemIdx);
                    widget.onOutletsChanged(widget.outlets);
                  },
                ),
              ),
              const SizedBox(width: 12),
              
              // Unit
              Expanded(
                child: TextFormField(
                  key: ValueKey('unit_${outletIdx}_${categoryIdx}_${itemIdx}'),
                  controller: unitController,
                  textDirection: ui.TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Unit *',
                    hintText: 'pcs, kg, etc',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                  onChanged: (value) {
                    item['unit'] = value;
                    widget.onOutletsChanged(widget.outlets);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Unit Price (Full Width)
          TextFormField(
            key: ValueKey('price_${outletIdx}_${categoryIdx}_${itemIdx}'),
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: ui.TextDirection.ltr,
            textAlign: TextAlign.left,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Unit Price *',
              hintText: '0',
              prefixText: 'Rp ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(
              fontSize: 16,
              textBaseline: TextBaseline.alphabetic,
            ),
            onChanged: (value) {
              // Allow empty value to clear the field
              if (value.isEmpty || value.trim().isEmpty) {
                item['unit_price'] = null;
                _calculateSubtotal(outletIdx, categoryIdx, itemIdx);
                widget.onOutletsChanged(widget.outlets);
                return;
              }
              
              // Remove non-numeric characters except decimal point
              String cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
              
              // Prevent multiple decimal points
              final parts = cleanValue.split('.');
              if (parts.length > 2) {
                cleanValue = '${parts[0]}.${parts.sublist(1).join('')}';
              }
              
              // Update controller text if sanitized (but preserve cursor position)
              if (cleanValue != value) {
                final selection = priceController.selection;
                final cursorOffset = selection.baseOffset;
                final newOffset = (cursorOffset - (value.length - cleanValue.length)).clamp(0, cleanValue.length);
                
                priceController.value = TextEditingValue(
                  text: cleanValue,
                  selection: TextSelection.collapsed(offset: newOffset),
                );
              }
              
              // Parse and store the value
              if (cleanValue.isEmpty || cleanValue == '.' || cleanValue == '0.0' || cleanValue == '0') {
                item['unit_price'] = null;
              } else {
                final price = double.tryParse(cleanValue);
                item['unit_price'] = price;
              }
              
              _calculateSubtotal(outletIdx, categoryIdx, itemIdx);
              widget.onOutletsChanged(widget.outlets);
            },
          ),
        ],
      ),
    );
  }

  // Searchable Dropdown Helper
  Widget _buildSearchableDropdown<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required T? Function(Map<String, dynamic>) getValue,
    required String Function(Map<String, dynamic>) getLabel,
    required void Function(T?) onChanged,
    bool isLoading = false,
  }) {
    String displayText = '';
    if (value != null && items.isNotEmpty) {
      try {
        final selectedItem = items.firstWhere(
          (item) => getValue(item) == value,
          orElse: () => <String, dynamic>{},
        );
        if (selectedItem.isNotEmpty) {
          displayText = getLabel(selectedItem);
        }
      } catch (e) {
        displayText = '';
      }
    }
    
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: displayText),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        hintText: isLoading ? 'Loading...' : 'Tap to search',
        suffixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      onTap: isLoading || items.isEmpty
          ? null
          : () async {
              final selected = await _showSearchableDialog<T>(
                context: context,
                title: label,
                items: items,
                getValue: getValue,
                getLabel: getLabel,
                currentValue: value,
              );
              if (selected != null && selected != value) {
                onChanged(selected);
              }
            },
    );
  }

  // Show searchable dialog
  Future<T?> _showSearchableDialog<T>({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> items,
    required T? Function(Map<String, dynamic>) getValue,
    required String Function(Map<String, dynamic>) getLabel,
    T? currentValue,
  }) async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredItems = List.from(items);
    
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Search field
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (query) {
                          setModalState(() {
                            if (query.isEmpty) {
                              filteredItems = List.from(items);
                            } else {
                              final lowerQuery = query.toLowerCase();
                              filteredItems = items.where((item) {
                                final label = getLabel(item).toLowerCase();
                                return label.contains(lowerQuery);
                              }).toList();
                            }
                          });
                        },
                      ),
                    ),
                    // List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No results found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final itemValue = getValue(item);
                                final itemLabel = getLabel(item);
                                final isSelected = itemValue == currentValue;
                                
                                return ListTile(
                                  title: Text(itemLabel),
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(context, itemValue);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

