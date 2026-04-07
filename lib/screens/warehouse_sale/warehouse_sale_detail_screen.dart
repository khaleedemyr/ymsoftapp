import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_sale_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseSaleDetailScreen extends StatefulWidget {
  final int saleId;

  const WarehouseSaleDetailScreen({super.key, required this.saleId});

  @override
  State<WarehouseSaleDetailScreen> createState() => _WarehouseSaleDetailScreenState();
}

class _WarehouseSaleDetailScreenState extends State<WarehouseSaleDetailScreen> {
  final WarehouseSaleService _service = WarehouseSaleService();
  Map<String, dynamic>? _sale;
  bool _isLoading = true;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.saleId);
    if (mounted) {
      setState(() {
        _sale = result?['sale'];
        _canDelete = result?['can_delete'] == true;
        _isLoading = false;
      });
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

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  String? _getAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    if (normalized.startsWith('storage/')) return '${AuthService.storageUrl}/$normalized';
    return '${AuthService.storageUrl}/storage/$normalized';
  }

  Future<void> _confirmDelete() async {
    final number = _sale?['number']?.toString() ?? '-';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus penjualan antar gudang?'),
        content: Text('Stok akan dikembalikan. Lanjutkan hapus $number?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _service.delete(widget.saleId);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil dihapus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['message']?.toString() ?? 'Gagal menghapus'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Penjualan Antar Gudang',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF0EA5E9)))
          : _sale == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Data tidak ditemukan', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  /// Laravel returns relations as camelCase (sourceWarehouse, targetWarehouse, items).
  T? _get<T>(Map<String, dynamic> m, String snakeKey, String camelKey) {
    final v = m[camelKey] ?? m[snakeKey];
    return v is T ? v : null;
  }

  Widget _buildContent() {
    final s = _sale!;
    final number = s['number']?.toString() ?? '-';
    final dateText = _formatDate(s['date']?.toString());
    final sourceWarehouse = _get<Map<String, dynamic>>(s, 'source_warehouse', 'sourceWarehouse');
    final targetWarehouse = _get<Map<String, dynamic>>(s, 'target_warehouse', 'targetWarehouse');
    final sourceName = sourceWarehouse?['name']?.toString() ?? '-';
    final targetName = targetWarehouse?['name']?.toString() ?? '-';
    final creator = _get<Map<String, dynamic>>(s, 'creator', 'creator');
    final creatorName = creator?['nama_lengkap']?.toString() ?? creator?['name']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();
    final notes = s['note']?.toString();
    final itemsRaw = s['items'];
    final items = (itemsRaw is List) ? itemsRaw.map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    double totalValue = 0;
    for (final i in items) {
      final t = i['total'];
      if (t is num) totalValue += t.toDouble();
      else if (t != null) totalValue += double.tryParse(t.toString()) ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(number, dateText),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Informasi Gudang',
            rows: [
              _InfoRow(label: 'Gudang Asal', value: sourceName),
              _InfoRow(label: 'Gudang Tujuan', value: targetName),
              _InfoRow(label: 'Dibuat Oleh', valueWidget: _buildCreatorRow(creatorName, creatorAvatar)),
              _InfoRow(label: 'Catatan', value: (notes != null && notes.isNotEmpty) ? notes : '-'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              if (_canDelete)
                TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(_buildItemCard),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Nilai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(_formatMoney(totalValue), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String number, String date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorRow(String name, String? avatarUrl) {
    final url = _getAvatarUrl(avatarUrl);
    return Row(
      children: [
        if (url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(imageUrl: url, width: 32, height: 32, fit: BoxFit.cover),
          )
        else
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
            ),
          ),
        const SizedBox(width: 10),
        Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required List<_InfoRow> rows}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 110, child: Text(row.label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                    Expanded(child: row.valueWidget ?? Text(row.value ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemData = item['item'] is Map ? item['item'] as Map<String, dynamic>? : null;
    final name = itemData?['name']?.toString() ?? '-';
    final sku = itemData?['sku']?.toString();
    final qtyS = (item['qty_small'] is num) ? (item['qty_small'] as num).toDouble() : double.tryParse(item['qty_small']?.toString() ?? '') ?? 0;
    final qtyM = (item['qty_medium'] is num) ? (item['qty_medium'] as num).toDouble() : double.tryParse(item['qty_medium']?.toString() ?? '') ?? 0;
    final qtyL = (item['qty_large'] is num) ? (item['qty_large'] as num).toDouble() : double.tryParse(item['qty_large']?.toString() ?? '') ?? 0;
    final qty = qtyS > 0 ? qtyS : (qtyM > 0 ? qtyM : qtyL);
    final price = item['price'];
    final total = item['total'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          if (sku != null && sku.isNotEmpty) Text('SKU: $sku', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Qty: $qty', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(_formatMoney(price), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Subtotal: ${_formatMoney(total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0EA5E9))),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String? value;
  final Widget? valueWidget;

  _InfoRow({required this.label, this.value, this.valueWidget});
}
