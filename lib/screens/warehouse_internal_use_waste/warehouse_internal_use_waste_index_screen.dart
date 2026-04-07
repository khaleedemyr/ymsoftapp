import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_internal_use_waste_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'warehouse_internal_use_waste_detail_screen.dart';
import 'warehouse_internal_use_waste_create_screen.dart';

class WarehouseInternalUseWasteIndexScreen extends StatefulWidget {
  const WarehouseInternalUseWasteIndexScreen({super.key});

  @override
  State<WarehouseInternalUseWasteIndexScreen> createState() => _WarehouseInternalUseWasteIndexScreenState();
}

class _WarehouseInternalUseWasteIndexScreenState extends State<WarehouseInternalUseWasteIndexScreen> {
  final WarehouseInternalUseWasteService _service = WarehouseInternalUseWasteService();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = true;
  bool _canDelete = false;
  String _typeFilter = 'all';
  int? _warehouseIdFilter;
  int _currentPage = 1;
  int _lastPage = 1;
  bool _filterExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _warehouses = result['warehouses'] != null && result['warehouses'] is List
            ? List<Map<String, dynamic>>.from((result['warehouses'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
            : [];
      });
    }
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    final result = await _service.getList(
      type: _typeFilter != 'all' ? _typeFilter : null,
      dateFrom: _dateFromController.text.trim().isNotEmpty ? _dateFromController.text.trim() : null,
      dateTo: _dateToController.text.trim().isNotEmpty ? _dateToController.text.trim() : null,
      warehouseId: _warehouseIdFilter,
      page: _currentPage,
      perPage: 20,
    );
    if (mounted && result != null) {
      final raw = result['data'] is List ? result['data'] as List : <dynamic>[];
      final data = raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      final dataTyped = List<Map<String, dynamic>>.from(data);
      setState(() {
        if (_currentPage == 1) {
          _list = dataTyped;
        } else {
          _list = [..._list, ...dataTyped];
        }
        _canDelete = result['can_delete'] == true;
        _lastPage = (result['last_page'] is int) ? result['last_page'] as int : 1;
        _isLoading = false;
      });
      if (result['success'] != true && result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'].toString()), backgroundColor: Colors.orange));
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v ?? '-';
    }
  }

  String _typeLabel(String? type) {
    if (type == null) return '-';
    switch (type) {
      case 'internal_use': return 'Internal Use';
      case 'spoil': return 'Spoil';
      case 'waste': return 'Waste';
      default: return type;
    }
  }

  /// Format qty: remove trailing zeros (1.0000 -> 1, 1.5 -> 1.5)
  String _formatQty(dynamic qty, String? unitName) {
    if (qty == null) {
      final unit = (unitName ?? '').trim();
      return unit.isNotEmpty ? '0 $unit' : '-';
    }
    final n = qty is num ? qty.toDouble() : (double.tryParse(qty.toString()) ?? 0);
    final formatted = n == n.truncate() ? n.toInt().toString() : n.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    final unit = (unitName ?? '').trim();
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) return '${AuthService.storageUrl}/$normalized';
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first.toUpperCase()}${parts.last.characters.first.toUpperCase()}';
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push(context, MaterialPageRoute(builder: (context) => const WarehouseInternalUseWasteCreateScreen()));
    if (ok == true && mounted) _loadList();
  }

  void _confirmDelete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data?'),
        content: const Text('Stok akan di-rollback. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _service.delete(id is int ? id : int.tryParse(id.toString()) ?? 0);
    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus'), backgroundColor: Color(0xFF059669)));
        _loadList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal hapus'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Internal Use & Waste',
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF059669)))
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Belum ada data', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadList(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _list.length + (_currentPage < _lastPage ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _list.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() => _currentPage++);
                                      _loadList();
                                    },
                                    child: const Text('Muat lebih banyak'),
                                  ),
                                ),
                              );
                            }
                            final item = _list[index];
                            return _buildCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: const Color(0xFF059669),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(_filterExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade700),
                ],
              ),
            ),
          ),
          if (_filterExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _typeFilter,
                    decoration: const InputDecoration(labelText: 'Tipe', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua')),
                      DropdownMenuItem(value: 'internal_use', child: Text('Internal Use')),
                      DropdownMenuItem(value: 'spoil', child: Text('Spoil')),
                      DropdownMenuItem(value: 'waste', child: Text('Waste')),
                    ],
                    onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _warehouseIdFilter,
                    decoration: const InputDecoration(labelText: 'Gudang', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Semua')),
                      ..._warehouses.map((w) {
                        final id = w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '');
                        return DropdownMenuItem<int?>(value: id, child: Text(w['name']?.toString() ?? '-'));
                      }),
                    ],
                    onChanged: (v) => setState(() => _warehouseIdFilter = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (d != null) setState(() => _dateFromController.text = DateFormat('yyyy-MM-dd').format(d));
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _dateFromController,
                              decoration: const InputDecoration(labelText: 'Dari', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: Icon(Icons.calendar_today)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (d != null) setState(() => _dateToController.text = DateFormat('yyyy-MM-dd').format(d));
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _dateToController,
                              decoration: const InputDecoration(labelText: 'Sampai', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), suffixIcon: Icon(Icons.calendar_today)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _currentPage = 1);
                        _loadList();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id'];
    final idInt = id is int ? id : int.tryParse(id?.toString() ?? '');
    final canTap = idInt != null && idInt > 0;
    final creatorName = item['creator_name']?.toString() ?? '-';
    final creatorAvatar = item['creator_avatar']?.toString();
    final avatarUrl = _getAvatarUrl(creatorAvatar);
    final initials = _getInitials(creatorName);

    return GestureDetector(
      onTap: canTap ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => WarehouseInternalUseWasteDetailScreen(id: idInt!))).then((_) => _loadList()) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE5E7EB),
              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['item_name']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      _buildTypeChip(item['type']?.toString()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(_formatDate(item['date']?.toString()), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Gudang', item['warehouse_name']?.toString() ?? '-'),
                  _infoRow('Qty', _formatQty(item['qty'], item['unit_name']?.toString())),
                  _infoRow('Dibuat', creatorName),
                  if (_canDelete) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _confirmDelete(item),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String? type) {
    final label = _typeLabel(type);
    Color bg = const Color(0xFF059669).withOpacity(0.15);
    Color fg = const Color(0xFF059669);
    if (type == 'spoil') {
      bg = Colors.orange.withOpacity(0.15);
      fg = Colors.orange.shade800;
    } else if (type == 'waste') {
      bg = Colors.red.withOpacity(0.15);
      fg = Colors.red.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
