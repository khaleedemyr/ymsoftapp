import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/floor_order_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class FloorOrderFormScreen extends StatefulWidget {
  final int? orderId;

  const FloorOrderFormScreen({super.key, this.orderId});

  @override
  State<FloorOrderFormScreen> createState() => _FloorOrderFormScreenState();
}

class _FloorOrderFormScreenState extends State<FloorOrderFormScreen> {
  final FloorOrderService _service = FloorOrderService();
  final AuthService _authService = AuthService();

  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Map<String, dynamic>? _userData;
  int? _outletId;
  int? _regionId;
  String? _outletName;

  List<Map<String, dynamic>> _warehouseOutlets = [];
  List<Map<String, dynamic>> _foSchedules = [];
  Map<String, dynamic>? _scheduleData;
  List<Map<String, dynamic>> _outletSchedules = [];
  List<Map<String, dynamic>> _itemsBySchedule = [];
  List<_CategoryGroup> _categories = [];
  final Set<int> _expandedCategoryIds = {};
  final TextEditingController _itemSearchController = TextEditingController();
  List<Map<String, dynamic>> _todaySchedules = [];
  String _todayScheduleNotes = '';

  int? _warehouseOutletId;
  int? _foScheduleId;
  String _foMode = 'RO Utama';

  final List<_FloorOrderItemInput> _items = [];

  bool _isLoading = false;
  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  bool _isCheckingSchedule = false;
  bool _isScheduleReady = false;
  bool _isLoadingItems = false;
  String? _scheduleError;
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  DateTime? _lastAutoSaveAt;

  int? _orderId;
  String? _currentStatus;
  Map<int, double> _editItemQty = {};

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _arrivalDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _items.add(_FloorOrderItemInput());
    _loadUserAndOptions();
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _arrivalDateController.dispose();
    _descriptionController.dispose();
    _itemSearchController.dispose();
    _autoSaveTimer?.cancel();
    for (final cat in _categories) {
      for (final item in cat.items) {
        item.qtyController.dispose();
        item.qtyFocusNode.dispose();
      }
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserAndOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final userData = await _authService.getUserData();
      _userData = userData;
      _outletId = userData?['id_outlet'] as int?;
      _regionId = userData?['region_id'] as int?;
        _outletName = userData?['outlet']?['nama_outlet']?.toString() ??
          userData?['outlet_name']?.toString() ??
          userData?['nama_outlet']?.toString() ??
          userData?['outlet']?['name']?.toString();

      if (_outletId != null) {
        _warehouseOutlets = await _service.getWarehouseOutletsByOutlet(_outletId!);
        _foSchedules = await _service.getFoSchedules(outletId: _outletId, regionId: _regionId);
      }

      if (widget.orderId != null) {
        await _loadEditData(widget.orderId!);
      }
    } catch (e) {
      print('Error loading user/options: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    }
  }

  Future<void> _loadEditData(int id) async {
    setState(() {
      _isLoading = true;
    });

    final data = await _service.getFloorOrder(id);
    if (!mounted) return;

    if (data != null) {
      _orderId = data['id'] as int?;
      _currentStatus = data['status']?.toString();
      _tanggalController.text = data['tanggal']?.toString() ?? _tanggalController.text;
      _arrivalDateController.text = data['arrival_date']?.toString() ?? _arrivalDateController.text;
      _descriptionController.text = data['description']?.toString() ?? '';
      _warehouseOutletId = data['warehouse_outlet_id'] as int?;
      _foScheduleId = data['fo_schedule_id'] as int?;
      _foMode = data['fo_mode']?.toString() ?? 'RO Utama';
      _outletName = data['outlet']?['nama_outlet']?.toString() ?? _outletName;

      final items = data['items'] as List<dynamic>? ?? [];
      _editItemQty = {};
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final itemId = item['item_id'] as int?;
        if (itemId != null) {
          final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
          _editItemQty[itemId] = qty;
        }
      }
      _items.clear();
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final input = _FloorOrderItemInput(
          itemId: item['item_id'] as int?,
          itemName: item['item_name']?.toString() ?? item['item']?['name']?.toString() ?? '',
          qty: item['qty']?.toString() ?? '',
          unit: item['unit']?.toString(),
          price: item['price']?.toString() ?? '0',
        );

        final units = <String>{};
        for (final unit in [
          item['unit'],
          item['item']?['small_unit']?['name'],
          item['item']?['medium_unit']?['name'],
          item['item']?['large_unit']?['name'],
        ]) {
          if (unit is String && unit.isNotEmpty) {
            units.add(unit);
          }
        }
        input.availableUnits = units.toList();
        if (input.unit == null && input.availableUnits.isNotEmpty) {
          input.unit = input.availableUnits.first;
        }
        _items.add(input);
      }
      if (_items.isEmpty) {
        _items.add(_FloorOrderItemInput());
      }
    }

