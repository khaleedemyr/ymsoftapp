import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/outlet_food_good_receive_models.dart';
import '../../services/outlet_food_good_receive_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';

/// Detail Outlet GR — layout mengikuti web `OutletFoodGoodReceive/Show.vue`.
/// Serial number generate/rollback hanya tersedia untuk **Food Good Receive** (gudang pusat), bukan outlet GR (belum ada API).
class OutletFoodGoodReceiveDetailScreen extends StatefulWidget {
  final int goodReceiveId;

  const OutletFoodGoodReceiveDetailScreen({super.key, required this.goodReceiveId});

  @override
  State<OutletFoodGoodReceiveDetailScreen> createState() => _OutletFoodGoodReceiveDetailScreenState();
}

class _OutletFoodGoodReceiveDetailScreenState extends State<OutletFoodGoodReceiveDetailScreen> {
  final OutletFoodGoodReceiveService _service = OutletFoodGoodReceiveService();

  OutletFoodGoodReceiveDetail? _goodReceive;
  List<OutletFoodGoodReceiveItem> _items = [];
  OutletDeliveryOrderInfo? _deliveryOrderInfo;

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

    final result = await _service.getOutletGoodReceive(widget.goodReceiveId);

    if (!mounted) return;

    if (result != null) {
      final rawGoodReceive = (result['goodReceive'] ?? result['good_receive'] ?? result['data'] ?? result) as Map<String, dynamic>;
      final rawDetails = (result['details'] as List<dynamic>?) ?? (rawGoodReceive['items'] as List<dynamic>?) ?? [];

      setState(() {
        _goodReceive = OutletFoodGoodReceiveDetail.fromJson({
          ...rawGoodReceive,
          'items': rawDetails,
        });
        _items = rawDetails.map((item) => OutletFoodGoodReceiveItem.fromJson(item as Map<String, dynamic>)).toList();

        final deliveryOrderRaw = result['deliveryOrder'] as Map<String, dynamic>?;
        _deliveryOrderInfo = deliveryOrderRaw != null ? OutletDeliveryOrderInfo.fromJson(deliveryOrderRaw) : null;
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

    final result = await _service.deleteOutletGoodReceive(widget.goodReceiveId);

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

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '-';
    try {
      return DateFormat.yMMMd('id_ID').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  Color _statusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'draft') return const Color(0xFFB45309);
    if (s == 'completed') return const Color(0xFF1D4ED8);
    if (s == 'stocked') return const Color(0xFF047857);
    return const Color(0xFF4B5563);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Good Receive Outlet',
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusHeader(),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildFloorOrderCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPackingCard()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildItemsTableCard(),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kembali'),
                      ),
                    ],
                  ),
                ),
                if (_isDeleting)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final st = _goodReceive!.status ?? '-';
    final c = _statusColor(st);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFBFDBFE))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Status: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                Text(st, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tanggal: ${_formatDate(_goodReceive!.receiveDate)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Text('Nomor GR: ${_goodReceive!.number}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Text('Outlet: ${_goodReceive!.outletName ?? '-'}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Text('Nomor DO: ${_goodReceive!.deliveryOrderNumber ?? '-'}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorOrderCard() {
    final d = _deliveryOrderInfo;
    final has = d != null &&
        ((d.floorOrderNumber ?? '').isNotEmpty ||
            (d.floorOrderDate ?? '').isNotEmpty ||
            (d.floorOrderDesc ?? '').isNotEmpty);
    return _buildSmallInfoCard(
      title: 'Floor Order',
      icon: Icons.list_alt,
      child: has
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((d.floorOrderNumber ?? '').isNotEmpty) Text('No: ${d.floorOrderNumber}', style: const TextStyle(fontSize: 13)),
                if ((d.floorOrderDate ?? '').isNotEmpty) Text('Tanggal: ${d.floorOrderDate}', style: const TextStyle(fontSize: 13)),
                if ((d.floorOrderDesc ?? '').isNotEmpty) Text('Keterangan: ${d.floorOrderDesc}', style: const TextStyle(fontSize: 13)),
              ],
            )
          : const Text('—', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildPackingCard() {
    final d = _deliveryOrderInfo;
    final has = d != null && ((d.packingNumber ?? '').isNotEmpty || (d.packingReason ?? '').isNotEmpty);
    return _buildSmallInfoCard(
      title: 'Packing List',
      icon: Icons.inventory_2_outlined,
      child: has
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((d.packingNumber ?? '').isNotEmpty) Text('No: ${d.packingNumber}', style: const TextStyle(fontSize: 13)),
                if ((d.packingReason ?? '').isNotEmpty) Text('Alasan: ${d.packingReason}', style: const TextStyle(fontSize: 13)),
              ],
            )
          : const Text('—', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildSmallInfoCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFBFDBFE))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade800)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTableCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFBFDBFE))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text('List Item DO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900)),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                columns: const [
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Satuan')),
                  DataColumn(label: Text('Qty DO'), numeric: true),
                  DataColumn(label: Text('Qty Scan'), numeric: true),
                ],
                rows: _items.map((it) {
                  return DataRow(
                    cells: [
                      DataCell(SizedBox(width: 180, child: Text(it.itemName, maxLines: 2, overflow: TextOverflow.ellipsis))),
                      DataCell(Text(it.unitName ?? '-')),
                      DataCell(Text(_formatQty(it.qtyDo))),
                      DataCell(Text(_formatQty(it.qtyReceived))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
