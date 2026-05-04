import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/approval_service.dart';
import '../../services/auth_service.dart';
import '../../services/contra_bon_service.dart';
import '../../widgets/app_loading_indicator.dart';

class ContraBonDetailScreen extends StatefulWidget {
  final int contraBonId;

  const ContraBonDetailScreen({super.key, required this.contraBonId});

  @override
  State<ContraBonDetailScreen> createState() => _ContraBonDetailScreenState();
}

class _ContraBonDetailScreenState extends State<ContraBonDetailScreen> {
  final ContraBonService _service = ContraBonService();
  final ApprovalService _approvalService = ApprovalService();

  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _service.getDetail(widget.contraBonId);
    if (!mounted) return;

    setState(() {
      _detail = result;
      _isLoading = false;
      _errorMessage = result == null ? 'Gagal memuat detail contra bon' : null;
    });
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF059669);
      case 'rejected':
        return Colors.red;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _handleApproveReject({required bool approve}) async {
    final noteController = TextEditingController();
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve Contra Bon' : 'Reject Contra Bon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                hintText: 'Opsional',
                border: OutlineInputBorder(),
              ),
            ),
            if (!approve) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alasan Reject',
                  hintText: 'Wajib diisi',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    if (!approve && reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alasan reject wajib diisi'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = approve
        ? await _approvalService.approveContraBon(widget.contraBonId, note: noteController.text.trim())
        : await _approvalService.rejectContraBon(
            widget.contraBonId,
            note: noteController.text.trim(),
            reason: reasonController.text.trim(),
          );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (result != null && result['success'] == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? 'Contra bon berhasil di-approve' : 'Contra bon berhasil di-reject'),
          backgroundColor: approve ? const Color(0xFF059669) : Colors.red,
        ),
      );
      await _loadDetail();
      if (mounted) {
        navigator.pop(true);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text((result != null && result['message'] != null ? result['message'] : 'Proses gagal').toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _detail ?? {};
    final status = data['status']?.toString();
    final canApprove = status == 'draft';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detail Contra Bon'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(data),
                      const SizedBox(height: 16),
                      _buildInfoCard(data),
                      const SizedBox(height: 16),
                      _buildSourcesCard(data),
                      const SizedBox(height: 16),
                      _buildItemsCard((data['items'] as List?)?.cast<Map<String, dynamic>>() ?? []),
                      if ((data['file_path'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildImageCard((data['file_path'] ?? '').toString()),
                      ],
                      if (canApprove) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : () => _handleApproveReject(approve: true),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting ? null : () => _handleApproveReject(approve: false),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final number = (data['number'] ?? '-').toString();
    final status = data['status']?.toString();
    final date = data['date']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Text('Tanggal: ${_formatDate(date)}', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status ?? '-', style: TextStyle(fontWeight: FontWeight.w600, color: _statusColor(status))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data) {
    final supplier = ((data['supplier'] as Map?)?['name'] ?? '-').toString();
    final invoiceNumber = (data['supplier_invoice_number'] ?? '-').toString();
    final invoiceDate = data['supplier_invoice_date']?.toString();
    final taxInvoice = (data['tax_invoice_number'] ?? '-').toString();
    final createdBy = ((data['creator'] as Map?)?['nama_lengkap'] ?? '-').toString();
    final notes = (data['notes'] ?? '-').toString();
    final financeManager = ((data['finance_manager'] as Map?)?['nama_lengkap'] ?? '').toString();
    final gmFinance = ((data['gm_finance'] as Map?)?['nama_lengkap'] ?? '').toString();

    return _card(
      title: 'Informasi',
      child: Column(
        children: [
          _infoRow('Supplier', supplier),
          _infoRow('Invoice Supplier', invoiceNumber),
          _infoRow('Tanggal Invoice', _formatDate(invoiceDate)),
          _infoRow('Faktur Pajak', taxInvoice.isNotEmpty ? taxInvoice : '-'),
          _infoRow('Dibuat Oleh', createdBy),
          _infoRow('Finance Manager', financeManager.isNotEmpty ? financeManager : '-'),
          _infoRow('GM Finance', gmFinance.isNotEmpty ? gmFinance : '-'),
          _infoRow('Notes', notes.isNotEmpty ? notes : '-'),
          _infoRow('Total', _formatCurrency(data['total_amount'])),
        ],
      ),
    );
  }

  Widget _buildSourcesCard(Map<String, dynamic> data) {
    final sourceType = (data['source_type_display'] ?? 'Unknown').toString();
    final sourceNumbers = (data['source_numbers'] is List)
        ? (data['source_numbers'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final sourceOutlets = (data['source_outlets'] is List)
        ? (data['source_outlets'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return _card(
      title: 'Sumber',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Tipe Source', sourceType),
          _infoRow('Source Number', sourceNumbers.isEmpty ? '-' : sourceNumbers.join(', ')),
          _infoRow('Outlet/Gudang', sourceOutlets.isEmpty ? '-' : sourceOutlets.join(', ')),
        ],
      ),
    );
  }

  Widget _buildItemsCard(List<Map<String, dynamic>> items) {
    return _card(
      title: 'Item Contra Bon',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Tidak ada item', style: TextStyle(color: Color(0xFF64748B))),
            )
          : Column(
              children: items.asMap().entries.map((entry) {
                final item = entry.value;
                final name = (item['item_name'] ?? item['name'] ?? '-').toString();
                final qty = item['qty'] ?? item['quantity'] ?? item['purchase_qty'] ?? 0;
                final price = item['price'] ?? item['unit_price'] ?? 0;
                final subtotal = item['subtotal'] ?? item['total'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _blue.withValues(alpha: 0.12),
                        child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            Text('Qty: ${qty.toString()}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text('Harga: ${_formatCurrency(price)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text('Subtotal: ${_formatCurrency(subtotal)}', style: const TextStyle(fontSize: 13, color: _blue, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildImageCard(String filePath) {
    final imageUrl = '${AuthService.baseUrl}/storage/$filePath';
    return _card(
      title: 'Lampiran',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 180,
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: const Text('Gagal memuat gambar'),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}