    if (_orderId != null) {
      if (_foMode == 'RO Khusus') {
        await _loadItemsForKhusus();
      } else if (_foMode == 'RO Supplier') {
        await _loadItemsForSupplier();
      } else if (_foScheduleId != null) {
        await _loadItemsForSchedule(_foScheduleId!);
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _getCurrentDayName() {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[DateTime.now().weekday % 7];
  }

  String _translateDay(String day) {
    const map = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };
    return map[day] ?? day;
  }

  double _roundUpToHundred(dynamic value) {
    final price = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '0') ?? 0;
    if (price <= 0) return 0;
    return (price / 100).ceil() * 100;
  }

  Future<void> _loadOutletSchedules() async {
    if (_outletId == null) return;
    final schedules = await _service.getFoSchedules(outletId: _outletId, regionId: _regionId);
    if (!mounted) return;
    setState(() {
      _outletSchedules = schedules;
    });
  }

  Future<void> _loadTodaySchedules() async {
    final schedules = await _service.getTodayItemSchedules();
    if (!mounted) return;
    setState(() {
      _todaySchedules = schedules;
      if (_todaySchedules.isNotEmpty) {
        final names = _todaySchedules
            .map((s) => s['item_name']?.toString())
            .where((s) => s != null && s.isNotEmpty)
            .toList();
        _todayScheduleNotes = names.isNotEmpty
            ? 'Item berikut wajib diorder hari ini: ${names.join(', ')}'
            : '';
      } else {
        _todayScheduleNotes = '';
      }
    });
  }

  bool _isTodayScheduleItem(int itemId) {
    return _todaySchedules.any((s) => s['item_id'] == itemId);
  }

