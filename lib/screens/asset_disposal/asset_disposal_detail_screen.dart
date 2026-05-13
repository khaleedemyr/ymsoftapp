import 'package:flutter/material.dart';
import '../../services/asset_disposal_service.dart';
import '../../models/asset_disposal_models.dart';
import '../../services/auth_service.dart';

class AssetDisposalDetailScreen extends StatefulWidget {
  final int disposalId;
  const AssetDisposalDetailScreen({super.key, required this.disposalId});

  @override
  State<AssetDisposalDetailScreen> createState() => _AssetDisposalDetailScreenState();
}

class _AssetDisposalDetailScreenState extends State<AssetDisposalDetailScreen> {
  final _service = AssetDisposalService();
  AssetDisposal? _disposal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await _service.getDisposal(widget.disposalId);
    if (data != null && mounted) {
      setState(() { _disposal = data; _isLoading = false; });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting_approval': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_approval': return 'WAITING';
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      default: return status.toUpperCase();
    }
  }

  Color _flowColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatCurrency(double val) {
    return 'Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _doApprove() async {
    final comments = await _showInputDialog('Approve Disposal', hintText: 'Komentar (opsional)', required: false);
    if (comments == null) return;
    final result = await _service.approve(widget.disposalId, 'approve', comments: comments);
    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Approved', Colors.green);
      _loadDetail();
    } else {
      _showSnack(result['message'] ?? 'Gagal approve', Colors.red);
    }
  }

  Future<void> _doReject() async {
    final comments = await _showInputDialog('Reject Disposal', hintText: 'Alasan penolakan (wajib)', required: true);
    if (comments == null || comments.isEmpty) return;
    final result = await _service.approve(widget.disposalId, 'reject', comments: comments);
    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Rejected', Colors.orange);
      _loadDetail();
    } else {
      _showSnack(result['message'] ?? 'Gagal reject', Colors.red);
    }
  }

  Future<void> _doDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Disposal?'),
        content: const Text('Data akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.destroy(widget.disposalId);
    if (result['success'] == true) {
      _showSnack('Berhasil dihapus', Colors.green);
      if (mounted) Navigator.pop(context, true);
    } else {
      _showSnack(result['message'] ?? 'Gagal', Colors.red);
    }
  }

  Future<String?> _showInputDialog(String title, {String? hintText, bool required = false}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: hintText, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Wajib diisi')));
                return;
              }
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _openPhotoViewer(List<AssetDisposalPhoto> photos, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Asset Disposal'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _disposal == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(),
                        if (_disposal!.type == 'sold') ...[
                          const SizedBox(height: 16),
                          _buildBuyerCard(),
                        ],
                        if (_disposal!.photos != null && _disposal!.photos!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildPhotoGallery(),
                        ],
                        const SizedBox(height: 16),
                        _buildApprovalFlow(),
                        const SizedBox(height: 16),
                        _buildItems(),
                        const SizedBox(height: 16),
                        _buildActions(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final d = _disposal!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(d.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: _statusColor(d.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(d.status), style: TextStyle(color: _statusColor(d.status), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: d.type == 'sold' ? Colors.blue.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(d.type == 'sold' ? 'Dijual' : 'Dibuang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: d.type == 'sold' ? Colors.blue.shade700 : Colors.grey.shade700)),
            ),
            const Divider(height: 20),
            _infoRow('Tanggal', d.date),
            _infoRow('Outlet', d.outletName ?? '-'),
            _infoRow('Warehouse', d.warehouseOutletName ?? '-'),
            _infoRow('Dibuat Oleh', d.creatorName ?? '-'),
            _infoRow('Deskripsi', d.description),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerCard() {
    final d = _disposal!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Info Pembeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
            const Divider(height: 16),
            _infoRow('Pembeli', d.buyerName ?? '-'),
            _infoRow('Kontak', d.buyerContact ?? '-'),
            _infoRow('Total Harga Jual', _formatCurrency(d.totalSalePrice)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery() {
    final photos = _disposal!.photos!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto Dokumentasi (${photos.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (_, idx) {
                return GestureDetector(
                  onTap: () => _openPhotoViewer(photos, idx),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photos[idx].url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalFlow() {
    final flows = _disposal!.approvalFlows;
    if (flows == null || flows.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approval Flow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...flows.map((flow) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _flowColor(flow.status)),
                        ),
                        if (flows.indexOf(flow) < flows.length - 1) Container(width: 2, height: 30, color: Colors.grey.shade300),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Level ${flow.approvalLevel}: ${flow.approverName ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(flow.approverJabatan ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _flowColor(flow.status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(flow.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _flowColor(flow.status))),
                          ),
                          if (flow.comments != null && flow.comments!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('"${flow.comments}"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                            ),
                          if (flow.approvedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(flow.approvedAt!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          if (flow.rejectedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(flow.rejectedAt!, style: const TextStyle(fontSize: 10, color: Colors.red)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildItems() {
    final items = _disposal!.items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${item.qty.toStringAsFixed(item.qty == item.qty.roundToDouble() ? 0 : 2)} ${item.unit}', style: const TextStyle(fontSize: 12)),
                        if (_disposal!.type == 'sold' && item.salePrice > 0) ...[
                          const Spacer(),
                          Text(_formatCurrency(item.salePrice), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade600)),
                        ],
                      ],
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.note!, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    final d = _disposal!;
    final canApprove = d.canApprove == true;
    final canDelete = d.status == 'waiting_approval';

    if (!canApprove && !canDelete) return const SizedBox.shrink();

    return Column(
      children: [
        if (canApprove) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _doApprove,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Approve', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _doReject,
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('Reject', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (canDelete)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _doDelete,
              icon: Icon(Icons.delete_forever, color: Colors.red.shade400),
              label: Text('Hapus Disposal', style: TextStyle(color: Colors.red.shade400)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<AssetDisposalPhoto> photos;
  final int initialIndex;

  const _PhotoViewerScreen({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}', style: const TextStyle(fontSize: 16)),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (_, idx) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                widget.photos[idx].url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 60),
              ),
            ),
          );
        },
      ),
    );
  }
}
