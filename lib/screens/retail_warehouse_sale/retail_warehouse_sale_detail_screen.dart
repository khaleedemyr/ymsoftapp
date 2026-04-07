import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/retail_warehouse_sale_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailWarehouseSaleDetailScreen extends StatefulWidget {
  final int saleId;

  const RetailWarehouseSaleDetailScreen({super.key, required this.saleId});

  @override
  State<RetailWarehouseSaleDetailScreen> createState() =>
      _RetailWarehouseSaleDetailScreenState();
}

class _RetailWarehouseSaleDetailScreenState extends State<RetailWarehouseSaleDetailScreen> {
  final RetailWarehouseSaleService _service = RetailWarehouseSaleService();
  Map<String, dynamic>? _sale;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _canDelete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getDetail(widget.saleId);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data';
      });
      return;
    }
    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Data tidak ditemukan';
      });
      return;
    }
    final sale = result['sale'];
    final items = result['items'];
    setState(() {
      _sale = sale != null ? Map<String, dynamic>.from(sale) : null;
      _items = items is List
          ? (items as List).map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      _canDelete = result['can_delete'] == true;
      _loading = false;
      _error = _sale == null ? 'Data tidak ditemukan' : null;
    });
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

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    final s = (status ?? '').toString();
    Color bg;
    Color fg;
    String label;
    if (s == 'completed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      label = 'Selesai';
    } else if (s == 'draft') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFCA8A04);
      label = 'Draft';
    } else if (s == 'cancelled') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Dibatalkan';
    } else {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade700;
      label = s.isEmpty ? '-' : s;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppScaffold(
        title: 'Detail Penjualan',
        showDrawer: false,
        body: const Center(child: AppLoadingIndicator(size: 32, color: Color(0xFF2563EB))),
      );
    }
    if (_error != null || _sale == null) {
      return AppScaffold(
        title: 'Detail Penjualan',
        showDrawer: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(_error ?? 'Data tidak ditemukan',
                    style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sale = _sale!;
    final number = sale['number']?.toString() ?? '-';
    final status = sale['status']?.toString();

    return AppScaffold(
      title: 'Detail Penjualan',
      showDrawer: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Informasi Penjualan',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          number,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  _buildInfoRow('Tanggal', _formatDate(sale['sale_date']?.toString() ?? sale['created_at']?.toString())),
                  _buildInfoRow('Total', _formatMoney(sale['total_amount'])),
                  if (sale['notes'] != null && sale['notes'].toString().isNotEmpty)
                    _buildInfoRow('Catatan', sale['notes'].toString()),
                ],
              ),
            ),
            _buildSection(
              'Customer',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Nama', sale['customer_name']?.toString() ?? '-'),
                  _buildInfoRow('Kode', sale['customer_code']?.toString() ?? '-'),
                  if (sale['customer_phone'] != null && sale['customer_phone'].toString().isNotEmpty)
                    _buildInfoRow('Telepon', sale['customer_phone'].toString()),
                  if (sale['customer_address'] != null && sale['customer_address'].toString().isNotEmpty)
                    _buildInfoRow('Alamat', sale['customer_address'].toString()),
                ],
              ),
            ),
            _buildSection(
              'Gudang',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Gudang', sale['warehouse_name']?.toString() ?? '-'),
                  _buildInfoRow('Divisi', sale['division_name']?.toString() ?? '-'),
                ],
              ),
            ),
            _buildSection(
              'Detail Item',
              _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Tidak ada item', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : Column(
                      children: _items.map((item) {
                        final name = item['item_name']?.toString() ?? '-';
                        final qty = item['qty'];
                        final unit = item['unit']?.toString() ?? '';
                        final price = item['price'];
                        final subtotal = item['subtotal'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$qty $unit x ${_formatMoney(price)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatMoney(subtotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (_canDelete) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  label: const Text('Hapus Penjualan', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final number = _sale?['number']?.toString() ?? '-';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus penjualan?'),
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
}
