import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/purchase_requisition_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/pr_ops_form_widget.dart';
import '../widgets/travel_application_form_widget.dart';
import 'purchase_requisition_detail_screen.dart';

class PurchaseRequisitionCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  
  const PurchaseRequisitionCreateScreen({super.key, this.editData});

  @override
  State<PurchaseRequisitionCreateScreen> createState() => _PurchaseRequisitionCreateScreenState();
}

class _PurchaseRequisitionCreateScreenState extends State<PurchaseRequisitionCreateScreen> {
  final PurchaseRequisitionService _service = PurchaseRequisitionService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Store outlet attachments for PR Ops mode
  Map<int, List<File>> _outletAttachments = {};
  
  // Mode
  String _selectedMode = 'pr_ops';
  
  // User data
  Map<String, dynamic>? _userData;
  
  // Basic fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedDivisionId;
  int? _selectedCategoryId;
  int? _selectedOutletId;
  int? _selectedTicketId;
  String? _selectedPriority;
  String? _selectedCurrency;
  
  // For travel_application
  final _travelAgendaController = TextEditingController();
  final _travelNotesController = TextEditingController();
  List<int> _travelOutletIds = [];
  
  // For kasbon
  final _kasbonAmountController = TextEditingController();
  final _kasbonReasonController = TextEditingController();
  
  // Items (for pr_ops, purchase_payment, travel_application)
  // Structure: outlets -> categories -> items
  List<Map<String, dynamic>> _outlets = [];
  
  // Travel items
  List<Map<String, dynamic>> _travelItems = [];
  
  // Approvers
  List<Map<String, dynamic>> _approvers = [];
  List<Map<String, dynamic>> _availableApprovers = [];
  
  // Options
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _outletOptions = [];
  List<Map<String, dynamic>> _tickets = [];
  
  // Attachments (for non-pr_ops/purchase_payment)
  List<File> _attachments = [];
  final ImagePicker _imagePicker = ImagePicker();
  
  // Loading
  bool _isLoading = false;
  bool _isLoadingOptions = true;
  
  // Budget info (per outlet-category for pr_ops/purchase_payment)
  Map<String, Map<String, dynamic>> _budgetInfo = {};
  
  // Kasbon validation errors
  String? _kasbonPeriodError;
  String? _kasbonExistsError;

