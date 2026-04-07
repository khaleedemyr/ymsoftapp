import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/floor_order_service.dart';
import '../../services/approval_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'floor_order_form_screen.dart';

class FloorOrderDetailScreen extends StatefulWidget {
  final int orderId;

  const FloorOrderDetailScreen({super.key, required this.orderId});

  @override
  State<FloorOrderDetailScreen> createState() => _FloorOrderDetailScreenState();
}

class _FloorOrderDetailScreenState extends State<FloorOrderDetailScreen> {
  final FloorOrderService _service = FloorOrderService();
  final ApprovalService _approvalService = ApprovalService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _order;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadOrder();
  }

  Future<void> _loadUser() async {
    final userData = await _authService.getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
      });
    }
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.getFloorOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  bool _isSuperadmin() {
    return _userData?['id_role'] == '5af56935b011a' && _userData?['status'] == 'A';
  }

  bool _canApproveKhusus() {
    if (_isSuperadmin()) return true;
    final warehouseName = _order?['warehouse_outlet']?['name']?.toString();
    final userJabatan = _userData?['id_jabatan'];
    final userStatus = _userData?['status'];
    if (userStatus != 'A') return false;

    if (warehouseName == 'Kitchen') {
      return [163, 174, 180, 345, 346, 347, 348, 349].contains(userJabatan);
    }
    if (warehouseName == 'Bar') {
      return [175, 182, 323].contains(userJabatan);
    }
    if (warehouseName == 'Service') {
      return [176, 322, 164, 321].contains(userJabatan);
    }
    return false;
  }

  Future<void> _openEdit() async {
    if (_order == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FloorOrderFormScreen(orderId: widget.orderId),
      ),
    );
    if (result == true) {
      _loadOrder();
    }
  }

  Future<void> _submitOrder() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final result = await _service.submitFloorOrder(widget.orderId);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true) {
      _showMessage('RO berhasil dikirim', success: true);
      _loadOrder();
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal submit RO');
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus RO?'),
        content: const Text('RO akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
    });

    final result = await _service.deleteFloorOrder(widget.orderId);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true) {
      _showMessage('RO berhasil dihapus', success: true);
      Navigator.pop(context, true);
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal menghapus RO');
    }
  }

  Future<void> _approveKhusus(bool approved) async {
    if (_isProcessing) return;

    final note = await _showNoteDialog(
      approved ? 'Approve RO Khusus' : 'Reject RO Khusus',
      'Catatan (opsional)',
    );
    if (note == null) return;

    setState(() {
      _isProcessing = true;
    });

    final result = approved
        ? await _approvalService.approveROKhusus(widget.orderId, note: note)
        : await _approvalService.rejectROKhusus(widget.orderId, note: note);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true ||
        result['message']?.toString().toLowerCase().contains('berhasil') == true) {
      _showMessage('RO Khusus berhasil diproses', success: true);
      _loadOrder();
    } else if (result['violations'] != null) {
      _showBudgetViolationDialog(result['message']?.toString() ?? 'Budget limit terlampaui');
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal memproses RO Khusus');
    }
  }

  Future<void> _exportPdf() async {
    setState(() {
      _isProcessing = true;
    });

    final path = await _service.downloadPdf(widget.orderId);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (path == null) {
      _showMessage('Gagal download PDF');
      return;
    }

    await OpenFilex.open(path);
  }

  void _showBudgetViolationDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Budget Limit'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showNoteDialog(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final numValue = amount is String
        ? (double.tryParse(amount) ?? 0.0)
        : (amount is num ? amount.toDouble() : 0.0);
    return 'Rp ${NumberFormat('#,###').format(numValue)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _order?['status']?.toString().toLowerCase();
    final isDraft = status == 'draft';
    final isSubmitted = status == 'submitted';
    final isKhusus = _order?['fo_mode']?.toString() == 'RO Khusus';
    final hasPackingList = _order?['has_packing_list'] == true;

    return AppScaffold(
      title: 'Detail RO',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _order == null
              ? Center(child: Text(_errorMessage ?? 'Data tidak ditemukan'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildItemsCard(),
                    const SizedBox(height: 16),
                    _buildTotalsCard(),
                    const SizedBox(height: 16),
                    if (isDraft) _buildDraftActions(),
                    if (isSubmitted && isKhusus && _canApproveKhusus()) _buildApprovalActions(),
                    if (!hasPackingList) ...[
                      const SizedBox(height: 10),
                      _buildDeleteAction(),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeaderCard() {
    final order = _order!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order['order_number']?.toString() ?? 'RO',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _infoRow('Status', order['status']?.toString() ?? '-'),
          _infoRow('Mode', order['fo_mode']?.toString() ?? '-'),
          _infoRow('Outlet', order['outlet']?['nama_outlet']?.toString() ?? '-'),
          _infoRow('Warehouse', order['warehouse_outlet']?['name']?.toString() ?? '-'),
          _infoRow('Tanggal', order['tanggal']?.toString() ?? '-'),
          _infoRow('Tanggal Datang', order['arrival_date']?.toString() ?? '-'),
          if ((order['description'] ?? '').toString().isNotEmpty)
            _infoRow('Deskripsi', order['description']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final items = _order?['items'] as List<dynamic>? ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('Tidak ada item', style: TextStyle(color: Colors.grey.shade600))
          else
            ...items.map((item) {
              final data = item as Map<String, dynamic>;
              final qty = data['qty'] ?? 0;
              final price = data['price'] ?? 0;
              final subtotal = (qty is num ? qty : double.tryParse(qty.toString()) ?? 0) *
                  (price is num ? price : double.tryParse(price.toString()) ?? 0);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['item_name']?.toString() ?? data['item']?['name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Qty: ${data['qty']} ${data['unit'] ?? ''}'),
                        const Spacer(),
                        Text(_formatCurrency(subtotal)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    final total = _order?['total_amount'] ?? _order?['total'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            _formatCurrency(total),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _openEdit,
            icon: const Icon(Icons.edit),
            label: const Text('Edit Draft', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
              shadowColor: const Color(0x664F46E5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _submitOrder,
            icon: const Icon(Icons.send),
            label: const Text('Submit RO', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
              shadowColor: const Color(0x6616A34A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteAction() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _deleteOrder,
        icon: const Icon(Icons.delete),
        label: const Text('Hapus RO', style: TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildApprovalActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _approveKhusus(true),
            icon: const Icon(Icons.check),
            label: const Text('Approve RO Khusus', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
              shadowColor: const Color(0x6616A34A),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _approveKhusus(false),
            icon: const Icon(Icons.close),
            label: const Text('Reject RO Khusus', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
              shadowColor: const Color(0x66DC2626),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
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
}
