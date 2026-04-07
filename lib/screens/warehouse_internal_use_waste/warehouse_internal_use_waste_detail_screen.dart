import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_internal_use_waste_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseInternalUseWasteDetailScreen extends StatefulWidget {
  final int id;

  const WarehouseInternalUseWasteDetailScreen({super.key, required this.id});

  @override
  State<WarehouseInternalUseWasteDetailScreen> createState() => _WarehouseInternalUseWasteDetailScreenState();
}

class _WarehouseInternalUseWasteDetailScreenState extends State<WarehouseInternalUseWasteDetailScreen> {
  final WarehouseInternalUseWasteService _service = WarehouseInternalUseWasteService();
  Map<String, dynamic>? _data;
  bool _canDelete = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.id);
    if (mounted && result != null) {
      setState(() {
        _data = result['data'] is Map ? Map<String, dynamic>.from(result['data'] as Map) : null;
        _canDelete = result['can_delete'] == true;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
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

  String _formatQty(dynamic qty, String? unitName) {
    if (qty == null) return (unitName?.trim().isNotEmpty == true) ? '0 ${unitName!.trim()}' : '-';
    final n = qty is num ? qty.toDouble() : (double.tryParse(qty.toString()) ?? 0);
    final formatted = n == n.truncate() ? n.toInt().toString() : n.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    final unit = (unitName ?? '').trim();
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final n = raw.startsWith('/') ? raw.substring(1) : raw;
    if (n.startsWith('storage/')) return '${AuthService.storageUrl}/$n';
    return '${AuthService.storageUrl}/storage/$n';
  }

  String _getInitials(String name) {
    final t = name.trim();
    if (t.isEmpty || t == '-') return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first.toUpperCase()}${parts.last.characters.first.toUpperCase()}';
  }

  Future<void> _confirmDelete() async {
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
    final result = await _service.delete(widget.id);
    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus'), backgroundColor: Color(0xFF059669)));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal hapus'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Internal Use & Waste',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF059669)))
          : _data == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(_data!['item_name']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                                _detailTypeChip(_data!['type']?.toString()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _row('Tanggal', _formatDate(_data!['date']?.toString())),
                            _row('Tipe', _typeLabel(_data!['type']?.toString())),
                            _row('Gudang', _data!['warehouse_name']?.toString() ?? '-'),
                            if (_data!['type'] == 'internal_use') _row('Ruko', _data!['nama_ruko']?.toString() ?? '-'),
                            _row('Item', _data!['item_name']?.toString() ?? '-'),
                            _row('Qty', _formatQty(_data!['qty'], _data!['unit_name']?.toString())),
                            if (_data!['notes'] != null && _data!['notes'].toString().isNotEmpty) _row('Catatan', _data!['notes']?.toString() ?? ''),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFE5E7EB),
                              backgroundImage: _getAvatarUrl(_data!['creator_avatar']?.toString()) != null
                                  ? CachedNetworkImageProvider(_getAvatarUrl(_data!['creator_avatar']?.toString())!)
                                  : null,
                              child: _getAvatarUrl(_data!['creator_avatar']?.toString()) == null
                                  ? Text(_getInitials(_data!['creator_name']?.toString() ?? '-'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)))
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dibuat oleh', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 2),
                                  Text(_data!['creator_name']?.toString() ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canDelete) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _confirmDelete,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _detailTypeChip(String? type) {
    final label = _typeLabel(type);
    Color bg = const Color(0xFF059669).withOpacity(0.15);
    Color fg = const Color(0xFF059669);
    if (type == 'spoil') { bg = Colors.orange.withOpacity(0.15); fg = Colors.orange.shade800; }
    else if (type == 'waste') { bg = Colors.red.withOpacity(0.15); fg = Colors.red.shade700; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