  // Next PR number (preview from backend - sama dengan versi web)
  String? _nextPrNumber;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndOptions();
    if (widget.editData != null) {
      _loadEditData();
    } else {
      _initializeForm();
    }
  }

  Future<void> _loadUserDataAndOptions() async {
    // Load user data first
    await _loadUserData();
    // Then load options
    _loadOptions();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userData = userData;
          // Auto-set division for kasbon mode if not already set
          if (_selectedMode == 'kasbon' && _selectedDivisionId == null) {
            final divisionId = userData['division_id'] ?? userData['id_divisi'];
            if (divisionId != null) {
              _selectedDivisionId = divisionId is int ? divisionId : (divisionId is num ? divisionId.toInt() : null);
            }
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _travelAgendaController.dispose();
    _travelNotesController.dispose();
    _kasbonAmountController.dispose();
    _kasbonReasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    // Initialize with default values based on mode
    if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
      _outlets = [
        {
          'outlet_id': null,
          'categories': [
            {
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
            }
          ],
        }
      ];
    } else if (_selectedMode == 'travel_application') {
      _travelOutletIds = [];
      _travelItems = [
        {
          'item_type': 'transport',
          'item_name': '',
          'qty': 0.0,
          'unit': '',
          'unit_price': 0.0,
          'subtotal': 0.0,
          'allowance_recipient_name': null,
          'allowance_account_number': null,
          'others_notes': null,
        }
      ];
    }
    _selectedCurrency = 'IDR';
    _selectedPriority = 'MEDIUM';
  }

  void _loadEditData() {
    // Load edit data if editing
    final data = widget.editData!;
    _selectedMode = data['mode'] ?? 'pr_ops';
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _selectedDivisionId = data['division_id'];
    _selectedCategoryId = data['category_id'];
    _selectedOutletId = data['outlet_id'];
    _selectedTicketId = data['ticket_id'];
    _selectedPriority = data['priority'];
    _selectedCurrency = data['currency'] ?? 'IDR';
    
    // Load items based on mode
    if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
      // Group items by outlet and category
      // ... (complex grouping logic)
    } else if (_selectedMode == 'travel_application') {
      // Load travel items
      // ...
    } else if (_selectedMode == 'kasbon') {
      // Load kasbon data
      // ...
    }
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final divisions = await _service.getDivisions();
      final categories = await _service.getCategories();
      final outlets = await _service.getOutlets();
      final approvers = await _service.getApprovers();

      setState(() {
        _divisions = divisions;
        _categories = categories;
        _outletOptions = outlets;
        _availableApprovers = approvers;
        _isLoadingOptions = false;
      });
      
      // Auto-set category for kasbon mode if not already set
      if (_selectedMode == 'kasbon' && _selectedCategoryId == null) {
        _autoSetKasbonCategory();
      }
      
      // Auto-set category for travel_application mode if not already set
      if (_selectedMode == 'travel_application' && _selectedCategoryId == null) {
        _autoSetTransportCategory();
      }
      
      // Load next PR number (preview) - same logic as web
      if (widget.editData == null) {
        await _loadNextPrNumber();
      }

      // Debug: Print loaded data
      print('Loaded divisions: ${_divisions.length}');
      print('Loaded outlets: ${_outletOptions.length}');
      print('Loaded categories: ${_categories.length}');
    } catch (e) {
      print('❌ Error loading options: $e');
      print('❌ Error stack: ${StackTrace.current}');
      setState(() {
        _isLoadingOptions = false;
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    print('🚀 _submitForm called');
    print('🚀 Selected mode: $_selectedMode');
    print('🚀 Current _outletAttachments state: ${_outletAttachments.length} outlets');
    for (var entry in _outletAttachments.entries) {
      print('🚀   Outlet ${entry.key}: ${entry.value.length} file(s)');
      for (var file in entry.value) {
        print('🚀     - ${file.path}');
      }
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate items based on mode
      String? validationError = _validateItems();
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Validate budget before submitting (for pr_ops and purchase_payment mode)
      if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
        String? budgetValidationError = await _validateBudget();
        if (budgetValidationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(budgetValidationError),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else if (_selectedMode != 'kasbon' && _selectedCategoryId != null) {
        // For other modes (travel_application), validate budget if category is set
        String? budgetValidationError = await _validateBudgetForCategory();
        if (budgetValidationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(budgetValidationError),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Validasi kasbon (sama dengan web): periode 10–20 bulan berjalan + cek duplikat per outlet
      if (_selectedMode == 'kasbon') {
        if (!_isWithinKasbonPeriod()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tidak dapat input kasbon di luar periode. Bisa ajukan: tanggal 10–20 bulan berjalan. Periode aktif: ${_getKasbonPeriodText()}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        if (_selectedOutletId != null) {
          final checkResult = await _service.checkKasbonPeriod(
            outletId: _selectedOutletId!,
            excludeId: widget.editData?['id'],
          );
          if (checkResult['exists'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(checkResult['message'] ?? 'Sudah ada pengajuan kasbon untuk outlet ini di periode yang sama.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      // Prepare items based on mode
      List<Map<String, dynamic>> items = [];
      
      if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
        // Flatten outlets -> categories -> items
        for (var outlet in _outlets) {
          final outletMap = outlet as Map<String, dynamic>;
          final outletId = outletMap['outlet_id'];
          if (outletId == null) continue;
          
          // Ensure outlet_id is int
          final outletIdInt = outletId is int ? outletId : (outletId is num ? outletId.toInt() : null);
          if (outletIdInt == null) continue;
          
          final categories = outletMap['categories'] as List;
          for (var category in categories) {
            final categoryMap = category as Map<String, dynamic>;
            final categoryId = categoryMap['category_id'];
            if (categoryId == null) continue;
            
            // Ensure category_id is int
            final categoryIdInt = categoryId is int ? categoryId : (categoryId is num ? categoryId.toInt() : null);
            if (categoryIdInt == null) continue;
            
            final categoryItems = categoryMap['items'] as List;
            for (var item in categoryItems) {
              final itemMap = item as Map<String, dynamic>;
              final itemName = itemMap['item_name'] as String?;
              if (itemName == null || itemName.trim().isEmpty) continue;
              
              // Ensure qty and unit_price are not null, default to 0 if null
              final qty = itemMap['qty'] ?? 0.0;
              final unitPrice = itemMap['unit_price'] ?? 0.0;
              final subtotal = itemMap['subtotal'] ?? 0.0;
              
              items.add({
                'item_name': itemName,
                'qty': qty,
                'unit': itemMap['unit'] ?? '',
                'unit_price': unitPrice,
                'subtotal': subtotal,
                'outlet_id': outletIdInt,
                'category_id': categoryIdInt,
              });
            }
          }
        }
      } else if (_selectedMode == 'travel_application') {
        // Travel items
        for (var item in _travelItems) {
          if ((item['item_name'] as String).trim().isEmpty) continue;
          items.add({
            'item_name': item['item_name'],
            'item_type': item['item_type'],
            'qty': item['qty'],
            'unit': item['unit'],
            'unit_price': item['unit_price'],
            'subtotal': item['subtotal'],
            'allowance_recipient_name': item['allowance_recipient_name'],
            'allowance_account_number': item['allowance_account_number'],
            'others_notes': item['others_notes'],
          });
        }
      } else if (_selectedMode == 'kasbon') {
        // Kasbon - single item
        items.add({
          'item_name': _kasbonReasonController.text,
          'qty': 1.0,
          'unit': 'pcs',
          'unit_price': double.tryParse(_kasbonAmountController.text) ?? 0.0,
          'subtotal': double.tryParse(_kasbonAmountController.text) ?? 0.0,
        });
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one item'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Prepare approvers - handle null values
      List<int> approverIds = _approvers
          .where((a) => a['id'] != null)
          .map((a) => a['id'] as int)
          .toList();

      // For kasbon mode, auto-set division from user data if not set
      if (_selectedMode == 'kasbon' && _selectedDivisionId == null && _userData != null) {
        final divisionId = _userData!['division_id'] ?? _userData!['id_divisi'];
        if (divisionId != null) {
          setState(() {
            _selectedDivisionId = divisionId is int ? divisionId : (divisionId is num ? divisionId.toInt() : null);
          });
        }
      }
      
      // For kasbon mode, auto-set category if not set
      if (_selectedMode == 'kasbon' && _selectedCategoryId == null && _categories.isNotEmpty) {
        _autoSetKasbonCategory();
      }
      
      // For travel_application mode, auto-set category if not set
      if (_selectedMode == 'travel_application' && _selectedCategoryId == null && _categories.isNotEmpty) {
        _autoSetTransportCategory();
      }
      
      // Validate required fields
      if (_selectedDivisionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a division'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> result;
      if (widget.editData != null) {
        result = await _service.updatePurchaseRequisition(
          id: widget.editData!['id'],
          title: _titleController.text,
          mode: _selectedMode,
          divisionId: _selectedDivisionId!,
          categoryId: _selectedCategoryId,
          outletId: _selectedOutletId,
          ticketId: _selectedTicketId,
          description: _descriptionController.text,
          priority: _selectedPriority,
          currency: _selectedCurrency,
          items: items,
          approvers: approverIds,
          travelOutletIds: _selectedMode == 'travel_application' ? _travelOutletIds : null,
          travelAgenda: _selectedMode == 'travel_application' ? _travelAgendaController.text : null,
          travelNotes: _selectedMode == 'travel_application' ? _travelNotesController.text : null,
          kasbonAmount: _selectedMode == 'kasbon' ? double.tryParse(_kasbonAmountController.text) : null,
          kasbonReason: _selectedMode == 'kasbon' ? _kasbonReasonController.text : null,
          attachments: _selectedMode != 'pr_ops' && _selectedMode != 'purchase_payment' ? _attachments : null,
        );
      } else {
        result = await _service.createPurchaseRequisition(
          title: _titleController.text,
          mode: _selectedMode,
          divisionId: _selectedDivisionId!,
          categoryId: _selectedCategoryId,
          outletId: _selectedOutletId,
          ticketId: _selectedTicketId,
          description: _descriptionController.text,
          priority: _selectedPriority,
          currency: _selectedCurrency,
          items: items,
          approvers: approverIds,
          travelOutletIds: _selectedMode == 'travel_application' ? _travelOutletIds : null,
          travelAgenda: _selectedMode == 'travel_application' ? _travelAgendaController.text : null,
          travelNotes: _selectedMode == 'travel_application' ? _travelNotesController.text : null,
          kasbonAmount: _selectedMode == 'kasbon' ? double.tryParse(_kasbonAmountController.text) : null,
          kasbonReason: _selectedMode == 'kasbon' ? _kasbonReasonController.text : null,
          attachments: _selectedMode != 'pr_ops' && _selectedMode != 'purchase_payment' ? _attachments : null,
        );
      }

      print('📋 Create/Update PR result: ${result['success']}');
      print('📋 Result keys: ${result.keys}');
      if (result['data'] != null) {
        print('📋 Result data keys: ${(result['data'] as Map).keys}');
        if (result['data'] is Map && (result['data'] as Map)['id'] != null) {
          print('📋 Result data id: ${(result['data'] as Map)['id']}');
        }
      }
      if (result['message'] != null) {
        print('📋 Result message: ${result['message']}');
      }

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        if (mounted) {
          // Safely extract PR ID from response
          int? prId;
          if (result['data'] != null) {
            final data = result['data'];
            print('📋 Extracting PR ID from data: $data');
            
            // Try multiple possible structures
            // Structure 1: data['id'] (direct)
            if (data is Map && data['id'] != null) {
              final idValue = data['id'];
              prId = idValue is int ? idValue : (idValue is num ? idValue.toInt() : null);
              print('📋 Extracted prId from data[id]: $prId');
            }
            
            // Structure 2: data['purchase_requisition']['id'] (nested)
            if (prId == null && data is Map && data['purchase_requisition'] != null) {
              final prData = data['purchase_requisition'];
              if (prData is Map && prData['id'] != null) {
                final idValue = prData['id'];
                prId = idValue is int ? idValue : (idValue is num ? idValue.toInt() : null);
                print('📋 Extracted prId from data[purchase_requisition][id]: $prId');
              }
            }
            
            if (prId == null) {
              print('⚠️ Could not extract PR ID from data structure');
            }
          } else {
            print('⚠️ result[data] is null');
          }
          
          // Fallback to editData id if available
          if (prId == null && widget.editData != null) {
            final editId = widget.editData!['id'];
            prId = editId is int ? editId : (editId is num ? editId.toInt() : null);
            print('📋 Using editData id as fallback: $prId');
          }
          
          if (prId != null) {
            // Upload attachments for PR Ops mode (per outlet)
            print('🔍 PR created successfully with ID: $prId');
            print('🔍 Selected mode: $_selectedMode');
            print('🔍 Current _outletAttachments: ${_outletAttachments.length} outlets');
            for (var entry in _outletAttachments.entries) {
              print('🔍   Outlet ${entry.key}: ${entry.value.length} file(s)');
            }
            if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
              print('🔍 Starting upload attachments for PR Ops mode...');
              await _uploadPROpsAttachments(prId!);
            } else {
              print('🔍 Skipping attachment upload (mode: $_selectedMode)');
            }
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseRequisitionDetailScreen(id: prId!),
              ),
            );
          } else {
            print('❌ ERROR: prId is null! Cannot upload attachments.');
            print('❌ Result structure: ${result.keys}');
            if (result['data'] != null) {
              print('❌ Data structure: ${(result['data'] as Map).keys}');
            }
            // If no ID, just show success message and pop
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase Requisition saved successfully, but attachment upload skipped (no PR ID)'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context);
          }
        }
      } else {
        print('❌ PR creation failed! result[success] = ${result['success']}');
        print('❌ Result: $result');
        if (mounted) {
          // Check if error is related to budget
          final errorMessage = result['message'] ?? 'Failed to save purchase requisition';
          final isBudgetError = errorMessage.toLowerCase().contains('budget') || 
                               errorMessage.toLowerCase().contains('exceed');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: isBudgetError ? Colors.red.shade700 : Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onModeChanged(String? newMode) async {
    if (newMode == null) return;
    
    setState(() {
      _selectedMode = newMode;
      // Clear kasbon errors if mode is not kasbon
      if (newMode != 'kasbon') {
        _kasbonPeriodError = null;
        _kasbonExistsError = null;
      }
      // Reset form based on mode
      _initializeForm();
      
      // Auto-set division for kasbon mode from user data
      if (newMode == 'kasbon' && _userData != null && _selectedDivisionId == null) {
        final divisionId = _userData!['division_id'] ?? _userData!['id_divisi'];
        if (divisionId != null) {
          _selectedDivisionId = divisionId is int ? divisionId : (divisionId is num ? divisionId.toInt() : null);
        }
      }
      
      // Auto-set category for kasbon mode
      if (newMode == 'kasbon' && _categories.isNotEmpty) {
        _autoSetKasbonCategory();
      }
      
      // Auto-set category for travel_application mode
      if (newMode == 'travel_application' && _categories.isNotEmpty) {
        _autoSetTransportCategory();
      }
    });
    
    // Check kasbon period if kasbon mode is selected
    // Always check period first (even without outlet), then check user per outlet if outlet is selected
    if (newMode == 'kasbon') {
      await _checkKasbonPeriod();
    }

    if (widget.editData == null) {
      await _loadNextPrNumber();
    }
  }

  Future<void> _loadNextPrNumber() async {
    final next = await _service.getNextPrNumber(mode: _selectedMode);
    if (mounted) setState(() => _nextPrNumber = next);
  }

  void _autoSetKasbonCategory() {
    // Find category that contains "kasbon" in its name (case insensitive)
    final kasbonCategory = _categories.firstWhere(
      (cat) {
        final name = (cat['name'] ?? cat['nama'] ?? '').toString().toLowerCase();
        return name.contains('kasbon');
      },
      orElse: () => <String, dynamic>{},
    );
    
    if (kasbonCategory.isNotEmpty && kasbonCategory['id'] != null) {
      setState(() {
        final categoryId = kasbonCategory['id'];
        _selectedCategoryId = categoryId is int ? categoryId : (categoryId is num ? categoryId.toInt() : null);
      });
      print('Auto-selected kasbon category: ${kasbonCategory['name'] ?? kasbonCategory['nama']} (ID: $_selectedCategoryId)');
    } else {
      print('Warning: Kasbon category not found in categories list');
    }
  }

  void _autoSetTransportCategory() {
    // Find category that contains "transport" in its name (case insensitive)
    final transportCategory = _categories.firstWhere(
      (cat) {
        final name = (cat['name'] ?? cat['nama'] ?? '').toString().toLowerCase();
        return name.contains('transport');
      },
      orElse: () => <String, dynamic>{},
    );
    
    if (transportCategory.isNotEmpty && transportCategory['id'] != null) {
      setState(() {
        final categoryId = transportCategory['id'];
        _selectedCategoryId = categoryId is int ? categoryId : (categoryId is num ? categoryId.toInt() : null);
      });
      print('Auto-selected transport category: ${transportCategory['name'] ?? transportCategory['nama']} (ID: $_selectedCategoryId)');
    } else {
      print('Warning: Transport category not found in categories list');
    }
  }

  List<Map<String, dynamic>> _getFilteredCategories() {
    // For pr_ops and purchase_payment modes, filter out categories containing "transport" and "kasbon"
    if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
      return _categories.where((cat) {
        final name = (cat['name'] ?? cat['nama'] ?? '').toString().toLowerCase();
        return !name.contains('transport') && !name.contains('kasbon');
      }).toList();
    }
    // For other modes, return all categories
    return _categories;
  }

  String? _validateItems() {
    if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment') {
      // Validate pr_ops and purchase_payment mode
      if (_outlets.isEmpty) {
        return 'Please add at least one outlet';
      }
      
      int validItemCount = 0;
      for (var outlet in _outlets) {
        if (outlet['outlet_id'] == null) {
          return 'Please select outlet for all outlet entries';
        }
        
        if (outlet['categories'].isEmpty) {
          return 'Please add at least one category for each outlet';
        }
        
        for (var category in outlet['categories']) {
          if (category['category_id'] == null) {
            return 'Please select category for all category entries';
          }
          
          if (category['items'].isEmpty) {
            return 'Please add at least one item for each category';
          }
          
          for (var item in category['items']) {
            final itemName = (item['item_name'] as String?)?.trim() ?? '';
            final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
            final unit = (item['unit'] as String?)?.trim() ?? '';
            final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
            
            if (itemName.isEmpty) {
              return 'Item name is required for all items';
            }
            
            if (qty <= 0) {
              return 'Quantity must be greater than 0 for all items';
            }
            
            if (unit.isEmpty) {
              return 'Unit is required for all items';
            }
            
            if (unitPrice <= 0) {
              return 'Unit price must be greater than 0 for all items';
            }
            
            validItemCount++;
          }
        }
      }
      
      if (validItemCount == 0) {
        return 'Please add at least one valid item';
      }
      
    } else if (_selectedMode == 'travel_application') {
      // Validate travel_application mode
      if (_travelItems.isEmpty) {
        return 'Please add at least one travel item';
      }
      
      for (var item in _travelItems) {
        final itemName = (item['item_name'] as String?)?.trim() ?? '';
        final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
        final unit = (item['unit'] as String?)?.trim() ?? '';
        final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        final itemType = item['item_type'] ?? 'transport';
        
        if (itemName.isEmpty) {
          return 'Item name is required for all travel items';
        }
        
        if (qty <= 0) {
          return 'Quantity must be greater than 0 for all travel items';
        }
        
        if (unit.isEmpty) {
          return 'Unit is required for all travel items';
        }
        
        if (unitPrice <= 0) {
          return 'Unit price must be greater than 0 for all travel items';
        }
        
        // Validate based on item type
        if (itemType == 'allowance') {
          final recipientName = (item['allowance_recipient_name'] as String?)?.trim() ?? '';
          final accountNumber = (item['allowance_account_number'] as String?)?.trim() ?? '';
          
          if (recipientName.isEmpty) {
            return 'Recipient name is required for allowance items';
          }
          
          if (accountNumber.isEmpty) {
            return 'Account number is required for allowance items';
          }
        } else if (itemType == 'others') {
          final notes = (item['others_notes'] as String?)?.trim() ?? '';
          
          if (notes.isEmpty) {
            return 'Notes is required for "others" type items';
          }
        }
      }
      
      // Validate travel outlets
      if (_travelOutletIds.isEmpty) {
        return 'Please add at least one travel destination outlet';
      }
      
      for (var outletId in _travelOutletIds) {
        if (outletId == null || outletId == 0) {
          return 'Please select outlet for all travel destinations';
        }
      }
      
    } else if (_selectedMode == 'kasbon') {
      // Kasbon validation is already handled by form validators
      // No additional item validation needed
    }
    
    return null; // No validation errors
  }

  /// Periode kasbon sama dengan web: bisa ajukan hanya tanggal 10–20 bulan berjalan.
  bool _isWithinKasbonPeriod() {
    final now = DateTime.now();
    final day = now.day;
    return day >= 10 && day <= 20;
  }

  /// Teks periode aktif (10–20 bulan berjalan) untuk tampilan.
  String _getKasbonPeriodText() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 10);
    final end = DateTime(now.year, now.month, 20);
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  Future<void> _checkKasbonPeriod() async {
    if (_selectedMode != 'kasbon') {
      setState(() {
        _kasbonPeriodError = null;
        _kasbonExistsError = null;
      });
      return;
    }

    try {
      // Bisa ajukan: tanggal 10–20 bulan berjalan (sama dengan web)
      if (!_isWithinKasbonPeriod()) {
        final periodText = _getKasbonPeriodText();

        setState(() {
          _selectedMode = 'pr_ops';
          _initializeForm();
          _kasbonPeriodError = null;
          _kasbonExistsError = null;
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                'Tidak Dapat Input Kasbon',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anda tidak dapat menginput kasbon di luar periode yang ditentukan.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periode Kasbon Aktif:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          periodText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Di-lock: 21 bulan sebelumnya s/d 9 bulan berjalan. Bisa ajukan: tanggal 10–20 bulan berjalan.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // Clear period error if within period
      setState(() {
        _kasbonPeriodError = null;
      });
      
      // Check if there's already a kasbon from another user for this outlet in the period
      // Only check if outlet is selected
      if (_selectedOutletId != null) {
        final checkResult = await _service.checkKasbonPeriod(
          outletId: _selectedOutletId!,
          excludeId: widget.editData?['id'],
        );
        
        if (checkResult['exists'] == true) {
          setState(() {
            _kasbonExistsError = checkResult['message'] ?? 'Sudah ada pengajuan kasbon untuk outlet ini di periode yang sama.';
          });
        } else {
          setState(() {
            _kasbonExistsError = null;
          });
        }
      }
    } catch (e) {
      print('Error checking kasbon period: $e');
      setState(() {
        _kasbonPeriodError = null;
        _kasbonExistsError = 'Error saat memvalidasi kasbon: $e';
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOptions) {
      return AppScaffold(
        title: widget.editData != null ? 'Edit Purchase Requisition' : 'Create Purchase Requisition',
        body: Center(child: AppLoadingIndicator()),
      );
    }

    return AppScaffold(
      title: widget.editData != null ? 'Edit Purchase Requisition' : 'Create Purchase Requisition',
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Mode Selection
            _buildModeSelection(),
            const SizedBox(height: 16),
            // Next PR number (preview from backend - sama dengan versi web)
            if (widget.editData == null && _nextPrNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tag, size: 20, color: Colors.grey.shade700),
                    const SizedBox(width: 10),
                    Text(
                      'No. PR (akan diberikan saat simpan): ',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    Text(
                      _nextPrNumber!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            // Basic Information
            _buildBasicInformation(),
            const SizedBox(height: 24),
            
            // Mode-specific forms
            if (_selectedMode == 'pr_ops' || _selectedMode == 'purchase_payment')
              _buildPROpsForm()
            else if (_selectedMode == 'travel_application')
              _buildTravelApplicationForm()
            else if (_selectedMode == 'kasbon')
              _buildKasbonForm(),
            
            const SizedBox(height: 24),
            
            // Description (for non-kasbon modes)
            if (_selectedMode != 'kasbon') _buildDescriptionSection(),
            
            const SizedBox(height: 24),
            
            // Attachments (for non-pr_ops/purchase_payment)
            if (_selectedMode != 'pr_ops' && _selectedMode != 'purchase_payment')
              _buildAttachmentsSection(),
            
            const SizedBox(height: 24),
            
            // Approvers
            _buildApproversSection(),
            
            const SizedBox(height: 32),
            
            // Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A90E2), // Lighter blue (left side of logo)
            Color(0xFF1E3A5F), // Darker blue (right side of logo)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedMode,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'pr_ops', child: Text('Purchase Requisition Ops')),
              DropdownMenuItem(value: 'purchase_payment', child: Text('Payment Application')),
              DropdownMenuItem(value: 'travel_application', child: Text('Travel Application')),
              DropdownMenuItem(value: 'kasbon', child: Text('Kasbon')),
            ],
            onChanged: widget.editData != null ? null : _onModeChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: const Color(0xFF1E3A5F)),
              const SizedBox(width: 8),
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Title
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Division
          if (_selectedMode != 'kasbon')
            _buildSearchableDropdown<int>(
              label: 'Division *',
              value: _selectedDivisionId,
              items: _divisions,
              getValue: (item) => item['id'] as int?,
              getLabel: (item) => item['nama_divisi'] ?? '',
              onChanged: (value) {
                setState(() {
                  _selectedDivisionId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Division is required';
                }
                return null;
              },
              isLoading: _isLoadingOptions || _divisions.isEmpty,
            )
          else
            // Kasbon: Auto-selected division (disabled)
            TextFormField(
              initialValue: 'Auto-selected (User Division)',
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Division',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
            ),
          const SizedBox(height: 16),
          
          // Category (only for non-pr_ops/purchase_payment modes)
          if (_selectedMode != 'pr_ops' && _selectedMode != 'purchase_payment')
            _buildCategoryField(),
          
          // Outlet (only for kasbon)
          if (_selectedMode == 'kasbon')
            _buildSearchableDropdown<int>(
              label: 'Outlet *',
              value: _selectedOutletId,
              items: _outletOptions,
              getValue: (item) => item['id_outlet'] as int?,
              getLabel: (item) => item['nama_outlet'] ?? '',
              onChanged: (value) async {
                setState(() {
                  _selectedOutletId = value;
                });
                // Check kasbon period when outlet is selected
                if (_selectedMode == 'kasbon' && value != null) {
                  await _checkKasbonPeriod();
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Outlet is required';
                }
                return null;
              },
              isLoading: _isLoadingOptions || _outletOptions.isEmpty,
            ),
          
          const SizedBox(height: 16),
          
          // Priority & Currency
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('Low')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                    DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IDR', child: Text('IDR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                  },
                ),
              ),
            ],
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
    String? Function(T?)? validator,
    bool isLoading = false,
  }) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: value != null
            ? getLabel(items.firstWhere(
                (item) => getValue(item) == value,
                orElse: () => {},
              ))
            : '',
      ),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        hintText: isLoading ? 'Loading...' : 'Tap to search',
        suffixIcon: const Icon(Icons.search),
      ),
      validator: validator != null ? (val) => validator(value) : null,
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

  Widget _buildCategoryField() {
    if (_selectedMode == 'travel_application') {
      // Auto-selected: Transport
      return TextFormField(
        initialValue: 'Transport (Auto-selected)',
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade200,
        ),
      );
    } else if (_selectedMode == 'kasbon') {
      // Auto-selected: Kasbon
      return TextFormField(
        initialValue: 'Kasbon (Auto-selected)',
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade200,
        ),
      );
    } else {
      // Searchable dropdown for other modes (pr_ops, purchase_payment)
      // Filter out categories containing "transport" and "kasbon" for these modes
      final filteredCategories = _getFilteredCategories();
      return _buildSearchableDropdown<int>(
        label: 'Category',
        value: _selectedCategoryId,
        items: filteredCategories,
        getValue: (item) => item['id'] as int?,
        getLabel: (item) {
          final division = item['division'] ?? item['division_name'] ?? '';
          final categoryName = item['name'] ?? '';
          return division.isNotEmpty 
              ? '[$division] - $categoryName'
              : categoryName;
        },
        onChanged: (value) {
          setState(() {
            _selectedCategoryId = value;
          });
        },
        isLoading: false,
      );
    }
  }

  Widget _buildPROpsForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: const Color(0xFF1E3A5F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Items (Multi-Outlet & Multi-Category)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PROpsFormWidget(
            outlets: _outlets,
            categories: _categories,
            outletOptions: _outletOptions,
            onOutletsChanged: (outlets) {
              setState(() {
                _outlets = outlets;
              });
            },
            onTotalChanged: (total) {
              // Total is calculated automatically
            },
            onAttachmentsChanged: (attachments) {
              print('📎 onAttachmentsChanged callback called');
              print('📎 Received attachments: ${attachments.length} outlets');
              for (var entry in attachments.entries) {
                print('📎   Outlet ${entry.key}: ${entry.value.length} file(s)');
                for (var file in entry.value) {
                  print('📎     - ${file.path}');
                }
              }
              setState(() {
                _outletAttachments = attachments;
              });
              print('📎 _outletAttachments updated: ${_outletAttachments.length} outlets');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTravelApplicationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TravelApplicationFormWidget(
        travelOutletIds: _travelOutletIds,
        travelItems: _travelItems,
        outletOptions: _outletOptions,
        onTravelOutletsChanged: (outlets) {
          setState(() {
            _travelOutletIds = outlets;
          });
        },
        onTravelItemsChanged: (items) {
          setState(() {
            _travelItems = items;
          });
        },
        onTotalChanged: (total) {
          // Total is calculated automatically
        },
      ),
    );
  }

  Widget _buildKasbonForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              const Text(
                'Kasbon Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Periode Aktif (sama dengan web): tampilkan saat dalam periode
          if (_kasbonPeriodError == null && _isWithinKasbonPeriod())
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Periode Aktif: ${_getKasbonPeriodText()}',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Kasbon Period Error
          if (_kasbonPeriodError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _kasbonPeriodError!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Kasbon Exists Error
          if (_kasbonExistsError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _kasbonExistsError!,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Kasbon Amount
          TextFormField(
            controller: _kasbonAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nilai Kasbon *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixText: 'Rp ',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nilai kasbon is required';
              }
              if (double.tryParse(value) == null || double.parse(value) <= 0) {
                return 'Please enter a valid amount';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Kasbon Reason
          TextFormField(
            controller: _kasbonReasonController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Reason / Alasan Kasbon *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              hintText: 'Masukkan alasan atau tujuan penggunaan kasbon...',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Reason is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    if (_selectedMode == 'travel_application') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'Agenda Kerja *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                border: Border.all(color: Colors.yellow.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.yellow.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wajib mencantumkan tanggal keberangkatan dan tanggal pulang dalam agenda kerja',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.yellow.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _travelAgendaController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Masukkan agenda kerja perjalanan dinas (bisa sangat panjang)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Agenda kerja is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _travelNotesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Masukkan catatan tambahan jika diperlukan...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter description...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAttachmentsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, color: const Color(0xFF1E3A5F)),
              const SizedBox(width: 8),
              const Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
              if (picked != null) {
                setState(() {
                  _attachments.add(File(picked.path));
                });
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Attachment'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._attachments.asMap().entries.map((entry) {
              return ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(entry.value.path.split('/').last),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _attachments.removeAt(entry.key);
                    });
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildApproversSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: const Color(0xFF1E3A5F)),
              const SizedBox(width: 8),
              const Text(
                'Approval Flow',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Add approvers in order from lowest to highest level',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showApproverPicker(),
            icon: const Icon(Icons.add),
            label: const Text('Add Approver'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (_approvers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._approvers.asMap().entries.map((entry) {
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${entry.key + 1}'),
                ),
                title: Text(entry.value['name'] ?? ''),
                subtitle: Text(entry.value['jabatan'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _approvers.removeAt(entry.key);
                    });
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
              )
            : Text(
                widget.editData != null ? 'Update Purchase Requisition' : 'Create Purchase Requisition',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<String?> _validateBudget() async {
    // Validate budget for pr_ops and purchase_payment mode (per outlet+category)
    try {
      for (var outlet in _outlets) {
        final outletMap = outlet as Map<String, dynamic>;
        final outletId = outletMap['outlet_id'];
        if (outletId == null) continue;
        
        final outletIdInt = outletId is int ? outletId : (outletId is num ? outletId.toInt() : null);
        if (outletIdInt == null) continue;
        
        final categories = outletMap['categories'] as List;
        for (var category in categories) {
          final categoryMap = category as Map<String, dynamic>;
          final categoryId = categoryMap['category_id'];
          if (categoryId == null) continue;
          
          final categoryIdInt = categoryId is int ? categoryId : (categoryId is num ? categoryId.toInt() : null);
          if (categoryIdInt == null) continue;
          
          // Calculate total amount for this outlet+category combination
          double totalAmount = 0.0;
          final categoryItems = categoryMap['items'] as List;
          for (var item in categoryItems) {
            final itemMap = item as Map<String, dynamic>;
            final itemName = itemMap['item_name'] as String?;
            if (itemName == null || itemName.trim().isEmpty) continue;
            
            final subtotal = (itemMap['subtotal'] as num?)?.toDouble() ?? 0.0;
            totalAmount += subtotal;
          }
          
          if (totalAmount > 0) {
            // Get budget info for this outlet+category
            final budgetInfo = await _service.getBudgetInfo(
              categoryId: categoryIdInt,
              outletId: outletIdInt,
              currentAmount: totalAmount,
            );
            
            if (budgetInfo != null && budgetInfo['success'] == true) {
              final exceedsBudget = budgetInfo['exceeds_budget'] == true;
              if (exceedsBudget) {
                final budgetType = budgetInfo['budget_type'] ?? 'GLOBAL';
                final budgetLimit = budgetType == 'PER_OUTLET' 
                    ? (budgetInfo['outlet_budget'] ?? budgetInfo['category_budget'] ?? 0)
                    : (budgetInfo['category_budget'] ?? 0);
                final totalWithCurrent = budgetInfo['total_with_current'] ?? 0;
                final remaining = budgetInfo['remaining_after_current'] ?? 0;
                
                return 'Budget melebihi limit untuk outlet ${outletIdInt} dan category ${categoryIdInt}!\n'
                    'Total: ${_formatCurrency(totalWithCurrent)}\n'
                    'Budget Limit: ${_formatCurrency(budgetLimit)}\n'
                    'Sisa: ${_formatCurrency(remaining)}';
              }
            }
          }
        }
      }
      
      return null; // No validation errors
    } catch (e) {
      print('Error validating budget: $e');
      return 'Error saat memvalidasi budget: $e';
    }
  }

  Future<String?> _validateBudgetForCategory() async {
    // Validate budget for other modes (travel_application) using main category
    try {
      if (_selectedCategoryId == null) return null;
      
      double totalAmount = 0.0;
      if (_selectedMode == 'travel_application') {
        for (var item in _travelItems) {
          final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
          totalAmount += subtotal;
        }
      }
      
      if (totalAmount > 0) {
        // Get budget info for this category
        final budgetInfo = await _service.getBudgetInfo(
          categoryId: _selectedCategoryId!,
          outletId: _selectedOutletId,
          currentAmount: totalAmount,
        );
        
        if (budgetInfo != null && budgetInfo['success'] == true) {
          final exceedsBudget = budgetInfo['exceeds_budget'] == true;
          if (exceedsBudget) {
            final budgetType = budgetInfo['budget_type'] ?? 'GLOBAL';
            final budgetLimit = budgetType == 'PER_OUTLET' 
                ? (budgetInfo['outlet_budget'] ?? budgetInfo['category_budget'] ?? 0)
                : (budgetInfo['category_budget'] ?? 0);
            final totalWithCurrent = budgetInfo['total_with_current'] ?? 0;
            final remaining = budgetInfo['remaining_after_current'] ?? 0;
            
            return 'Budget melebihi limit!\n'
                'Total: ${_formatCurrency(totalWithCurrent)}\n'
                'Budget Limit: ${_formatCurrency(budgetLimit)}\n'
                'Sisa: ${_formatCurrency(remaining)}';
          }
        }
      }
      
      return null; // No validation errors
    } catch (e) {
      print('Error validating budget: $e');
      return 'Error saat memvalidasi budget: $e';
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  void _showApproverPicker() async {
    if (!mounted || _availableApprovers.isEmpty) return;
    
    // Filter out already selected approvers
    final available = _availableApprovers.where((approver) {
      return !_approvers.any((a) => a['id'] == approver['id']);
    }).toList();
    
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All available approvers have been added'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Show simple dialog with list
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SimpleApproverDialog(approvers: available),
    );
    
    if (selected != null && mounted) {
      setState(() {
        _approvers.add(selected);
      });
    }
  }

  // Upload attachments for PR Ops mode (per outlet)
  Future<void> _uploadPROpsAttachments(int prId) async {
    try {
      print('📤 Starting to upload PR Ops attachments for PR ID: $prId');
      
      // Get outlet attachments from stored state
      final outletAttachments = _outletAttachments;
      print('📤 Found ${outletAttachments.length} outlets with attachments');

      if (outletAttachments.isEmpty) {
        print('ℹ️ No attachments to upload');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      // Upload attachments for each outlet
      for (var entry in outletAttachments.entries) {
        final outletId = entry.key;
        final files = entry.value;

        print('📤 Uploading ${files.length} attachment(s) for outlet ID: $outletId');

        for (var file in files) {
          try {
            print('📤 Uploading file: ${file.path}');
            final result = await _service.uploadAttachment(
              id: prId,
              file: file,
              outletId: outletId,
            );

            if (result['success'] == true) {
              successCount++;
              print('✅ Attachment uploaded successfully for outlet $outletId');
            } else {
              failCount++;
              print('❌ Failed to upload attachment for outlet $outletId: ${result['message']}');
            }
          } catch (e) {
            failCount++;
            print('❌ Error uploading attachment for outlet $outletId: $e');
          }
        }
      }

      print('📤 Upload complete: $successCount success, $failCount failed');

      if (mounted) {
        if (failCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PR created successfully, but $failCount attachment(s) failed to upload'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        } else if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PR created successfully with $successCount attachment(s)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error in _uploadPROpsAttachments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PR created successfully, but failed to upload attachments: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

// Simple approver dialog - no complex state management
class _SimpleApproverDialog extends StatefulWidget {
  final List<Map<String, dynamic>> approvers;

  const _SimpleApproverDialog({required this.approvers});

  @override
  State<_SimpleApproverDialog> createState() => _SimpleApproverDialogState();
}

class _SimpleApproverDialogState extends State<_SimpleApproverDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredApprovers = [];

  @override
  void initState() {
    super.initState();
    _filteredApprovers = widget.approvers;
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterList);
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApprovers = widget.approvers;
      } else {
        _filteredApprovers = widget.approvers.where((approver) {
          final name = (approver['name'] ?? '').toLowerCase();
          final email = (approver['email'] ?? '').toLowerCase();
          final jabatan = (approver['jabatan'] ?? '').toLowerCase();
          return name.contains(query) || email.contains(query) || jabatan.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Select Approver',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search approver...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // List
            Flexible(
              child: _filteredApprovers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No approvers found')),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredApprovers.length,
                      itemBuilder: (context, index) {
                        final approver = _filteredApprovers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text((approver['name'] ?? 'U')[0].toUpperCase()),
                          ),
                          title: Text(approver['name'] ?? ''),
                          subtitle: Text(approver['jabatan'] ?? ''),
                          onTap: () => Navigator.pop(context, approver),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

