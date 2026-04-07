import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_supplier_good_receive_models.dart';
import '../../services/outlet_supplier_good_receive_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

class OutletSupplierGoodReceiveDetailScreen extends StatefulWidget {
  final int goodReceiveId;

  const OutletSupplierGoodReceiveDetailScreen({super.key, required this.goodReceiveId});

  @override
  State<OutletSupplierGoodReceiveDetailScreen> createState() => _OutletSupplierGoodReceiveDetailScreenState();
}

class _OutletSupplierGoodReceiveDetailScreenState extends State<OutletSupplierGoodReceiveDetailScreen> {
  final OutletSupplierGoodReceiveService _service = OutletSupplierGoodReceiveService();

  OutletSupplierGoodReceiveDetail? _goodReceive;
  List<OutletSupplierGoodReceiveItem> _items = [];
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _service.getOutletSupplierGoodReceive(widget.goodReceiveId);

    if (!mounted) return;

    if (result != null) {
      final rawGoodReceive = (result['goodReceive'] ?? result['good_receive'] ?? result['data'] ?? result)
          as Map<String, dynamic>;
      final rawItems = (result['items'] as List<dynamic>?) ?? (rawGoodReceive['items'] as List<dynamic>?) ?? [];

      setState(() {
        _goodReceive = OutletSupplierGoodReceiveDetail.fromJson({
          ...rawGoodReceive,
          'items': rawItems,
        });
        _items = rawItems
            .map((item) => OutletSupplierGoodReceiveItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteGoodReceive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus Good Receive ini?'),
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

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final result = await _service.deleteOutletSupplierGoodReceive(widget.goodReceiveId);

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Good Receive berhasil dihapus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal menghapus'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Outlet Supplier GR',
      actions: [
        IconButton(
          onPressed: _isDeleting ? null : _deleteGoodReceive,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF6F7FB), Color(0xFFEFF3F8)],
              ),
            ),
          ),
          if (_isLoading)
            const AppLoadingIndicator()
          else if (_goodReceive == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Data tidak ditemukan'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            )
          else
            Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildSourceCard(),
                      const SizedBox(height: 16),
                      _buildItemsCard(),
                    ],
                  ),
                ),
                if (_isDeleting)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final receiveDate = _goodReceive!.receiveDate.isNotEmpty
        ? DateFormat('dd MMMM yyyy').format(DateTime.parse(_goodReceive!.receiveDate))
        : '-';

    return _buildSectionCard(
      title: 'Informasi Good Receive',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Nomor GR', _goodReceive!.number),
          _buildInfoRow('Tanggal', receiveDate),
          _buildInfoRow('Outlet', _goodReceive!.outletName ?? '-'),
          _buildInfoRow('Warehouse', _goodReceive!.warehouseOutletName ?? '-'),
          _buildInfoRow('Supplier', _goodReceive!.supplierName ?? '-'),
          _buildInfoRow('Petugas', _goodReceive!.receivedByName ?? '-'),
          _buildStatusRow('Status', _goodReceive!.status ?? '-'),
        ],
      ),
    );
  }

  Widget _buildSourceCard() {
    final isFromDo = (_goodReceive!.poNumber ?? '').isNotEmpty;
    return _buildSectionCard(
      title: isFromDo ? 'Info PO' : 'Info RO Supplier',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            isFromDo ? 'Nomor PO' : 'Nomor RO',
            isFromDo ? (_goodReceive!.poNumber ?? '-') : (_goodReceive!.roNumber ?? '-'),
          ),
          _buildInfoRow(
            isFromDo ? 'Tanggal PO' : 'Tanggal RO',
            isFromDo ? (_goodReceive!.poDate ?? '-') : (_goodReceive!.roDate ?? '-'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return _buildSectionCard(
      title: 'List Item',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_items.isEmpty)
            const Text('Tidak ada item')
          else
            ..._items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3E7EF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildQtyChip('Qty Order', _formatQty(item.qtyOrdered), item.unitName),
                        const SizedBox(width: 10),
                        _buildQtyChip('Qty Terima', _formatQty(item.qtyReceived), item.unitName),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              safeValue,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(safeValue).withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor(safeValue).withOpacity(0.4)),
            ),
            child: Text(
              safeValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(safeValue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildQtyChip(String label, String value, String? unitName) {
    final unitText = (unitName ?? '').trim();
    final displayUnit = unitText.isEmpty ? '' : ' $unitText';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E7EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              '$value$displayUnit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQty(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      if (value % 1 == 0) return value.toInt().toString();
      return value.toString();
    }
    final raw = value.toString();
    return raw.trim().isEmpty ? '-' : raw;
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('complete') || normalized.contains('selesai')) {
      return const Color(0xFF16A34A);
    }
    if (normalized.contains('draft') || normalized.contains('pending')) {
      return const Color(0xFFF59E0B);
    }
    if (normalized.contains('cancel') || normalized.contains('batal')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF4B5563);
  }
}
