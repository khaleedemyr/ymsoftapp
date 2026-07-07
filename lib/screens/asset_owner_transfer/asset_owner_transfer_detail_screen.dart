import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/asset_owner_transfer_service.dart';
import '../../models/asset_owner_transfer_models.dart';
import '../../utils/asset_qty_format.dart';

class AssetOwnerTransferDetailScreen extends StatefulWidget {
  final int transferId;
  const AssetOwnerTransferDetailScreen({super.key, required this.transferId});

  @override
  State<AssetOwnerTransferDetailScreen> createState() =>
      _AssetOwnerTransferDetailScreenState();
}

class _AssetOwnerTransferDetailScreenState extends State<AssetOwnerTransferDetailScreen> {
  static const Color _violet = Color(0xFF7C3AED);

  final _service = AssetOwnerTransferService();
  AssetOwnerTransfer? _transfer;
  bool _isLoading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await _service.getTransfer(widget.transferId);
    if (data != null && mounted) {
      setState(() {
        _transfer = AssetOwnerTransfer.fromJson(data);
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return Colors.grey;
      case 'SUBMITTED':
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _approverMeta(Map<String, dynamic> u) {
    final parts = <String>[];
    final jabatan = u['jabatan']?.toString();
    final outlet = u['outlet']?.toString();
    if (jabatan != null && jabatan.isNotEmpty) parts.add(jabatan);
    if (outlet != null && outlet.isNotEmpty) parts.add(outlet);
    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  Future<List<int>?> _pickApprovers() async {
    final selected = <Map<String, dynamic>>[];
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    Timer? debounce;

    Future<void> search(String q) async {
      final users = await _service.searchApprovers(q);
      results = users.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    await search('');

    if (!mounted) return null;

    final ids = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void moveApprover(int idx, int dir) {
              final newIdx = idx + dir;
              if (newIdx < 0 || newIdx >= selected.length) return;
              final tmp = selected[idx];
              selected[idx] = selected[newIdx];
              selected[newIdx] = tmp;
              setModalState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Submit untuk Approval',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Pilih approver berurutan (level 1 = pertama).',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Cari approver (nama / jabatan / outlet)...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (q) {
                          debounce?.cancel();
                          debounce = Timer(const Duration(milliseconds: 400), () async {
                            await search(q);
                            setModalState(() {});
                          });
                        },
                      ),
                    ),
                    if (selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: selected.asMap().entries.map((e) {
                            final idx = e.key;
                            final a = e.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _violet.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _violet.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _violet,
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a['name']?.toString() ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          _approverMeta(a),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                                    onPressed: idx == 0 ? null : () => moveApprover(idx, -1),
                                    color: _violet,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                    onPressed: idx == selected.length - 1
                                        ? null
                                        : () => moveApprover(idx, 1),
                                    color: _violet,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                    onPressed: () => setModalState(() => selected.removeAt(idx)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final u = results[i];
                          final uid = int.tryParse(u['id'].toString()) ?? 0;
                          final isSel =
                              selected.any((a) => int.tryParse(a['id'].toString()) == uid);
                          return ListTile(
                            leading: Icon(
                              isSel ? Icons.check_box : Icons.check_box_outline_blank,
                              color: isSel ? _violet : Colors.grey,
                            ),
                            title: Text(u['name']?.toString() ?? ''),
                            subtitle: Text(_approverMeta(u)),
                            onTap: () {
                              setModalState(() {
                                final idx = selected.indexWhere(
                                    (a) => int.tryParse(a['id'].toString()) == uid);
                                if (idx >= 0) {
                                  selected.removeAt(idx);
                                } else {
                                  selected.add(u);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(
                                        ctx,
                                        selected
                                            .map((a) =>
                                                int.tryParse(a['id'].toString()) ?? 0)
                                            .where((id) => id > 0)
                                            .toList(),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _violet,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    debounce?.cancel();
    return ids;
  }

  Future<void> _submitDraft() async {
    final savedFlows = _transfer?.approvalFlows ?? [];
    List<int>? approvers;

    if (savedFlows.isEmpty) {
      approvers = await _pickApprovers();
      if (approvers == null || approvers.isEmpty) return;
    } else {
      final flowLines = savedFlows
          .map((f) => 'Level ${f.approvalLevel}: ${f.approverName ?? '-'}')
          .join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit untuk Approval?'),
          content: Text(
            'Approver sudah dipilih saat create:\n\n$flowLines',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: _violet),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _actionLoading = true);
    final result = await _service.submit(widget.transferId, approvers: approvers);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Berhasil submit.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal submit.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleApproval(String action) async {
    String? comments;

    if (action == 'reject') {
      comments = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Reject Transfer'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Alasan penolakan (wajib)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alasan wajib diisi.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, controller.text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
      if (comments == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve Transfer?'),
          content: const Text('Anda yakin ingin menyetujui transfer ini?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: _violet),
              child: const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _actionLoading = true);
    final result = await _service.approve(widget.transferId, action, comments: comments);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Berhasil.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTransfer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transfer?'),
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

    setState(() => _actionLoading = true);
    final result = await _service.deleteTransfer(widget.transferId);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer dihapus.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = _transfer?.status.toLowerCase() == 'draft';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transfer Kepemilikan'),
        backgroundColor: _violet,
        foregroundColor: Colors.white,
        actions: [
          if (_transfer != null && isDraft)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _actionLoading ? null : _deleteTransfer,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transfer == null
              ? const Center(child: Text('Data tidak ditemukan.'))
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _transfer!.transferNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: _violet,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(_transfer!.status)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _transfer!.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(_transfer!.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _infoRow('Tanggal', _transfer!.transferDate),
                                _infoRow('Pemilik Asal', _transfer!.ownerFromName ?? '-'),
                                _infoRow('Pemilik Tujuan', _transfer!.ownerToName ?? '-'),
                                _infoRow('Lokasi', _transfer!.locationOutletName ?? '-'),
                                _infoRow('Gudang', _transfer!.warehouseOutletName ?? '-'),
                                _infoRow('Dibuat Oleh', _transfer!.creatorName ?? '-'),
                                if (_transfer!.notes != null && _transfer!.notes!.isNotEmpty)
                                  _infoRow('Catatan', _transfer!.notes!),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isDraft)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _actionLoading ? null : _submitDraft,
                              icon: _actionLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send, size: 18),
                              label: const Text('Submit untuk Approval'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        if (isDraft) const SizedBox(height: 12),
                        if (_transfer!.canApprove)
                          Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            color: _violet.withOpacity(0.08),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _actionLoading
                                          ? null
                                          : () => _handleApproval('approve'),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _actionLoading
                                          ? null
                                          : () => _handleApproval('reject'),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_transfer!.canApprove) const SizedBox(height: 12),
                        if (_transfer!.approvalFlows.isNotEmpty)
                          Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Approval Flow',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _violet)),
                                  const SizedBox(height: 12),
                                  ..._transfer!.approvalFlows.map((flow) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: _statusColor(flow.status)
                                                .withOpacity(0.3)),
                                        borderRadius: BorderRadius.circular(10),
                                        color: _statusColor(flow.status)
                                            .withOpacity(0.05),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: _statusColor(flow.status),
                                            child: Text(
                                              '${flow.approvalLevel}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  flow.approverName ?? '-',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14),
                                                ),
                                                Text(
                                                  flow.approverJabatan ?? '-',
                                                  style: const TextStyle(
                                                      fontSize: 12, color: Colors.grey),
                                                ),
                                                if (flow.comments != null &&
                                                    flow.comments!.isNotEmpty)
                                                  Text(
                                                    '"${flow.comments}"',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontStyle: FontStyle.italic,
                                                        color: Colors.black54),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _statusColor(flow.status)
                                                  .withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              flow.status,
                                              style: TextStyle(
                                                color: _statusColor(flow.status),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Item Transfer',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _violet)),
                                const SizedBox(height: 12),
                                ..._transfer!.items.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final item = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: _violet.withOpacity(0.15),
                                          child: Text('${idx + 1}',
                                              style: const TextStyle(
                                                  fontSize: 12, color: _violet)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.itemName ?? '-',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14)),
                                              Text(
                                                'Qty: ${formatAssetQtyWithUnit(item.qty, item.unitName)}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black87),
                                              ),
                                              if (item.note != null &&
                                                  item.note!.isNotEmpty)
                                                Text(item.note!,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey)),
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
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
