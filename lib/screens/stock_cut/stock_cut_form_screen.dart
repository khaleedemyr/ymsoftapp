import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stock_cut_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'stock_cut_menu_cost_screen.dart';

class StockCutFormScreen extends StatefulWidget {
  const StockCutFormScreen({super.key});

  @override
  State<StockCutFormScreen> createState() => _StockCutFormScreenState();
}

class _StockCutFormScreenState extends State<StockCutFormScreen> {
  final StockCutService _service = StockCutService();
  List<Map<String, dynamic>> _outlets = [];
  int? _userIdOutlet;
  String _outletName = '';
  DateTime _selectedDate = DateTime.now();
  int? _selectedOutletId;
  String _selectedType = ''; // '', 'food', 'beverages'
  bool _loadingFormData = true;
  bool _loading = false;
  String? _loadingTask; // engineering | kebutuhan | dispatch
  Map<String, dynamic>? _statusData;
  Map<String, dynamic>? _kebutuhanData;
  Map<String, dynamic>? _engineeringData;
  bool _engineeringChecked = false;
  final Set<String> _expandedEngineering = {};
  String? _errorMsg;
  String? _successMsg;
  final Set<String> _expandedKebutuhanKeys = {};
  final Set<String> _expandedWarehouse = {};
  final Set<String> _expandedCategory = {};
  final Set<String> _expandedSubCategory = {};
  String _kebutuhanSearchQuery = '';
  Timer? _stockCutProgressTimer;
  Timer? _stockCutProgressAutoHideTimer;
  bool _showStockCutProgress = false;
  bool _stockCutProgressDone = false;
  double _stockCutProgress = 0.0;
  String _stockCutProgressLabel = '';
  DateTime? _stockCutProgressStartedAt;
  int? _stockCutProgressProcessedItems;
  int? _stockCutProgressTotalItems;
  String? _stockCutProgressPhase;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _stockCutProgressTimer?.cancel();
    _stockCutProgressAutoHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _loadingFormData = true);
    try {
      final result = await _service.getFormData();
      if (!mounted) return;
      if (result != null && result['success'] == true) {
        final outlets = result['outlets'];
        final user = result['user'];
        final rawList = outlets is List ? outlets : [];
        final list = rawList.map((e) {
          final m = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
          return {
            'id': m['id'] ?? m['id_outlet'],
            'name': m['name'] ?? m['nama_outlet'] ?? '',
          };
        }).toList();
        final idOutletRaw = user is Map ? user['id_outlet'] : null;
        final idOutlet = idOutletRaw is int ? idOutletRaw : int.tryParse(idOutletRaw?.toString() ?? '');
        setState(() {
          _outlets = List<Map<String, dynamic>>.from(list);
          _userIdOutlet = idOutlet != 0 ? idOutlet : null;
          _outletName = user is Map ? (user['outlet_name']?.toString() ?? '') : '';
          // Sama seperti web: user id_outlet != 1 (bukan pusat) → outlet tetap, tidak bisa pilih
          if (_userIdOutlet != null && _userIdOutlet != 1) {
            _selectedOutletId = _userIdOutlet;
          }
          // Admin (id_outlet == 1): tidak auto-pilih outlet; user harus pilih dari dropdown
          // _selectedOutletId tetap null sampai user pilih (dropdown hint "Pilih Outlet")
          _loadingFormData = false;
        });
        // Fallback: jika user admin (id_outlet == 1) tapi outlets kosong, load dari API outlets (sama seperti web)
        if (_userIdOutlet == 1 && _outlets.isEmpty) {
          final fallbackOutlets = await _service.getOutlets();
          if (fallbackOutlets.isNotEmpty && mounted) {
            setState(() => _outlets = fallbackOutlets);
          }
        }
        await _checkStatusSilently();
      } else {
        setState(() => _loadingFormData = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFormData = false);
    }
  }

  int? get _effectiveOutletId => _selectedOutletId ?? _userIdOutlet;
  String get _selectedDateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _checkStatusSilently() async {
    if (_effectiveOutletId == null) return;
    final result = await _service.checkStatus(
      tanggal: _selectedDateStr,
      idOutlet: _effectiveOutletId!,
      type: _selectedType.isEmpty ? null : _selectedType,
    );
    if (!mounted) return;
    setState(() => _statusData = result);
  }

  Future<void> _cekEngineering() async {
    if (_effectiveOutletId == null) {
      setState(() => _errorMsg = 'Pilih outlet');
      return;
    }
    setState(() {
      _loading = true;
      _loadingTask = 'engineering';
      _errorMsg = null;
      _successMsg = null;
      _engineeringData = null;
      _engineeringChecked = true;
      _kebutuhanData = null;
      _expandedKebutuhanKeys.clear();
      _expandedWarehouse.clear();
      _expandedCategory.clear();
      _expandedSubCategory.clear();
    });
    try {
      final status = await _service.checkStatus(
        tanggal: _selectedDateStr,
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      _statusData = status;
      final hasStockCut = status?['has_stock_cut'] == true;
      final canCut = status?['can_cut'] == true;
      if (hasStockCut && !canCut) {
        String message = 'Stock cut tidak dapat dilakukan untuk filter yang dipilih.';
        if (status?['has_all_mode'] == true) {
          message = 'Stock cut "Semua Type" sudah pernah dilakukan. Tidak dapat stock cut lagi di tanggal ini.';
        } else if (_selectedType.isEmpty) {
          if (status?['has_food_mode'] == true && status?['has_beverages_mode'] == true) {
            message = 'Stock cut Food dan Beverages sudah pernah dilakukan. Tidak dapat stock cut Semua Type.';
          } else if (status?['has_food_mode'] == true) {
            message = 'Stock cut Food sudah pernah dilakukan. Tidak dapat stock cut Semua Type.';
          } else if (status?['has_beverages_mode'] == true) {
            message = 'Stock cut Beverages sudah pernah dilakukan. Tidak dapat stock cut Semua Type.';
          }
        } else if (_selectedType == 'food' && status?['has_food_mode'] == true) {
          message = 'Stock cut Food sudah pernah dilakukan pada tanggal ini.';
        } else if (_selectedType == 'beverages' && status?['has_beverages_mode'] == true) {
          message = 'Stock cut Beverages sudah pernah dilakukan pada tanggal ini.';
        }
        setState(() {
          _loading = false;
          _loadingTask = null;
          _errorMsg = message;
        });
        return;
      }

      final result = await _service.getEngineering(
        tanggal: _selectedDateStr,
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      var engineeringResult = result;
      final eng = result?['engineering'] is Map ? result!['engineering'] as Map : const {};
      final mods = result?['modifiers'] is List ? result!['modifiers'] as List : const [];

      if (eng.isEmpty &&
          mods.isEmpty &&
          _selectedType.isNotEmpty &&
          status?['has_stock_cut'] == true &&
          (( _selectedType == 'food' && status?['has_food_mode'] != true) ||
              (_selectedType == 'beverages' && status?['has_beverages_mode'] != true))) {
        await _service.fixData(
          tanggal: _selectedDateStr,
          idOutlet: _effectiveOutletId!,
        );
        engineeringResult = await _service.getEngineering(
          tanggal: _selectedDateStr,
          idOutlet: _effectiveOutletId!,
          type: _selectedType.isEmpty ? null : _selectedType,
        );
      }
      setState(() {
        _engineeringData = engineeringResult;
        final finalEng = engineeringResult?['engineering'] is Map
            ? engineeringResult!['engineering'] as Map
            : const {};
        final finalMods = engineeringResult?['modifiers'] is List
            ? engineeringResult!['modifiers'] as List
            : const [];
        if (finalEng.isEmpty && finalMods.isEmpty) {
          _successMsg =
              'Tidak ada transaksi/menu terjual pada tanggal dan outlet yang dipilih.';
        }
        _loading = false;
        _loadingTask = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingTask = null;
        });
      }
    }
  }

  void _toggleEngineeringKey(String key) {
    setState(() {
      if (_expandedEngineering.contains(key)) {
        _expandedEngineering.remove(key);
      } else {
        _expandedEngineering.add(key);
      }
    });
  }

  Future<void> _checkStatus() async {
    if (_effectiveOutletId == null) {
      setState(() => _errorMsg = 'Pilih outlet');
      return;
    }
    setState(() {
      _loading = true;
      _loadingTask = 'engineering';
      _errorMsg = null;
      _successMsg = null;
      _statusData = null;
      _kebutuhanData = null;
    });
    try {
      final result = await _service.checkStatus(
        tanggal: _selectedDateStr,
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      setState(() {
        _statusData = result;
        _loading = false;
        _loadingTask = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingTask = null;
        });
      }
    }
  }

  Future<void> _cekKebutuhan() async {
    if (_effectiveOutletId == null) {
      setState(() => _errorMsg = 'Pilih outlet');
      return;
    }
    setState(() {
      _loading = true;
      _loadingTask = 'kebutuhan';
      _errorMsg = null;
      _successMsg = null;
      _kebutuhanData = null;
    });
    try {
      final result = await _service.cekKebutuhan(
        tanggal: _selectedDateStr,
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      setState(() {
        _kebutuhanData = result;
        _expandedKebutuhanKeys.clear();
        _kebutuhanSearchQuery = '';
        _loading = false;
        _loadingTask = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingTask = null;
        });
      }
    }
  }

  Future<void> _potongStock() async {
    if (_effectiveOutletId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potong Stock'),
        content: const Text('Yakin akan memotong stock untuk tanggal dan outlet ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );
    if (confirm != true) return;
    _startStockCutProgressPolling();
    setState(() {
      _loading = true;
      _loadingTask = 'dispatch';
      _errorMsg = null;
      _successMsg = null;
    });
    try {
      final result = await _service.dispatch(
        tanggal: _selectedDateStr,
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      final status = result?['status']?.toString();
      final message = result?['message']?.toString();
      final alreadyCut = result?['already_cut'] == true;
      final isSuccess = status == 'success';
      final errorMessage =
          message ?? (alreadyCut ? 'Stock cut sudah pernah dilakukan.' : 'Gagal memproses.');
      setState(() {
        _loading = false;
        _loadingTask = null;
        if (isSuccess) {
          _successMsg = message ?? 'Potong stock berhasil.';
          _statusData = null;
          _kebutuhanData = null;
        } else {
          _errorMsg = errorMessage;
        }
      });
      await _pollDispatchStatusOnce();
      _finishStockCutProgress(
        success: isSuccess,
        message: isSuccess ? 'Stock cut selesai.' : errorMessage,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingTask = null;
        _errorMsg = 'Gagal memproses';
      });
      _finishStockCutProgress(success: false, message: _errorMsg);
    }
  }

  bool get _canCut {
    if (_kebutuhanData == null) return false;
    final totalKurang = _kebutuhanData!['total_kurang'] is int
        ? _kebutuhanData!['total_kurang'] as int
        : int.tryParse(_kebutuhanData!['total_kurang']?.toString() ?? '0') ?? 0;
    return totalKurang == 0;
  }

  bool get _isAlreadyCut {
    if (_statusData == null) return false;
    final hasStockCut = _statusData!['has_stock_cut'] == true;
    final canCut = _statusData!['can_cut'] == true;
    if (!hasStockCut) return false;
    return !canCut;
  }

  int get _stockCutElapsedSeconds {
    if (_stockCutProgressStartedAt == null) return 0;
    return DateTime.now().difference(_stockCutProgressStartedAt!).inSeconds;
  }

  String _formatDurationShort(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    if (minutes <= 0) return '${seconds}s';
    if (minutes < 60) return '${minutes}m ${seconds}s';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return '${hours}j ${remMinutes}m';
  }

  int? get _stockCutEtaSeconds {
    if (_stockCutProgressDone) return null;
    final progress = _stockCutProgress;
    final elapsed = _stockCutElapsedSeconds;
    if (progress <= 0.03 || elapsed < 3) return null;
    final eta = (elapsed * (1 - progress) / progress).round();
    if (eta < 0) return null;
    return eta;
  }

  double _toProgressFraction(dynamic rawProgress) {
    if (rawProgress is num) {
      if (rawProgress <= 1) return rawProgress.toDouble().clamp(0.0, 1.0);
      return (rawProgress.toDouble() / 100).clamp(0.0, 1.0);
    }
    final parsed = double.tryParse(rawProgress?.toString() ?? '');
    if (parsed == null) return 0.0;
    if (parsed <= 1) return parsed.clamp(0.0, 1.0);
    return (parsed / 100).clamp(0.0, 1.0);
  }

  int? _toIntOrNull(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String? _phaseLabel(String? phase) {
    switch (phase) {
      case 'bom_calculation':
        return 'Tahap: Hitung BOM';
      case 'stock_validation':
        return 'Tahap: Validasi stok';
      case 'stock_cutting':
        return 'Tahap: Potong stok';
      case 'marking_order_items':
        return 'Tahap: Penandaan order item';
      case 'finalizing':
        return 'Tahap: Finalisasi';
      case 'completed':
        return 'Tahap: Selesai';
      default:
        return null;
    }
  }

  Future<void> _pollDispatchStatusOnce() async {
    if (_effectiveOutletId == null) return;
    final status = await _service.getDispatchStatus(
      tanggal: _selectedDateStr,
      idOutlet: _effectiveOutletId!,
      type: _selectedType.isEmpty ? null : _selectedType,
    );
    if (!mounted || status == null) return;
    final progress = _toProgressFraction(status['progress']);
    final message = status['message']?.toString() ?? 'Memproses stock cut...';
    final statusText = status['status']?.toString() ?? 'running';
    final processedItems = _toIntOrNull(status['processed_items']);
    final totalItems = _toIntOrNull(status['total_items']);
    final phase = status['phase']?.toString();
    setState(() {
      _stockCutProgress = progress;
      _stockCutProgressLabel = message;
      _stockCutProgressProcessedItems = processedItems;
      _stockCutProgressTotalItems = totalItems;
      _stockCutProgressPhase = phase;
      _stockCutProgressDone =
          statusText == 'success' || statusText == 'failed';
      if (_stockCutProgressDone && statusText == 'success') {
        _stockCutProgress = 1.0;
      }
    });
  }

  void _startStockCutProgressPolling() {
    _stockCutProgressTimer?.cancel();
    _stockCutProgressAutoHideTimer?.cancel();
    setState(() {
      _showStockCutProgress = true;
      _stockCutProgressDone = false;
      _stockCutProgress = 0.0;
      _stockCutProgressStartedAt = DateTime.now();
      _stockCutProgressLabel = 'Memulai proses stock cut...';
      _stockCutProgressProcessedItems = null;
      _stockCutProgressTotalItems = null;
      _stockCutProgressPhase = null;
    });

    _pollDispatchStatusOnce();
    _stockCutProgressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _stockCutProgressDone) return;
      _pollDispatchStatusOnce();
    });
  }

  void _finishStockCutProgress({required bool success, String? message}) {
    _stockCutProgressTimer?.cancel();
    _stockCutProgressAutoHideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _stockCutProgressDone = true;
      _stockCutProgress = success ? 1.0 : _stockCutProgress.clamp(0.0, 0.98);
      _stockCutProgressLabel = success
          ? (message ?? 'Stock cut selesai.')
          : (message ?? 'Stock cut gagal.');
      if (success) {
        _stockCutProgressPhase = 'completed';
      }
    });
    if (success) {
      _stockCutProgressAutoHideTimer =
          Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _showStockCutProgress = false;
          _stockCutProgressDone = false;
          _stockCutProgress = 0.0;
          _stockCutProgressLabel = '';
          _stockCutProgressStartedAt = null;
          _stockCutProgressProcessedItems = null;
          _stockCutProgressTotalItems = null;
          _stockCutProgressPhase = null;
        });
      });
    }
  }

  Widget _buildStockCutProgressCard() {
    final percent = (_stockCutProgress * 100).clamp(0, 100).toStringAsFixed(0);
    final etaSeconds = _stockCutEtaSeconds;
    final processed = _stockCutProgressProcessedItems;
    final total = _stockCutProgressTotalItems;
    final hasItemCounter = processed != null && total != null && total > 0;
    final phaseText = _phaseLabel(_stockCutProgressPhase);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _stockCutProgressDone
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_top_rounded,
                color:
                    _stockCutProgressDone ? Colors.green.shade700 : Colors.blue.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progress Stock Cut: $percent%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              if (!_stockCutProgressDone)
                Text(
                  '${_stockCutElapsedSeconds}s',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
            ],
          ),
          if (!_stockCutProgressDone && etaSeconds != null) ...[
            const SizedBox(height: 4),
            Text(
              'Estimasi sisa: ${_formatDurationShort(etaSeconds)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (hasItemCounter) ...[
            const SizedBox(height: 4),
            Text(
              'Proses item: $processed / $total',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (phaseText != null) ...[
            const SizedBox(height: 4),
            Text(
              phaseText,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _stockCutProgress.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white,
            valueColor: AlwaysStoppedAnimation<Color>(
              _stockCutProgressDone ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stockCutProgressLabel,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
          ),
        ],
      ),
    );
  }

  String _loadingTaskText() {
    if (_loadingTask == 'kebutuhan') return 'Sedang cek kebutuhan stock...';
    if (_loadingTask == 'engineering') return 'Sedang check engineering...';
    return 'Sedang memproses...';
  }

  Widget _buildTaskLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loadingTaskText(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 7),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFormData) {
      return AppScaffold(
        title: 'Potong Stock',
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return AppScaffold(
      title: 'Potong Stock',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report Cost Menu — pill link
            Material(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StockCutMenuCostScreen()),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 20, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text('Report Cost Menu', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tanggal
            Text('Tanggal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Material(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null && mounted) {
                    setState(() {
                      _selectedDate = date;
                      _kebutuhanData = null;
                      _engineeringData = null;
                      _engineeringChecked = false;
                      _errorMsg = null;
                      _successMsg = null;
                    });
                    await _checkStatusSilently();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Outlet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            if (_userIdOutlet != null && _userIdOutlet != 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store_rounded, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Text(_outletName.isNotEmpty ? _outletName : 'Outlet Anda', style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
                  ],
                ),
              )
            else if (_outlets.isNotEmpty)
              DropdownButtonFormField<int>(
                value: _selectedOutletId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                hint: const Text('Pilih Outlet'),
                items: _outlets.map((o) {
                  final id = o['id'] is int ? o['id'] as int : int.tryParse(o['id']?.toString() ?? '0');
                  final name = o['name']?.toString() ?? '';
                  return DropdownMenuItem<int>(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) async {
                  setState(() {
                    _selectedOutletId = v;
                    _kebutuhanData = null;
                    _engineeringData = null;
                    _engineeringChecked = false;
                    _errorMsg = null;
                    _successMsg = null;
                  });
                  await _checkStatusSilently();
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store_rounded, size: 20, color: Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Text('Daftar outlet tidak tersedia', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Text('Type Item', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: inputBorder,
                enabledBorder: inputBorder,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Semua Type (Food + Beverages)')),
                DropdownMenuItem(value: 'food', child: Text('Food')),
                DropdownMenuItem(value: 'beverages', child: Text('Beverages')),
              ],
              onChanged: (v) async {
                setState(() {
                  _selectedType = v ?? '';
                  _kebutuhanData = null;
                  _engineeringData = null;
                  _engineeringChecked = false;
                  _errorMsg = null;
                  _successMsg = null;
                });
                await _checkStatusSilently();
              },
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              onPressed: _loading ? null : _cekEngineering,
              icon: Icons.engineering_rounded,
              label: 'Cek Engineering',
              primary: false,
            ),
            if (_loading &&
                (_loadingTask == 'engineering' || _loadingTask == 'kebutuhan')) ...[
              const SizedBox(height: 10),
              _buildTaskLoadingCard(),
            ],
            if (_statusData != null && _statusData!['has_stock_cut'] == true) ...[
              const SizedBox(height: 14),
              _buildStatusCard(),
            ],
            if (_engineeringData != null) ...[
              const SizedBox(height: 14),
              _buildEngineeringSection(),
            ],
            const SizedBox(height: 14),
            _buildActionButton(
              onPressed: _loading ? null : _cekKebutuhan,
              icon: Icons.checklist_rounded,
              label: 'Cek Kebutuhan Stock Engineering',
              primary: false,
            ),
            if (_kebutuhanData != null) ...[
              const SizedBox(height: 14),
              _buildKebutuhanCard(),
            ],
            if (_canCut && !_isAlreadyCut) ...[
              const SizedBox(height: 14),
              _buildActionButton(
                onPressed: _loading ? null : _potongStock,
                icon: Icons.content_cut_rounded,
                label: 'Potong Stock Sekarang (Queue)',
                primary: true,
                accent: Colors.green,
              ),
            ],
            if (_showStockCutProgress) ...[
              const SizedBox(height: 12),
              _buildStockCutProgressCard(),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMsg!, style: TextStyle(fontSize: 14, color: Colors.red.shade800))),
                  ],
                ),
              ),
            ],
            if (_successMsg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_successMsg!, style: TextStyle(fontSize: 14, color: Colors.green.shade800))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool primary = true,
    bool loading = false,
    Color? accent,
  }) {
    final filled = primary || accent != null;
    final bgColor = accent ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: filled ? bgColor : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : Theme.of(context).colorScheme.primary))
              else
                Icon(icon, size: 22, color: filled ? Colors.white : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: filled ? Colors.white : Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngineeringSection() {
    final eng = _engineeringData!;
    final missingBom = eng['missing_bom'] is List ? eng['missing_bom'] as List : <dynamic>[];
    final missingModBom = eng['missing_modifier_bom'] is List ? eng['missing_modifier_bom'] as List : <dynamic>[];
    final modifiers = eng['modifiers'] is List ? eng['modifiers'] as List : <dynamic>[];
    final engineering = eng['engineering'] is Map ? eng['engineering'] as Map<String, dynamic> : <String, dynamic>{};

    final hasItems = engineering.isNotEmpty || modifiers.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.engineering_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Engineering (Item Terjual)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            if (!hasItems) ...[
              const SizedBox(height: 8),
              Text('Tidak ada transaksi/menu terjual pada tanggal dan outlet ini.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
            if (missingBom.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item tanpa BOM: ${missingBom.length}', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade800)),
                    ...(missingBom.map((e) {
                      final m = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• ${m['item_name']} (ID: ${m['item_id']})', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                      );
                    })),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...(engineering.entries.map((typeEntry) {
              final typeKey = typeEntry.key;
              final typeVal = typeEntry.value;
              final typeId = 'type_$typeKey';
              final isTypeOpen = _expandedEngineering.contains(typeId);
              if (typeVal is! Map) return const SizedBox.shrink();
              final catMap = typeVal as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _toggleEngineeringKey(typeId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(isTypeOpen ? Icons.expand_more : Icons.chevron_right),
                            const SizedBox(width: 8),
                            Expanded(child: Text(typeKey, style: const TextStyle(fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    ),
                    if (isTypeOpen)
                      ...(catMap.entries.map((catEntry) {
                        final catKey = catEntry.key;
                        final catVal = catEntry.value;
                        final catId = '${typeId}_$catKey';
                        final isCatOpen = _expandedEngineering.contains(catId);
                        if (catVal is! Map) return const SizedBox.shrink();
                        final subcatMap = catVal as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _toggleEngineeringKey(catId),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(isCatOpen ? Icons.expand_more : Icons.chevron_right, size: 20),
                                      const SizedBox(width: 4),
                                      Text(catKey, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey.shade800)),
                                    ],
                                  ),
                                ),
                              ),
                              if (isCatOpen)
                                ...(subcatMap.entries.map((subEntry) {
                                  final subKey = subEntry.key;
                                  final items = subEntry.value;
                                  final list = items is List ? items : [];
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(subKey, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                        const SizedBox(height: 4),
                                        ...(list.map((item) {
                                          final i = item is Map ? Map<String, dynamic>.from(item as Map) : <String, dynamic>{};
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 8, top: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(i['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
                                                Text('Qty: ${i['total_qty'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          );
                                        })),
                                      ],
                                    ),
                                  );
                                })),
                            ],
                          ),
                        );
                      })),
                  ],
                ),
              );
            })),
            if (modifiers.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Modifier Engineering', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              ...(modifiers.map((g) {
                final group = g is Map ? Map<String, dynamic>.from(g as Map) : <String, dynamic>{};
                final groupId = group['group_id']?.toString() ?? '';
                final groupName = group['group_name']?.toString() ?? 'Group';
                final modList = group['modifiers'] is List ? group['modifiers'] as List : [];
                final total = modList.fold<int>(0, (s, m) => s + ((m is Map && m['qty'] != null) ? (m['qty'] is int ? m['qty'] as int : int.tryParse(m['qty'].toString()) ?? 0) : 0));
                final modId = 'mod_$groupId';
                final isOpen = _expandedEngineering.contains(modId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _toggleEngineeringKey(modId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(isOpen ? Icons.expand_more : Icons.chevron_right),
                              const SizedBox(width: 8),
                              Expanded(child: Text('$groupName (Total: $total)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                      ),
                      if (isOpen)
                        ...(modList.map((m) {
                          final mod = m is Map ? Map<String, dynamic>.from(m as Map) : <String, dynamic>{};
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(32, 4, 12, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(mod['name']?.toString() ?? '-', style: const TextStyle(fontSize: 12)),
                                Text('Qty: ${mod['qty'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        })),
                    ],
                  ),
                );
              })),
            ],
            if (missingModBom.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                child: Text('Modifier tanpa BOM: ${missingModBom.length} item', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final hasStockCut = _statusData!['has_stock_cut'] == true;
    final canCut = _statusData!['can_cut'] == true;
    final list = (_statusData!['logs'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final successLogs = list.where((e) => e['status'] == 'success').toList();
    final failedLogs = list.where((e) => e['status'] != 'success').toList();

    if (!hasStockCut) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...successLogs.map((log) {
            final typeFilter = log['type_filter']?.toString();
            final typeName = typeFilter == 'food'
                ? 'Food'
                : (typeFilter == 'beverages' ? 'Beverages' : 'Semua Type');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Cut Sudah Dilakukan',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text('Type: $typeName', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                  Text('Total item dipotong: ${log['total_items_cut'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                  Text('Total modifier dipotong: ${log['total_modifiers_cut'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ],
              ),
            );
          }),
          ...failedLogs.map((log) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock Cut Gagal', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade800)),
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${log['error_message'] ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ),
            );
          }),
          if (!canCut)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: Text(
                _statusData!['has_all_mode'] == true
                    ? 'Stock cut "Semua Type" sudah dilakukan. Tidak bisa stock cut lagi di tanggal ini.'
                    : (_statusData!['has_food_mode'] == true &&
                            _statusData!['has_beverages_mode'] == true)
                        ? 'Stock cut Food dan Beverages sudah dilakukan. Tidak bisa stock cut lagi di tanggal ini.'
                        : (_statusData!['has_food_mode'] == true)
                            ? 'Stock cut Food sudah dilakukan. Anda masih bisa stock cut Beverages.'
                            : (_statusData!['has_beverages_mode'] == true)
                                ? 'Stock cut Beverages sudah dilakukan. Anda masih bisa stock cut Food.'
                                : 'Stock cut sudah dilakukan untuk tanggal ini.',
                style: TextStyle(fontSize: 12, color: Colors.yellow.shade900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKebutuhanCard() {
    final status = _kebutuhanData!['status']?.toString();
    final laporan = _kebutuhanData!['laporan_stock'];
    final list = laporan is List ? laporan : [];
    final totalKurang = _kebutuhanData!['total_kurang'] is int
        ? _kebutuhanData!['total_kurang'] as int
        : int.tryParse(_kebutuhanData!['total_kurang']?.toString() ?? '0') ?? 0;
    final totalCukup = _kebutuhanData!['total_cukup'] is int
        ? _kebutuhanData!['total_cukup'] as int
        : int.tryParse(_kebutuhanData!['total_cukup']?.toString() ?? '0') ?? 0;

    if (status != 'success' || list.isEmpty) {
      final msg = _kebutuhanData!['message']?.toString() ?? 'Tidak ada kebutuhan stock untuk tanggal dan outlet ini.';
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade100),
        ),
        child: Text(msg, style: TextStyle(fontSize: 14, color: Colors.amber.shade900)),
      );
    }

    final grouped = _groupKebutuhanByWarehouseCategorySubcategory(list);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(totalKurang > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: totalKurang > 0 ? Colors.orange : Colors.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    totalKurang > 0 ? 'Stock kurang ($totalKurang item)' : 'Stock cukup, siap potong',
                    style: TextStyle(fontWeight: FontWeight.w600, color: totalKurang > 0 ? Colors.orange.shade800 : Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Total dicek: ${list.length} • Cukup: $totalCukup • Kurang: $totalKurang', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _kebutuhanSearchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Cari item, kategori, atau unit...',
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: _kebutuhanSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() => _kebutuhanSearchQuery = ''),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _expandAllStockSections,
                  child: const Text('Expand All'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _collapseAllStockSections,
                  child: const Text('Collapse All'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildStockHierarchy(grouped),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniSummaryCard(
                    title: 'Total Item Dicek',
                    value: '${list.length}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniSummaryCard(
                    title: 'Stock Cukup',
                    value: '$totalCukup',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniSummaryCard(
                    title: 'Stock Kurang',
                    value: '$totalKurang',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildWarehouseSummaryCards(grouped),
          ],
        ),
      ),
    );
  }

  Widget _miniSummaryCard({
    required String title,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: color.shade700)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseSummaryCards(
    Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>> grouped,
  ) {
    if (grouped.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: grouped.entries.map((entry) {
        final warehouseItems = entry.value.values
            .expand((subMap) => subMap.values.expand((rows) => rows))
            .toList();
        final total = warehouseItems.length;
        final cukup = warehouseItems.where((e) => e['status'] == 'cukup').length;
        final kurang =
            warehouseItems.where((e) => e['status'] == 'kurang').length;
        return Container(
          width: (MediaQuery.of(context).size.width - 56) / 2,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text('Total: $total', style: const TextStyle(fontSize: 11)),
              Text(
                'Cukup: $cukup',
                style: TextStyle(fontSize: 11, color: Colors.green.shade700),
              ),
              Text(
                'Kurang: $kurang',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>
      _groupKebutuhanByWarehouseCategorySubcategory(List<dynamic> list) {
    final grouped = <String, Map<String, Map<String, List<Map<String, dynamic>>>>>{};
    for (final row in list) {
      final item = row is Map ? Map<String, dynamic>.from(row as Map) : <String, dynamic>{};
      if (!_kebutuhanItemMatchesSearch(item, _kebutuhanSearchQuery)) continue;
      final warehouse = (item['warehouse_name']?.toString().trim().isNotEmpty ?? false)
          ? item['warehouse_name'].toString().trim()
          : 'Warehouse';
      final category = (item['category_name']?.toString().trim().isNotEmpty ?? false)
          ? item['category_name'].toString().trim()
          : 'Tanpa Kategori';
      final subCategory = (item['sub_category_name']?.toString().trim().isNotEmpty ?? false)
          ? item['sub_category_name'].toString().trim()
          : 'Tanpa Sub Kategori';
      grouped.putIfAbsent(warehouse, () => {});
      grouped[warehouse]!.putIfAbsent(category, () => {});
      grouped[warehouse]![category]!.putIfAbsent(subCategory, () => []);
      grouped[warehouse]![category]![subCategory]!.add(item);
    }
    return grouped;
  }

  void _expandAllStockSections() {
    final list = (_kebutuhanData?['laporan_stock'] as List? ?? const []);
    final grouped = _groupKebutuhanByWarehouseCategorySubcategory(list);
    setState(() {
      for (final warehouseEntry in grouped.entries) {
        _expandedWarehouse.add(warehouseEntry.key);
        for (final categoryEntry in warehouseEntry.value.entries) {
          final catKey = '${warehouseEntry.key}|${categoryEntry.key}';
          _expandedCategory.add(catKey);
          for (final subEntry in categoryEntry.value.entries) {
            final subKey = '$catKey|${subEntry.key}';
            _expandedSubCategory.add(subKey);
            for (final item in subEntry.value) {
              _expandedKebutuhanKeys.add(_itemKey(item));
            }
          }
        }
      }
    });
  }

  void _collapseAllStockSections() {
    setState(() {
      _expandedWarehouse.clear();
      _expandedCategory.clear();
      _expandedSubCategory.clear();
      _expandedKebutuhanKeys.clear();
    });
  }

  Widget _buildStockHierarchy(
    Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>> grouped,
  ) {
    if (grouped.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _kebutuhanSearchQuery.isEmpty ? 'Tidak ada data laporan stock.' : 'Tidak ada item yang cocok dengan pencarian.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: grouped.entries.map((warehouseEntry) {
        final warehouseName = warehouseEntry.key;
        final isWarehouseOpen = _expandedWarehouse.contains(warehouseName);
        final warehouseItems = warehouseEntry.value.values
            .expand((subMap) => subMap.values.expand((rows) => rows))
            .toList();
        final warehouseCukup = warehouseItems.where((e) => e['status'] == 'cukup').length;
        final warehouseKurang = warehouseItems.where((e) => e['status'] == 'kurang').length;
        final warehouseHasKurang = warehouseKurang > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: warehouseHasKurang ? Colors.red.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: warehouseHasKurang ? Colors.red.shade300 : Colors.grey.shade300,
              width: warehouseHasKurang ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                onTap: () => setState(() {
                  if (isWarehouseOpen) {
                    _expandedWarehouse.remove(warehouseName);
                  } else {
                    _expandedWarehouse.add(warehouseName);
                  }
                }),
                leading: Icon(
                  isWarehouseOpen ? Icons.expand_less : Icons.expand_more,
                  color: warehouseHasKurang ? Colors.red.shade700 : null,
                ),
                title: Text(
                  '$warehouseName (${warehouseItems.length} items)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: warehouseHasKurang ? Colors.red.shade900 : null,
                  ),
                ),
                subtitle: Text(
                  '$warehouseCukup cukup • $warehouseKurang kurang',
                  style: TextStyle(
                    fontSize: 11,
                    color: warehouseHasKurang
                        ? Colors.red.shade700
                        : Colors.grey.shade700,
                    fontWeight:
                        warehouseHasKurang ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (isWarehouseOpen)
                ...warehouseEntry.value.entries.map((categoryEntry) {
                  final categoryName = categoryEntry.key;
                  final categoryKey = '$warehouseName|$categoryName';
                  final isCategoryOpen = _expandedCategory.contains(categoryKey);
                  final categoryItems =
                      categoryEntry.value.values.expand((rows) => rows).toList();
                  final categoryCukup =
                      categoryItems.where((e) => e['status'] == 'cukup').length;
                  final categoryKurang =
                      categoryItems.where((e) => e['status'] == 'kurang').length;
                  final categoryHasKurang = categoryKurang > 0;
                  return Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8, bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: categoryHasKurang
                            ? Colors.red.shade100
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: categoryHasKurang
                              ? Colors.red.shade300
                              : Colors.blue.shade200,
                          width: categoryHasKurang ? 1.3 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            onTap: () => setState(() {
                              if (isCategoryOpen) {
                                _expandedCategory.remove(categoryKey);
                              } else {
                                _expandedCategory.add(categoryKey);
                              }
                            }),
                            leading: Icon(
                              isCategoryOpen
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color:
                                  categoryHasKurang ? Colors.red.shade700 : null,
                            ),
                            title: Text(
                              '$categoryName (${categoryItems.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: categoryHasKurang
                                    ? Colors.red.shade900
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '$categoryCukup cukup • $categoryKurang kurang',
                              style: TextStyle(
                                fontSize: 10,
                                color: categoryHasKurang
                                    ? Colors.red.shade700
                                    : Colors.grey.shade700,
                                fontWeight: categoryHasKurang
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isCategoryOpen)
                            ...categoryEntry.value.entries.map((subEntry) {
                              final subName = subEntry.key;
                              final subKey = '$categoryKey|$subName';
                              final isSubOpen = _expandedSubCategory.contains(subKey);
                              final items = subEntry.value;
                              final subCukup =
                                  items.where((e) => e['status'] == 'cukup').length;
                              final subKurang =
                                  items.where((e) => e['status'] == 'kurang').length;
                              final subHasKurang = subKurang > 0;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 8, right: 6, bottom: 6),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: subHasKurang
                                        ? Colors.red.shade50
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: subHasKurang
                                          ? Colors.red.shade300
                                          : Colors.blue.shade100,
                                      width: subHasKurang ? 1.2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        onTap: () => setState(() {
                                          if (isSubOpen) {
                                            _expandedSubCategory.remove(subKey);
                                          } else {
                                            _expandedSubCategory.add(subKey);
                                          }
                                        }),
                                        leading: Icon(
                                          isSubOpen ? Icons.expand_less : Icons.expand_more,
                                          size: 18,
                                          color:
                                              subHasKurang ? Colors.red.shade700 : null,
                                        ),
                                        title: Text(
                                          '$subName (${items.length})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: subHasKurang
                                                ? Colors.red.shade900
                                                : null,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '$subCukup cukup • $subKurang kurang',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: subHasKurang
                                                ? Colors.red.shade700
                                                : Colors.grey.shade700,
                                            fontWeight: subHasKurang
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      if (isSubOpen)
                                        ...items.map(_buildStockItemRows),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockItemRows(Map<String, dynamic> item) {
    final itemName = item['item_name']?.toString() ?? '-';
    final isKurang = item['status'] == 'kurang';
    final hasMenus = (item['contributing_menus'] as List? ?? const []).isNotEmpty;
    final rowKey = _itemKey(item);
    final isExpanded = _expandedKebutuhanKeys.contains(rowKey);
    final smallNeed = _numVal(item['kebutuhan_small'] ?? item['kebutuhan']);
    final smallStock = _numVal(item['stock_tersedia_small'] ?? item['stock_tersedia']);
    final smallDiff = _numVal(item['selisih_small'] ?? item['selisih']);

    Widget unitRow({
      required String label,
      required num need,
      required num stock,
      required num diff,
      bool showStatus = false,
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 68, child: Text(_fmtQty(need), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
            SizedBox(width: 68, child: Text(_fmtQty(stock), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
            SizedBox(
              width: 78,
              child: Text(
                _fmtSelisih(diff),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: diff > 0 ? Colors.red : Colors.green.shade700),
              ),
            ),
            SizedBox(
              width: 70,
              child: showStatus
                  ? Text(
                      isKurang ? 'Kurang' : 'Cukup',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isKurang ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: isKurang ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isKurang ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            onTap: hasMenus
                ? () => setState(() {
                      if (isExpanded) {
                        _expandedKebutuhanKeys.remove(rowKey);
                      } else {
                        _expandedKebutuhanKeys.add(rowKey);
                      }
                    })
                : null,
            leading: hasMenus
                ? Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18)
                : const SizedBox(width: 18),
            title: Text(itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 500,
                child: Column(
                  children: [
                    unitRow(
                      label: '${item['unit_small_name'] ?? item['unit_name'] ?? '-'} (Small)',
                      need: smallNeed,
                      stock: smallStock,
                      diff: smallDiff,
                      showStatus: true,
                    ),
                    if (item['has_medium_unit'] == true && item['unit_medium_name'] != null)
                      unitRow(
                        label: '${item['unit_medium_name']} (Medium)',
                        need: _numVal(item['kebutuhan_medium']),
                        stock: _numVal(item['stock_tersedia_medium']),
                        diff: _numVal(item['selisih_medium']),
                      ),
                    if (item['has_large_unit'] == true && item['unit_large_name'] != null)
                      unitRow(
                        label: '${item['unit_large_name']} (Large)',
                        need: _numVal(item['kebutuhan_large']),
                        stock: _numVal(item['stock_tersedia_large']),
                        diff: _numVal(item['selisih_large']),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded && hasMenus)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu yang Mengurangi Stock',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...((item['contributing_menus'] as List? ?? const []).map((m) {
                    final menu = m is Map ? Map<String, dynamic>.from(m as Map) : <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              menu['menu_name']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            _fmtQty(_numVal(menu['total_contributed'])),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _itemKey(Map<String, dynamic> item) {
    return '${item['item_id']}-${item['warehouse_id']}-${item['unit_id']}';
  }

  bool _kebutuhanItemMatchesSearch(Map<String, dynamic> item, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final itemName = item['item_name']?.toString().toLowerCase() ?? '';
    final categoryName = item['category_name']?.toString().toLowerCase() ?? '';
    final subCategoryName = item['sub_category_name']?.toString().toLowerCase() ?? '';
    final unitName = (item['unit_small_name'] ?? item['unit_name'])?.toString().toLowerCase() ?? '';
    return itemName.contains(q) || categoryName.contains(q) || subCategoryName.contains(q) || unitName.contains(q);
  }


  double _numVal(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0;
  }

  String _fmtQty(num v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v >= 1 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  /// Format selisih agar ringkas (tidak wrap): -292371 → "-292k", 25 → "25"
  String _fmtSelisih(num v) {
    final abs = v.abs();
    final s = abs >= 1000 ? '${(abs / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k' : (abs >= 1 ? abs.toStringAsFixed(0) : abs.toStringAsFixed(2));
    return v < 0 ? '-$s' : s;
  }
}

