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
  Map<String, dynamic>? _statusData;
  Map<String, dynamic>? _kebutuhanData;
  Map<String, dynamic>? _engineeringData;
  bool _engineeringChecked = false;
  final Set<String> _expandedEngineering = {};
  String? _errorMsg;
  String? _successMsg;
  final Set<String> _expandedKebutuhanKeys = {};
  String _kebutuhanSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFormData();
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
      } else {
        setState(() => _loadingFormData = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFormData = false);
    }
  }

  int? get _effectiveOutletId => _selectedOutletId ?? _userIdOutlet;

  Future<void> _cekEngineering() async {
    if (_effectiveOutletId == null) {
      setState(() => _errorMsg = 'Pilih outlet');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
      _engineeringData = null;
      _engineeringChecked = true;
    });
    try {
      final result = await _service.getEngineering(
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      setState(() {
        _engineeringData = result;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      _errorMsg = null;
      _successMsg = null;
      _statusData = null;
      _kebutuhanData = null;
    });
    try {
      final result = await _service.checkStatus(
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      setState(() {
        _statusData = result;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cekKebutuhan() async {
    if (_effectiveOutletId == null) {
      setState(() => _errorMsg = 'Pilih outlet');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
      _successMsg = null;
      _kebutuhanData = null;
    });
    try {
      final result = await _service.cekKebutuhan(
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      setState(() {
        _kebutuhanData = result;
        _expandedKebutuhanKeys.clear();
        _kebutuhanSearchQuery = '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    setState(() {
      _loading = true;
      _errorMsg = null;
      _successMsg = null;
    });
    try {
      final result = await _service.dispatch(
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        idOutlet: _effectiveOutletId!,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      if (!mounted) return;
      final status = result?['status']?.toString();
      final message = result?['message']?.toString();
      final alreadyCut = result?['already_cut'] == true;
      setState(() {
        _loading = false;
        if (status == 'success') {
          _successMsg = message ?? 'Potong stock berhasil.';
          _statusData = null;
          _kebutuhanData = null;
        } else {
          _errorMsg = message ?? (alreadyCut ? 'Stock cut sudah pernah dilakukan.' : 'Gagal memproses.');
        }
      });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _errorMsg = 'Gagal memproses';
      });
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
                  if (date != null && mounted) setState(() => _selectedDate = date);
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
                onChanged: (v) => setState(() => _selectedOutletId = v),
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
              onChanged: (v) => setState(() => _selectedType = v ?? ''),
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              onPressed: _loading ? null : _cekEngineering,
              icon: Icons.engineering_rounded,
              label: 'Cek Engineering',
              primary: false,
            ),
            if (_engineeringData != null) ...[
              const SizedBox(height: 14),
              _buildEngineeringSection(),
            ],
            const SizedBox(height: 14),
            _buildActionButton(
              onPressed: _loading ? null : _checkStatus,
              icon: Icons.info_outline_rounded,
              label: 'Cek Status Stock Cut',
              primary: true,
              loading: _loading,
            ),
            if (_statusData != null) ...[
              const SizedBox(height: 14),
              _buildStatusCard(),
            ],
            const SizedBox(height: 14),
            _buildActionButton(
              onPressed: _loading ? null : _cekKebutuhan,
              icon: Icons.checklist_rounded,
              label: 'Cek Kebutuhan Stock',
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
                label: 'Potong Stock Sekarang',
                primary: true,
                accent: Colors.green,
              ),
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
    final logs = _statusData!['logs'];
    final list = logs is List ? logs : [];

    if (!hasStockCut) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 22),
            const SizedBox(width: 12),
            const Expanded(child: Text('Belum ada stock cut untuk tanggal dan outlet ini. Anda bisa lanjut Cek Kebutuhan lalu Potong Stock.', style: TextStyle(fontSize: 14))),
          ],
        ),
      );
    }

    String message = 'Stock cut sudah pernah dilakukan untuk tanggal ini.';
    if (!canCut && list.isNotEmpty) {
      final first = list.first is Map ? list.first as Map : null;
      final typeFilter = first?['type_filter'];
      String typeName = 'Semua';
      if (typeFilter == 'food') typeName = 'Food';
      if (typeFilter == 'beverages') typeName = 'Beverages';
      message = 'Stock cut ($typeName) sudah pernah dilakukan. Tidak dapat potong lagi untuk type yang sama.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: TextStyle(fontSize: 14, color: Colors.orange.shade900))),
            ],
          ),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Total item dipotong: ${list.first is Map ? (list.first as Map)['total_items_cut'] ?? '-' : '-'}',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
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
            // Detail per item: search + grouping per category + expand per item
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              title: Text('Detail per item (${list.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              children: [
                // Search
                TextField(
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
                const SizedBox(height: 10),
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                      SizedBox(width: 52, child: Text('Butuh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700), textAlign: TextAlign.right)),
                      SizedBox(width: 52, child: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700), textAlign: TextAlign.right)),
                      SizedBox(width: 58, child: Text('Selisih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700), textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      SizedBox(width: 58, child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _buildKebutuhanGroupedList(list),
              ],
            ),
          ],
        ),
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

  Widget _buildKebutuhanGroupedList(List<dynamic> list) {
    final filtered = list.where((e) {
      final item = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
      return _kebutuhanItemMatchesSearch(item, _kebutuhanSearchQuery);
    }).toList();

    final Map<String, List<dynamic>> byCategory = {};
    for (final e in filtered) {
      final item = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
      final catStr = item['category_name']?.toString() ?? '';
      final cat = catStr.trim().isEmpty ? 'Tanpa Kategori' : catStr.trim();
      byCategory.putIfAbsent(cat, () => []).add(e);
    }
    final categories = byCategory.keys.toList()..sort();

    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _kebutuhanSearchQuery.isEmpty ? 'Tidak ada data.' : 'Tidak ada item yang cocok dengan "$_kebutuhanSearchQuery".',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      );
    }

    final totalFiltered = filtered.length;
    final listHeight = totalFiltered > 10 ? 360.0 : null;

    return SizedBox(
      height: listHeight,
      child: ListView(
        shrinkWrap: listHeight == null,
        physics: listHeight != null ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
        children: [
          for (final category in categories) ...[
            Builder(
              builder: (context) {
                final itemsInCat = byCategory[category]!;
                final kurangCount = itemsInCat.where((e) {
                  final item = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
                  return item['status'] == 'kurang';
                }).length;
                final hasKurang = kurangCount > 0;
                return ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  childrenPadding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                  title: Row(
                    children: [
                      Icon(
                        hasKurang ? Icons.warning_amber_rounded : Icons.folder_outlined,
                        size: 20,
                        color: hasKurang ? Colors.orange : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasKurang ? Colors.orange.shade800 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      if (hasKurang) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text('$kurangCount kurang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                        child: Text('${itemsInCat.length} item', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
              children: byCategory[category]!.map<Widget>((e) {
                final item = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
                return _buildKebutuhanItemRow(item);
              }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKebutuhanItemRow(Map<String, dynamic> item) {
    final itemName = item['item_name']?.toString() ?? '-';
    final unitName = item['unit_small_name']?.toString() ?? item['unit_name']?.toString() ?? '';
    final kebutuhan = _numVal(item['kebutuhan_small'] ?? item['kebutuhan']);
    final stock = _numVal(item['stock_tersedia_small'] ?? item['stock_tersedia']);
    final selisih = _numVal(item['selisih_small'] ?? item['selisih']);
    final isKurang = item['status'] == 'kurang';
    final contributingMenus = item['contributing_menus'];
    final menusList = contributingMenus is List ? contributingMenus : [];
    final hasMenus = menusList.isNotEmpty;
    final key = _itemKey(item);
    final isExpanded = _expandedKebutuhanKeys.contains(key);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: hasMenus
                ? () => setState(() {
                      if (isExpanded) {
                        _expandedKebutuhanKeys.remove(key);
                      } else {
                        _expandedKebutuhanKeys.add(key);
                      }
                    })
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (hasMenus)
                          Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey.shade600),
                        if (hasMenus) const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              if (unitName.isNotEmpty) Text(unitName, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 52, child: Text(_fmtQty(kebutuhan), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                  SizedBox(width: 52, child: Text(_fmtQty(stock), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                  SizedBox(width: 58, child: Text(_fmtSelisih(selisih), style: TextStyle(fontSize: 11, color: selisih > 0 ? Colors.red : Colors.green.shade700, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isKurang ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(isKurang ? 'Kurang' : 'Cukup', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isKurang ? Colors.red.shade700 : Colors.green.shade700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && hasMenus)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menu yang menggunakan item ini:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
                  const SizedBox(height: 8),
                  ...menusList.map<Widget>((m) {
                    final menu = m is Map ? Map<String, dynamic>.from(m as Map) : <String, dynamic>{};
                    final menuName = menu['menu_name']?.toString() ?? '-';
                    final type = menu['type']?.toString() ?? '';
                    final totalContributed = _numVal(menu['total_contributed']);
                    String detail = '';
                    if (type == 'menu') {
                      final qty = _numVal(menu['menu_qty']);
                      final bom = _numVal(menu['bom_qty_per_menu']);
                      detail = 'Total: ${_fmtQty(qty)} × ${_fmtQty(bom)}';
                    } else if (type == 'modifier') {
                      final menuQty = _numVal(menu['menu_qty']);
                      final modQty = _numVal(menu['modifier_qty']);
                      final bomMod = _numVal(menu['bom_qty_per_modifier']);
                      detail = 'Pesanan: ${_fmtQty(menuQty)}, Modifier: ${_fmtQty(modQty)}, BOM: ${_fmtQty(bomMod)}';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(menuName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
                                if (detail.isNotEmpty) Text(detail, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(_fmtQty(totalContributed), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
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

