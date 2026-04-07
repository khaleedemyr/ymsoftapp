import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/retail_nono_food_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class RetailNonoFoodDetailScreen extends StatefulWidget {
  final int retailNonFoodId;

  const RetailNonoFoodDetailScreen({super.key, required this.retailNonFoodId});

  @override
  State<RetailNonoFoodDetailScreen> createState() => _RetailNonoFoodDetailScreenState();
}

class _RetailNonoFoodDetailScreenState extends State<RetailNonoFoodDetailScreen> {
  final RetailNonFoodService _service = RetailNonFoodService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getDetail(widget.retailNonFoodId);
    if (mounted) {
      setState(() {
        _data = result?['retail_non_food'] ?? result;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatMoney(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(n)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Retail Non Food',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF16A34A)))
          : _data == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = _data!;
    final retailNumber = (t['retail_number'] ?? '-').toString();
    final dateText = _formatDate(t['transaction_date']?.toString());
    final outletName = t['outlet']?['nama_outlet']?.toString() ?? '-';
    final categoryName = t['category_budget']?['name']?.toString() ?? '-';
    final supplierName = t['supplier']?['name']?.toString() ?? '-';
    final paymentMethod = (t['payment_method'] ?? '').toString();
    final paymentLabel = paymentMethod == 'contra_bon' ? 'Contra Bon' : 'Cash';
    final totalAmount = t['total_amount'];
    final notes = t['notes']?.toString();
    final creator = t['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['nama_lengkap']?.toString() ?? creator?['name']?.toString() ?? '-';
    final creatorAvatar = creator?['avatar']?.toString();
    final items = (t['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final invoices = (t['invoices'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(retailNumber, dateText, paymentLabel),
          const SizedBox(height: 16),
          _buildInfoCard(
            rows: [
              _InfoRow(label: 'Outlet', value: outletName),
              _InfoRow(label: 'Kategori Budget', value: categoryName),
              _InfoRow(label: 'Supplier', value: supplierName),
              _InfoRow(label: 'Metode Pembayaran', value: paymentLabel),
              _InfoRow(label: 'Dibuat Oleh', valueWidget: _buildCreator(creatorName, creatorAvatar)),
              _InfoRow(label: 'Keterangan', value: (notes != null && notes.isNotEmpty) ? notes : '-'),
              _InfoRow(label: 'Total', value: _formatMoney(totalAmount), valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
            ],
          ),
          if (invoices.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInvoicesCard(invoices),
          ],
          const SizedBox(height: 16),
          const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          ...items.map(_buildItemCard),
        ],
      ),
    );
  }

  String _invoiceImageUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';
    final path = filePath.startsWith('/') ? filePath.substring(1) : filePath;
    if (path.startsWith('http')) return path;
    if (path.startsWith('storage/')) return '${AuthService.storageUrl}/$path';
    return '${AuthService.storageUrl}/storage/$path';
  }

  Widget _buildInvoicesCard(List<Map<String, dynamic>> invoices) {
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
          Row(
            children: [
              const Icon(Icons.attach_file, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              const Text('Lampiran Invoice / Bon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: invoices.asMap().entries.map((entry) {
              final i = entry.key;
              final inv = entry.value;
              final filePath = inv['file_path']?.toString();
              final url = _invoiceImageUrl(filePath);
              return GestureDetector(
                onTap: () => _showFullScreenImage(url, filePath ?? 'Lampiran ${i + 1}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: url.isEmpty
                        ? const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 32))
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A))),
                            errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32)),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl, String label) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String number, String date, String paymentLabel) {
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
          Row(
            children: [
              Expanded(child: Text(number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentLabel == 'Contra Bon' ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(paymentLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: paymentLabel == 'Contra Bon' ? const Color(0xFFB45309) : const Color(0xFF166534))),
              ),
            ],
          ),
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

  Widget _buildInfoCard({required List<_InfoRow> rows}) {
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
          const Text('Informasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 140, child: Text(row.label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                    Expanded(
                      child: row.valueWidget ??
                          Text(
                            row.value ?? '-',
                            style: row.valueStyle ?? const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCreator(String name, String? avatarPath) {
    final initials = name.isEmpty ? 'U' : (name.trim().split(' ').length >= 2 ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase() : name[0].toUpperCase());
    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = avatarPath.startsWith('http') ? avatarPath : '${AuthService.storageUrl}/storage/${avatarPath.startsWith('/') ? avatarPath.substring(1) : avatarPath}';
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE5E7EB),
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl == null ? Text(initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))) : null,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['item_name']?.toString() ?? '-';
    final qty = item['qty']?.toString() ?? '0';
    final unit = item['unit']?.toString() ?? '-';
    final price = item['price']?.toString() ?? '0';
    final subtotal = (item['subtotal'] ?? (double.tryParse(qty) ?? 0) * (double.tryParse(price) ?? 0)).toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(Icons.scale_rounded, '$qty $unit'),
              _buildPill(Icons.attach_money, 'Harga: $price'),
              _buildPill(Icons.summarize, 'Subtotal: $subtotal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Data tidak ditemukan', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final TextStyle? valueStyle;
  _InfoRow({required this.label, this.value, this.valueWidget, this.valueStyle});
}