  List<_ScheduleItem> _filterItems(List<_ScheduleItem> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) => item.name.toLowerCase().contains(q)).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupedSchedules() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in _outletSchedules) {
      final mode = s['fo_mode']?.toString() ?? '-';
      grouped.putIfAbsent(mode, () => []);
      grouped[mode]!.add(s);
    }
    const daysOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (final mode in grouped.keys) {
      grouped[mode] = grouped[mode]!
        ..sort((a, b) {
          final da = daysOrder.indexOf(a['day']?.toString() ?? '');
          final db = daysOrder.indexOf(b['day']?.toString() ?? '');
          return da.compareTo(db);
        });
    }
    return grouped;
  }

  void _buildCategoriesFromItems(List<Map<String, dynamic>> items) {
    final Map<int, _CategoryGroup> grouped = {};
    for (final item in items) {
      final categoryId = item['category_id'] as int? ?? 0;
      final categoryName = (item['category_name']?.toString().trim().isNotEmpty ?? false)
          ? item['category_name']?.toString() ?? 'Tanpa Kategori'
          : 'Tanpa Kategori';
      grouped.putIfAbsent(
        categoryId,
        () => _CategoryGroup(id: categoryId, name: categoryName, items: []),
      );
      grouped[categoryId]!.items.add(_ScheduleItem(
        id: item['id'] as int,
        name: item['name']?.toString() ?? '-',
        unit: item['unit_medium_name']?.toString() ??
            item['unit_medium']?.toString() ??
            item['unit_small']?.toString() ??
            item['unit']?.toString() ?? '-',
        price: _roundUpToHundred(item['price'] ?? item['price_medium'] ?? 0),
        qty: 0,
      ));
    }

    _categories = grouped.values.toList();
    if (_expandedCategoryIds.isEmpty) {
      for (final cat in _categories) {
        _expandedCategoryIds.add(cat.id);
      }
    }
    _applyEditQtyToCategories();
  }

  void _applyEditQtyToCategories() {
    if (_editItemQty.isEmpty) return;
    for (final cat in _categories) {
      for (final item in cat.items) {
        final qty = _editItemQty[item.id];
        if (qty != null && qty > 0) {
          item.qty = qty;
          item.qtyController.text = qty.toString();
        }
      }
    }
  }

  Future<void> _checkSchedule() async {
    if (_warehouseOutletId == null) {
      _showMessage('Pilih warehouse outlet terlebih dahulu');
      return;
    }

    final warehouse = _warehouseOutlets.firstWhere(
      (w) => w['id'] == _warehouseOutletId,
      orElse: () => {},
    );
    final warehouseName = warehouse['name']?.toString() ?? 'Warehouse';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Warehouse'),
        content: Text('Warehouse yang dipilih: $warehouseName. Sudah benar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Benar')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isCheckingSchedule = true;
      _scheduleError = null;
      _scheduleData = null;
      _isScheduleReady = false;
      _itemsBySchedule = [];
      _categories = [];
    });

    if (_foMode == 'RO Khusus') {
      await _loadItemsForKhusus();
      return;
    }

    if (_foMode == 'RO Supplier') {
      await _loadItemsForSupplier();
      return;
    }

    if (_foMode.isEmpty) {
      setState(() {
        _isCheckingSchedule = false;
        _scheduleError = 'Silakan pilih mode RO terlebih dahulu';
      });
      return;
    }

    final scheduleRes = await _service.checkFoSchedule(
      foMode: _foMode,
      day: _getCurrentDayName(),
      outletId: _outletId,
      regionId: _regionId,
    );

    if (scheduleRes == null || scheduleRes['schedule'] == null) {
      setState(() {
        _isCheckingSchedule = false;
        _scheduleError = 'Tidak ada jadwal RO yang tersedia untuk hari ini';
      });
      await _loadOutletSchedules();
      return;
    }

    final schedule = scheduleRes['schedule'] as Map<String, dynamic>;
    if (schedule['is_active'] != true) {
      setState(() {
        _isCheckingSchedule = false;
        _scheduleError = 'Di luar jam operasional';
      });
      await _loadOutletSchedules();
      return;
    }

    if ((_foMode == 'RO Utama' || _foMode == 'RO Tambahan') && _outletId != null) {
      final exists = await _service.checkExists(
        tanggal: _tanggalController.text,
        outletId: _outletId!,
        foMode: _foMode,
        excludeId: _orderId,
        warehouseOutletId: _warehouseOutletId,
      );
      if (exists != null && exists['exists'] == true) {
        setState(() {
          _isCheckingSchedule = false;
        });
        _showMessage('RO $_foMode untuk hari ini sudah dibuat');
        return;
      }
    }

    setState(() {
      _foSchedules = [schedule];
      _foScheduleId = schedule['id'] as int?;
      _scheduleData = schedule;
      _scheduleError = null;
    });
    await _loadItemsForSchedule(_foScheduleId!);
  }

  Future<void> _loadItemsForSchedule(int scheduleId) async {
    setState(() {
      _isLoadingItems = true;
    });
    final items = await _service.getItemsBySchedule(
      scheduleId: scheduleId,
      outletId: _outletId,
      regionId: _regionId,
      excludeSupplier: true,
    );
    if (!mounted) return;
    setState(() {
      _itemsBySchedule = items;
      _buildCategoriesFromItems(items);
      _isScheduleReady = true;
      _isLoadingItems = false;
      _isCheckingSchedule = false;
    });
    await _loadTodaySchedules();
    await _createDraftIfNeeded();
  }

  Future<void> _loadItemsForKhusus() async {
    setState(() {
      _isLoadingItems = true;
    });
    final items = await _service.getItemsByFOKhusus(
      outletId: _outletId,
      regionId: _regionId,
      excludeSupplier: true,
    );
    if (!mounted) return;
    setState(() {
      _itemsBySchedule = items;
      _buildCategoriesFromItems(items);
      _isScheduleReady = true;
      _isLoadingItems = false;
      _isCheckingSchedule = false;
    });
    await _loadTodaySchedules();
    await _createDraftIfNeeded();
  }

  Future<void> _loadItemsForSupplier() async {
    final scheduleRes = await _service.checkFoSchedule(
      foMode: _foMode,
      day: _getCurrentDayName(),
      outletId: _outletId,
      regionId: _regionId,
    );

    if (scheduleRes != null && scheduleRes['schedule'] != null) {
      final schedule = scheduleRes['schedule'] as Map<String, dynamic>;
      if (schedule['is_active'] == true && schedule['id'] != null) {
        _foScheduleId = schedule['id'] as int?;
        _scheduleData = schedule;
        await _loadItemsForSchedule(_foScheduleId!);
        return;
      }
    }

    await _loadItemsForKhusus();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      _triggerAutoSave();
    }
  }

  void _addItem() {
    setState(() {
      _items.add(_FloorOrderItemInput());
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  double _parseNumber(String value) {
    return double.tryParse(value.replaceAll(',', '')) ?? 0;
  }

  double _totalAmount() {
    double total = 0;
    for (final cat in _categories) {
      for (final item in cat.items) {
        total += item.price * item.qty;
      }
    }
    return total;
  }

  int _selectedItemCount() {
    int count = 0;
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.qty > 0) count++;
      }
    }
    return count;
  }

  void _setItemQty(_ScheduleItem item, String value) {
    final cleaned = value.replaceAll(',', '.');
    final qty = double.tryParse(cleaned.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final currentCount = _selectedItemCount();
    final willIncrease = item.qty == 0 && qty > 0;

    if (_foMode == 'RO Tambahan' && willIncrease && currentCount >= 6) {
      _showMessage('Maksimal 6 item untuk RO Tambahan');
      return;
    }

    setState(() {
      item.qty = qty;
    });
    _triggerAutoSave();
  }

  void _triggerAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _autoSaveDraft();
    });
  }

  Future<void> _autoSaveDraft() async {
    if (_isSubmitting) return;
    if (!_isScheduleReady) return;
    if (_warehouseOutletId == null) return;
    if (_arrivalDateController.text.isEmpty) return;
    if (_orderId == null) {
      await _createDraftIfNeeded();
    }
    if (_orderId == null) return;

    final itemsPayload = <Map<String, dynamic>>[];
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.qty <= 0) continue;
        itemsPayload.add({
          'item_id': item.id,
          'item_name': item.name,
          'qty': item.qty,
          'unit': item.unit,
          'price': item.price,
          'subtotal': item.qty * item.price,
          'category_name': cat.name,
        });
      }
    }

    try {
      if (mounted) {
        setState(() {
          _isAutoSaving = true;
        });
      }
      await _service.updateFloorOrder(
        id: _orderId!,
        tanggal: _tanggalController.text,
        arrivalDate: _arrivalDateController.text,
        warehouseOutletId: _warehouseOutletId!,
        foMode: _foMode,
        foScheduleId: _foScheduleId,
        description: _descriptionController.text,
        items: itemsPayload,
      );
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
          _lastAutoSaveAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
      }
      return;
    }
  }

  Future<void> _openItemSearch(int index) async {
    if (_outletId == null) {
      _showMessage('Data outlet tidak ditemukan');
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FloorOrderItemSearchModal(
        outletId: _outletId!,
        regionId: _regionId,
        service: _service,
      ),
    );

    if (selected != null && mounted) {
      final units = <String>{};
      for (final unit in [
        selected['unit'],
        selected['unit_medium_name'],
        selected['unit_large'],
      ]) {
        if (unit is String && unit.isNotEmpty) {
          units.add(unit);
        }
      }

      setState(() {
        _items[index].itemId = selected['id'] as int?;
        _items[index].nameController.text = selected['name']?.toString() ?? '';
        _items[index].availableUnits = units.toList();
        _items[index].unit = _items[index].availableUnits.isNotEmpty
            ? _items[index].availableUnits.first
            : null;
        _items[index].priceController.text =
            (selected['price'] ?? selected['price_medium'] ?? 0).toString();
      });
    }
  }

  Future<void> _saveDraft() async {
    if (!_isScheduleReady) {
      _showMessage('Periksa jadwal RO terlebih dahulu');
      return;
    }
    if (_warehouseOutletId == null) {
      _showMessage('Pilih warehouse outlet');
      return;
    }
    if (_arrivalDateController.text.isEmpty) {
      _showMessage('Tanggal kedatangan wajib diisi');
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.qty <= 0) continue;
        itemsPayload.add({
          'item_id': item.id,
          'item_name': item.name,
          'qty': item.qty,
          'unit': item.unit,
          'price': item.price,
          'subtotal': item.qty * item.price,
          'category_name': cat.name,
        });
      }
    }

    if (itemsPayload.isEmpty) {
      _showMessage('Minimal pilih 1 item');
      return;
    }

    if (_foMode == 'RO Tambahan' && _selectedItemCount() > 6) {
      _showMessage('Maksimal 6 item untuk RO Tambahan');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    Map<String, dynamic> result;
    if (_orderId != null) {
      result = await _service.updateFloorOrder(
        id: _orderId!,
        tanggal: _tanggalController.text,
        arrivalDate: _arrivalDateController.text,
        warehouseOutletId: _warehouseOutletId!,
        foMode: _foMode,
        foScheduleId: _foScheduleId,
        description: _descriptionController.text,
        items: itemsPayload,
      );
    } else {
      result = await _service.createFloorOrder(
        tanggal: _tanggalController.text,
        arrivalDate: _arrivalDateController.text,
        warehouseOutletId: _warehouseOutletId!,
        foMode: _foMode,
        foScheduleId: _foScheduleId,
        description: _descriptionController.text,
        items: itemsPayload,
      );
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      if (_orderId == null) {
        final data = result['data'];
        if (data is Map && data['floor_order_id'] != null) {
          _orderId = data['floor_order_id'] as int?;
        }
      }
      _showMessage('Draft berhasil disimpan', success: true);
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal menyimpan draft');
    }
  }

  Future<void> _submit() async {
    if (!_isScheduleReady) {
      _showMessage('Periksa jadwal RO terlebih dahulu');
      return;
    }
    if (_orderId == null) return;
    if (_orderId == null) {
      _showMessage('Draft Order belum tersimpan. Silakan tunggu beberapa detik.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Kirim RO'),
        content: const Text('Setelah dikirim, RO tidak dapat diubah. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Kirim')),
        ],
      ),
    );

    if (confirm != true) return;

    if (_outletId != null && (_foMode == 'RO Utama' || _foMode == 'RO Tambahan')) {
      final exists = await _service.checkExists(
        tanggal: _tanggalController.text,
        outletId: _outletId!,
        foMode: _foMode,
        excludeId: _orderId,
        warehouseOutletId: _warehouseOutletId,
      );

      if (exists != null && exists['exists'] == true) {
        _showMessage('RO dengan tanggal & outlet ini sudah ada');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await _service.submitFloorOrder(_orderId!);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      _showMessage('RO berhasil dikirim', success: true);
      Navigator.pop(context, true);
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal submit RO');
    }
  }

  Future<bool> _handleWillPop() async {
    _autoSaveTimer?.cancel();

    if (_isSubmitting) return false;
    if (!_isScheduleReady) return true;
    if (_selectedItemCount() == 0) return true;
    if (_warehouseOutletId == null) return true;
    if (_arrivalDateController.text.isEmpty) return true;

    if (_orderId == null) {
      await _createDraftIfNeeded();
    }

    await _autoSaveDraft();
    return true;
  }

  Future<void> _createDraftIfNeeded() async {
    if (_isSubmitting) return;
    if (_orderId != null) return;
    if (!_isScheduleReady) return;
    if (_warehouseOutletId == null) return;
    if (_arrivalDateController.text.isEmpty) return;

    final itemsPayload = <Map<String, dynamic>>[];
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.qty <= 0) continue;
        itemsPayload.add({
          'item_id': item.id,
          'item_name': item.name,
          'qty': item.qty,
          'unit': item.unit,
          'price': item.price,
          'subtotal': item.qty * item.price,
          'category_name': cat.name,
        });
      }
    }

    try {
      final result = await _service.createFloorOrder(
        tanggal: _tanggalController.text,
        arrivalDate: _arrivalDateController.text,
        warehouseOutletId: _warehouseOutletId!,
        foMode: _foMode,
        foScheduleId: _foScheduleId,
        description: _descriptionController.text,
        items: itemsPayload,
      );

      if (result['data'] is Map) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['floor_order_id'] != null) {
          _orderId = data['floor_order_id'] as int?;
        }
      }
    } catch (e) {
      return;
    }
  }

  Future<void> _openSubmitPreview() async {
    if (!_isScheduleReady) {
      _showMessage('Periksa jadwal RO terlebih dahulu');
      return;
    }
    if (_warehouseOutletId == null) {
      _showMessage('Pilih warehouse outlet');
      return;
    }
    if (_arrivalDateController.text.isEmpty) {
      _showMessage('Tanggal kedatangan wajib diisi');
      return;
    }
    if (_selectedItemCount() == 0) {
      _showMessage('Minimal pilih 1 item');
      return;
    }
    if (_foMode == 'RO Tambahan' && _selectedItemCount() > 6) {
      _showMessage('Maksimal 6 item untuk RO Tambahan');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.qty <= 0) continue;
        items.add({
          'name': item.name,
          'unit': item.unit,
          'qty': item.qty,
          'price': item.price,
          'subtotal': item.price * item.qty,
          'category': cat.name,
        });
      }
    }

    final previewCats = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final cat = item['category']?.toString() ?? 'Tanpa Kategori';
      previewCats.putIfAbsent(cat, () => []);
      previewCats[cat]!.add(item);
    }
    final previewExpandedCats = <String>{...previewCats.keys};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Preview RO',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        _previewRow('Outlet', _outletName ?? '-'),
                        _previewRow(
                          'Warehouse',
                          _warehouseOutlets.firstWhere(
                            (w) => w['id'] == _warehouseOutletId,
                            orElse: () => {},
                          )['name']?.toString() ?? '-',
                        ),
                        _previewRow('Mode', _foMode),
                        _previewRow('Tanggal', _tanggalController.text),
                        _previewRow('Tanggal Datang', _arrivalDateController.text),
                        if (_descriptionController.text.trim().isNotEmpty)
                          _previewRow('Deskripsi', _descriptionController.text.trim()),
                        const SizedBox(height: 12),
                        StatefulBuilder(
                          builder: (context, setModalState) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    const Text('Item', style: TextStyle(fontWeight: FontWeight.w700)),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        setModalState(() {
                                          previewExpandedCats.addAll(previewCats.keys);
                                        });
                                      },
                                      child: const Text('Expand All'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setModalState(() {
                                          previewExpandedCats.clear();
                                        });
                                      },
                                      child: const Text('Collapse All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...previewCats.entries.map((entry) {
                                  final catName = entry.key;
                                  final catItems = entry.value;
                                  final catTotal = catItems.fold<double>(
                                    0,
                                    (sum, item) => sum + ((item['subtotal'] as num?)?.toDouble() ?? 0),
                                  );
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: ExpansionTile(
                                      initiallyExpanded: previewExpandedCats.contains(catName),
                                      onExpansionChanged: (value) {
                                        setModalState(() {
                                          if (value) {
                                            previewExpandedCats.add(catName);
                                          } else {
                                            previewExpandedCats.remove(catName);
                                          }
                                        });
                                      },
                                      title: Text(
                                        '$catName (Rp ${NumberFormat('#,###').format(catTotal)})',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      children: catItems.map((item) {
                                        return Container(
                                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['name']?.toString() ?? '-',
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${item['qty']} ${item['unit']} • Rp ${NumberFormat('#,###').format(item['price'])}',
                                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                'Rp ${NumberFormat('#,###').format(item['subtotal'])}',
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                              'Rp ${NumberFormat('#,###').format(_totalAmount())}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              await _saveDraft();
                              if (mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Draft'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: const Color(0xFF1D4ED8),
                        side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _submit();
                            },
                      icon: const Icon(Icons.send),
                      label: const Text('Submit RO'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                        shadowColor: const Color(0x664F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildHeaderSection() {
    final autoSaveText = _isAutoSaving
        ? 'Autosaving...'
        : _lastAutoSaveAt == null
            ? ''
            : 'Autosaved ${DateFormat('HH:mm:ss').format(_lastAutoSaveAt!)}';
    return _buildGlassCard(
      child: Column(
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Outlet',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_outletName ?? '-'),
          ),
          if (autoSaveText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                autoSaveText,
                style: TextStyle(
                  color: _isAutoSaving ? Colors.orange.shade700 : Colors.green.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildDateField('Tanggal', _tanggalController, () => _selectDate(_tanggalController)),
          const SizedBox(height: 12),
          _buildDateField('Tanggal Kedatangan', _arrivalDateController, () => _selectDate(_arrivalDateController)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _warehouseOutletId,
            decoration: InputDecoration(
              labelText: 'Warehouse Outlet',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _warehouseOutlets.map((wh) {
              return DropdownMenuItem<int>(
                value: wh['id'] as int?,
                child: Text(wh['name']?.toString() ?? '-'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _warehouseOutletId = value;
              });
              _triggerAutoSave();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _foMode,
            decoration: InputDecoration(
              labelText: 'Mode RO',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'RO Utama', child: Text('RO Utama')),
              DropdownMenuItem(value: 'RO Tambahan', child: Text('RO Tambahan')),
              DropdownMenuItem(value: 'RO Pengambilan', child: Text('RO Pengambilan')),
              DropdownMenuItem(value: 'RO Khusus', child: Text('RO Khusus')),
              DropdownMenuItem(value: 'RO Supplier', child: Text('RO Supplier')),
            ],
            onChanged: (value) {
              setState(() {
                _foMode = value ?? 'RO Utama';
                _isScheduleReady = false;
                _scheduleError = null;
                _scheduleData = null;
                _itemsBySchedule = [];
                _categories = [];
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _foScheduleId,
            decoration: InputDecoration(
              labelText: 'RO Schedule',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _foSchedules.map((item) {
              final label = item['name']?.toString() ?? item['title']?.toString() ?? 'Schedule';
              return DropdownMenuItem<int>(
                value: item['id'] as int?,
                child: Text(label),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _foScheduleId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Deskripsi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _triggerAutoSave(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: _isCheckingSchedule ? null : _checkSchedule,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Periksa Jadwal RO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              minimumSize: const Size(double.infinity, 48),
              elevation: 6,
              shadowColor: const Color(0x661D4ED8),
            ),
          ),
          if (_scheduleError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _scheduleError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
          if (_outletSchedules.isNotEmpty && _scheduleError != null) ...[
            const SizedBox(height: 12),
            Text('Jadwal RO Outlet Anda:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._groupedSchedules().entries.map((entry) {
              final mode = entry.key;
              final schedules = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    const SizedBox(height: 4),
                    ...schedules.map((s) {
                      final day = _translateDay(s['day']?.toString() ?? '-');
                      final open = s['open_time']?.toString() ?? '-';
                      final close = s['close_time']?.toString() ?? '-';
                      return Text('$day: $open - $close');
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
          if (_isCheckingSchedule || _isLoadingItems) ...[
            const SizedBox(height: 12),
            const Center(child: AppLoadingIndicator()),
          ],
          if (_isScheduleReady && !_isLoadingItems) ...[
            if (_foMode == 'RO Tambahan') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Notes: Hanya dapat order 6 item'),
              ),
            ],
            if (_todayScheduleNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_todayScheduleNotes),
              ),
            ],
            if (_foMode == 'RO Supplier' && _itemsBySchedule.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Info Jadwal RO Supplier: ${_itemsBySchedule.length} item tersedia sesuai jadwal hari ini.'),
              ),
            ],
            const SizedBox(height: 12),
            if (_categories.isNotEmpty) ...[
              Row(
                children: [
                  const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final cat in _categories) {
                          _expandedCategoryIds.add(cat.id);
                        }
                      });
                    },
                    child: const Text('Expand All'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _expandedCategoryIds.clear();
                      });
                    },
                    child: const Text('Collapse All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            ..._categories.map((cat) {
              final isExpanded = _expandedCategoryIds.contains(cat.id);
              final filteredItems = _filterItems(cat.items, _itemSearchController.text);
              final subtotal = cat.items.fold<double>(0, (sum, item) => sum + (item.price * item.qty));
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedCategoryIds.remove(cat.id);
                          } else {
                            _expandedCategoryIds.add(cat.id);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${cat.name} (Rp ${NumberFormat('#,###').format(subtotal)})',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                            Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: filteredItems.isEmpty
                            ? Text('Tidak ada item', style: TextStyle(color: Colors.grey.shade600))
                            : Column(
                                children: filteredItems.map((item) {
                                  final highlight = _isTodayScheduleItem(item.id);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: highlight ? Colors.lime.shade50 : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: highlight ? Colors.lime.shade300 : Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(item.name),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            item.unit,
                                            style: TextStyle(color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            'Rp ${NumberFormat('#,###').format(item.price)}',
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 74,
                                          child: Focus(
                                            onFocusChange: (hasFocus) {
                                              if (!hasFocus) return;
                                              item.qtyController.selection = TextSelection(
                                                baseOffset: 0,
                                                extentOffset: item.qtyController.text.length,
                                              );
                                            },
                                            child: TextField(
                                              focusNode: item.qtyFocusNode,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                              textAlign: TextAlign.center,
                                              controller: item.qtyController,
                                              inputFormatters: [
                                                TextInputFormatter.withFunction((oldValue, newValue) {
                                                  final text = newValue.text;
                                                  if (text.isEmpty) return newValue;
                                                  final isValid = RegExp(r'^\d*([\.,]\d{0,2})?$').hasMatch(text);
                                                  return isValid ? newValue : oldValue;
                                                }),
                                              ],
                                              onTap: () {
                                                if (item.qtyController.text.isNotEmpty) {
                                                  item.qtyController.text = '';
                                                  item.qty = 0;
                                                }
                                                item.qtyController.selection = const TextSelection(
                                                  baseOffset: 0,
                                                  extentOffset: 0,
                                                );
                                              },
                                              onChanged: (value) => _setItemQty(item, value),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 95,
                                          child: Text(
                                            'Rp ${NumberFormat('#,###').format(item.price * item.qty)}',
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final total = _totalAmount();
    return Column(
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Total', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    'Rp ${NumberFormat('#,###').format(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _saveDraft,
            icon: const Icon(Icons.save),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: const Color(0xFF1D4ED8),
              side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            label: const Text(
              'Simpan Draft',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _openSubmitPreview,
            icon: const Icon(Icons.send),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 8,
              shadowColor: const Color(0x664F46E5),
            ),
            label: const Text(
              'Submit RO',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(controller.text),
      ),
    );
  }

  Widget _buildAnimatedSection({required Widget child, required int index}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, innerChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: innerChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF8FFFFFF), Color(0xF2F8FAFF)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBackgroundLayer() {
    return Positioned.fill(
      child: Stack(
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
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFDBEAFE), Color(0xFFD1FAE5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 40,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFE0E7FF), Color(0xFFFCE7F3)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 50,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    if (!_isScheduleReady || _isLoadingItems) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _itemSearchController,
        decoration: InputDecoration(
          hintText: 'Cari item... (tetap terlihat)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _itemSearchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _itemSearchController.clear();
                    setState(() {});
                  },
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildHeroBanner() {
    final title = widget.orderId != null ? 'Edit Request Order' : 'Buat Request Order';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_graph, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buat RO lebih cepat, akurat, dan nyaman',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'RO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: AppScaffold(
        title: widget.orderId != null ? 'Edit Request Order' : 'Buat Request Order',
        showDrawer: false,
        body: _isLoadingOptions
            ? const Center(child: AppLoadingIndicator())
            : _isLoading
                ? const Center(child: AppLoadingIndicator())
                : Stack(
                    children: [
                      _buildBackgroundLayer(),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        child: Column(
                          children: [
                            _buildAnimatedSection(child: _buildHeroBanner(), index: 0),
                            const SizedBox(height: 16),
                            _buildAnimatedSection(child: _buildHeaderSection(), index: 1),
                            const SizedBox(height: 16),
                            _buildAnimatedSection(child: _buildItemsSection(), index: 2),
                            const SizedBox(height: 16),
                            _buildAnimatedSection(child: _buildSummarySection(), index: 3),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _buildFloatingSearchBar(),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _FloorOrderItemInput {
  int? itemId;
  String? unit;
  List<String> availableUnits = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  _FloorOrderItemInput({
    this.itemId,
    String? itemName,
    String? qty,
    String? unit,
    String? price,
  }) {
    nameController.text = itemName ?? '';
    qtyController.text = qty ?? '';
    priceController.text = price ?? '';
    this.unit = unit;
  }

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _CategoryGroup {
  final int id;
  final String name;
  final List<_ScheduleItem> items;

  _CategoryGroup({
    required this.id,
    required this.name,
    required this.items,
  });
}

class _ScheduleItem {
  final int id;
  final String name;
  final String unit;
  final double price;
  double qty;
  final TextEditingController qtyController = TextEditingController();
  final FocusNode qtyFocusNode = FocusNode();

  _ScheduleItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.qty,
  }) {
    qtyController.text = qty == 0 ? '' : qty.toString();
  }
}

class _FloorOrderItemSearchModal extends StatefulWidget {
  final int outletId;
  final int? regionId;
  final FloorOrderService service;

  const _FloorOrderItemSearchModal({
    required this.outletId,
    required this.regionId,
    required this.service,
  });

  @override
  State<_FloorOrderItemSearchModal> createState() => _FloorOrderItemSearchModalState();
}

class _FloorOrderItemSearchModalState extends State<_FloorOrderItemSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search();
    });
  }

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final result = await widget.service.searchItems(
      query: _searchController.text.trim(),
      outletId: widget.outletId,
      regionId: widget.regionId,
    );

    if (!mounted) return;

    setState(() {
      _results = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari item...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _onSearchChanged(),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          if (_isLoading) const AppLoadingIndicator(),
          if (!_isLoading)
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada item',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          title: Text(item['name']?.toString() ?? ''),
                          subtitle: Text(item['sku']?.toString() ?? ''),
                          trailing: Text(
                            'Rp ${NumberFormat('#,###').format(item['price'] ?? 0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
