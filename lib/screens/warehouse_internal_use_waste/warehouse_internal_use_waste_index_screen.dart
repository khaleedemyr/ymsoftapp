import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/warehouse_internal_use_waste_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'warehouse_internal_use_waste_create_screen.dart';
import 'warehouse_internal_use_waste_detail_screen.dart';

/// Selaras web `InternalUseWaste/Index.vue` — filter, kolom, paginasi server, aksi.
class WarehouseInternalUseWasteIndexScreen extends StatefulWidget {
  const WarehouseInternalUseWasteIndexScreen({super.key});

  @override
  State<WarehouseInternalUseWasteIndexScreen> createState() => _WarehouseInternalUseWasteIndexScreenState();
}

class _WarehouseInternalUseWasteIndexScreenState extends State<WarehouseInternalUseWasteIndexScreen> {
  final WarehouseInternalUseWasteService _service = WarehouseInternalUseWasteService();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = true;
  bool _canDelete = false;
  String _typeFilter = '';
  int? _warehouseIdFilter;
  int _currentPage = 1;
  int _lastPage = 1;
  int _perPage = 15;
  int _total = 0;
  bool _filterExpanded = true;
  int? _deletingDocId;

  static const Color _green = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadCreateData();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreateData() async {
    final result = await _service.getCreateData();
    if (mounted && result != null) {
      setState(() {
        _warehouses = result['warehouses'] != null && result['warehouses'] is List
            ? List<Map<String, dynamic>>.from(
                (result['warehouses'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
              )
            : [];
      });
    }
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    final result = await _service.getList(
      type: _typeFilter.isNotEmpty ? _typeFilter : null,
      dateFrom: _dateFromController.text.trim().isNotEmpty ? _dateFromController.text.trim() : null,
      dateTo: _dateToController.text.trim().isNotEmpty ? _dateToController.text.trim() : null,
      warehouseId: _warehouseIdFilter,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      page: _currentPage,
      perPage: _perPage,
    );
    if (mounted && result != null) {
      final raw = result['data'] is List ? result['data'] as List : <dynamic>[];
      final dataTyped = raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      setState(() {
        _list = dataTyped;
        _canDelete = result['can_delete'] == true;
        _lastPage = _parsePositiveInt(result['last_page'], fallback: 1);
        _total = _parsePositiveInt(result['total'], fallback: dataTyped.length);
        final cp = _parsePositiveInt(result['current_page'], fallback: _currentPage);
        _currentPage = cp;
        final pp = _parsePositiveInt(result['per_page'], fallback: _perPage);
        if (pp > 0) _perPage = pp;
        _isLoading = false;
      });
      if (result['success'] != true && result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'].toString()), backgroundColor: Colors.orange),
        );
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int _parsePositiveInt(dynamic v, {required int fallback}) {
    if (v is int && v > 0) return v;
    final p = int.tryParse(v?.toString() ?? '');
    return (p != null && p > 0) ? p : fallback;
  }

  int? _documentId(Map<String, dynamic> row) {
    final h = row['header_id'];
    if (h != null) {
      if (h is int) return h;
      return int.tryParse(h.toString());
    }
    final id = row['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String _lineNoteDisplay(Map<String, dynamic> row) {
    final n = row['notes'];
    if (n != null && n.toString().trim().isNotEmpty) return n.toString();
    final hn = row['header_notes'];
    if (hn != null && hn.toString().trim().isNotEmpty) return hn.toString();
    return '-';
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat.yMMMd('id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  String _typeLabel(String? type) {
    if (type == null || type.isEmpty) return '-';
    switch (type) {
      case 'internal_use':
        return 'Internal Use';
      case 'spoil':
        return 'Spoil';
      case 'waste':
        return 'Waste';
      case 'r_and_d':
        return 'RnD';
      default:
        return type;
    }
  }

  String _formatNumber(dynamic val) {
    if (val == null) return '-';
    final n = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (n == null) return '-';
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return NumberFormat.decimalPattern('id_ID').format(n);
  }

  int get _displayFrom {
    if (_list.isEmpty || _total == 0) return 0;
    return (_currentPage - 1) * _perPage + 1;
  }

  int get _displayTo {
    if (_list.isEmpty) return 0;
    return _displayFrom + _list.length - 1;
  }

  Future<void> _openUrl(String path) async {
    final base = AuthService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka browser')));
    }
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const WarehouseInternalUseWasteCreateScreen()),
    );
    if (ok == true && mounted) _loadList();
  }

  Future<void> _openEditWeb(int docId) async {
    final base = AuthService.baseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/internal-use-waste/$docId/edit');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka browser')));
    }
  }

  Future<void> _confirmDelete(int docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakin hapus dokumen ini?'),
        content: const Text('Semua baris item terkait akan dihapus dan stok di-rollback.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deletingDocId = docId);
    final result = await _service.delete(docId);
    if (mounted) {
      setState(() => _deletingDocId = null);
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dihapus dan stok di-rollback.'), backgroundColor: _green),
        );
        _loadList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal hapus'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() => _currentPage = 1);
    _loadList();
  }

  void _resetFilters() {
    setState(() {
      _typeFilter = '';
      _warehouseIdFilter = null;
      _dateFromController.clear();
      _dateToController.clear();
      _searchController.clear();
      _perPage = 15;
      _currentPage = 1;
    });
    _loadList();
  }

  void _goPage(int page) {
    if (page < 1 || page > _lastPage) return;
    setState(() => _currentPage = page);
    _loadList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Internal Use & Waste',
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white),
                    onPressed: () => _openUrl('/internal-use-waste/report'),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Laporan Internal Use'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
                    onPressed: () => _openUrl('/internal-use-waste/report-waste-spoil'),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Laporan Spoil & Waste'),
                  ),
                ],
              ),
            ),
          ),
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator(size: 32, color: _green))
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Tidak ada data.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadList(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: _list.length,
                          itemBuilder: (context, index) => _buildRowCard(_list[index]),
                        ),
                      ),
          ),
          if (!_isLoading && _lastPage > 1) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menampilkan $_displayFrom–$_displayTo dari $_total',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: _currentPage <= 1 ? null : () => _goPage(_currentPage - 1),
                    child: const Text('Sebelumnya'),
                  ),
                  Text('Halaman $_currentPage / $_lastPage', style: const TextStyle(fontSize: 13)),
                  OutlinedButton(
                    onPressed: _currentPage >= _lastPage ? null : () => _goPage(_currentPage + 1),
                    child: const Text('Berikutnya'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    value: _typeFilter.isEmpty ? '' : _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Semua')),
                      DropdownMenuItem(value: 'internal_use', child: Text('Internal Use')),
                      DropdownMenuItem(value: 'spoil', child: Text('Spoil')),
                      DropdownMenuItem(value: 'waste', child: Text('Waste')),
                      DropdownMenuItem(value: 'r_and_d', child: Text('RnD')),
                    ],
                    onChanged: (v) => setState(() => _typeFilter = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _warehouseIdFilter,
                    decoration: const InputDecoration(
                      labelText: 'Warehouse',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
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
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => _dateFromController.text = DateFormat('yyyy-MM-dd').format(d));
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _dateFromController,
                              decoration: const InputDecoration(
                                labelText: 'Dari tanggal',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => _dateToController.text = DateFormat('yyyy-MM-dd').format(d));
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _dateToController,
                              decoration: const InputDecoration(
                                labelText: 'Sampai tanggal',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Cari item',
                      hintText: 'Nama item',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: _perPage,
                          decoration: const InputDecoration(
                            labelText: 'Per halaman',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 15, child: Text('15')),
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _perPage = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _applyFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Terapkan'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _resetFilters,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _documentModeLabel(String? mode) {
    if (mode == 'serial') return 'Serial';
    if (mode == 'mixed') return 'Campuran';
    return null;
  }

  Widget _buildDocumentModeChip(String? mode) {
    final label = _documentModeLabel(mode);
    if (label == null) return const SizedBox.shrink();
    final isSerial = mode == 'serial';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSerial ? const Color(0xFFE0E7FF) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isSerial ? const Color(0xFF4338CA) : const Color(0xFF7E22CE),
        ),
      ),
    );
  }

  bool _canEditRow(Map<String, dynamic> row) {
    final mode = row['document_mode']?.toString();
    return mode == null || mode.isEmpty || mode == 'normal';
  }

  Widget _buildRowCard(Map<String, dynamic> row) {
    final docId = _documentId(row);
    final busy = _deletingDocId != null && _deletingDocId == docId;
    final docMode = row['document_mode']?.toString();
    final creatorName = row['creator_name']?.toString() ?? '-';
    final creatorAvatar = row['creator_avatar']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreatorBlock(creatorName, creatorAvatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dok ${docId ?? '-'}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            _buildDocumentModeChip(docMode),
                          ],
                        ),
                      ),
                      _buildTypeChip(row['type']?.toString()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _kv('Tanggal', _formatDate(row['date']?.toString())),
                  _kv('Warehouse', row['warehouse_name']?.toString() ?? '-'),
                  _kv('Item', row['item_name']?.toString() ?? '-'),
                  _kv('Qty', _formatNumber(row['qty'])),
                  _kv('Unit', row['unit_name']?.toString() ?? '-'),
                  _kv('Catatan', _lineNoteDisplay(row)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: docId == null
                            ? null
                            : () {
                                Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (context) => WarehouseInternalUseWasteDetailScreen(id: docId)),
                                ).then((_) => _loadList());
                              },
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: _green),
                        label: const Text('Detail', style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
                      ),
                      if (_canEditRow(row))
                        TextButton.icon(
                          onPressed: docId == null ? null : () => _openEditWeb(docId),
                          icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade800),
                          label: Text('Edit', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600)),
                        ),
                      if (_canDelete)
                        TextButton.icon(
                          onPressed: docId == null || busy ? null : () => _confirmDelete(docId),
                          icon: busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red.shade700),
                                )
                              : Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
                          label: Text(
                            busy ? 'Menghapus...' : 'Hapus',
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar creator + nama di bawah (sama pola `OutletTransferIndexScreen`).
  Widget _buildCreatorBlock(String name, String? avatarPath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCreatorAvatar(name, avatarPath),
        const SizedBox(height: 6),
        SizedBox(
          width: 52 * 2,
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorAvatar(String name, String? avatarPath) {
    final initials = _getInitials(name);
    final avatarUrl = _getAvatarUrl(avatarPath);
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
            )
          : null,
    );
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) {
      return '${AuthService.storageUrl}/$normalized';
    }
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final p = parts.first;
      return p.isEmpty ? '?' : p.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Widget _buildTypeChip(String? type) {
    final label = _typeLabel(type);
    Color bg = _green.withOpacity(0.15);
    Color fg = _green;
    if (type == 'spoil') {
      bg = Colors.orange.withOpacity(0.15);
      fg = Colors.orange.shade800;
    } else if (type == 'waste') {
      bg = Colors.red.withOpacity(0.15);
      fg = Colors.red.shade700;
    } else if (type == 'r_and_d') {
      bg = Colors.indigo.withOpacity(0.15);
      fg = Colors.indigo.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 76, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
