import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/outlet_transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class OutletTransferDetailScreen extends StatefulWidget {
  final int transferId;

  const OutletTransferDetailScreen({super.key, required this.transferId});

  @override
  State<OutletTransferDetailScreen> createState() => _OutletTransferDetailScreenState();
}

class _OutletTransferDetailScreenState extends State<OutletTransferDetailScreen> {
  final OutletTransferService _service = OutletTransferService();
  Map<String, dynamic>? _transfer;
  bool _canApprove = false;
  bool _isLoading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _service.getTransfer(widget.transferId);
    if (mounted) {
      setState(() {
        _transfer = result?['transfer'] ?? result;
        _canApprove = result?['can_approve'] == true;
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final approvers = await _showApproverSelect();
    if (approvers == null || approvers.isEmpty) return;
    setState(() => _actionLoading = true);
    final res = await _service.submit(widget.transferId, approvers);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil submit'), backgroundColor: Colors.green));
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
      }
    }
  }

  Future<List<int>?> _showApproverSelect() async {
    final users = await _service.getApprovers();
    final selected = <int>[];
    if (!mounted) return null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Approver (urutan = level)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      final id = u['id'] as int?;
                      final name = u['name']?.toString() ?? u['nama_lengkap']?.toString() ?? '-';
                      final isSelected = selected.contains(id);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(name),
                        onChanged: (v) {
                          setModalState(() {
                            if (v == true) {
                              selected.add(id!);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, List<int>.from(selected)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return selected.isEmpty ? null : selected;
  }

  Future<void> _approveOrReject(String action) async {
    String? comments;
    if (action == 'reject') {
      comments = await showDialog<String>(
        context: context,
        builder: (context) {
          final c = TextEditingController();
          return AlertDialog(
            title: const Text('Alasan penolakan'),
            content: TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Wajib diisi'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, c.text),
                child: const Text('Tolak'),
              ),
            ],
          );
        },
      );
      if (comments == null || comments.isEmpty) return;
    }
    setState(() => _actionLoading = true);
    final res = await _service.approve(widget.transferId, action: action, comments: comments);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'OK'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Pindah Outlet',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF6366F1)))
          : _transfer == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = _transfer!;
    final number = (t['transfer_number'] ?? '-').toString();
    final dateText = _formatDate(t['transfer_date']?.toString());
    final status = (t['status'] ?? 'draft').toString();
    final outletFromName = t['outlet_from_nama']?.toString() ?? t['warehouse_outlet_from']?['outlet']?['nama_outlet']?.toString();
    final outletToName = t['outlet_to_nama']?.toString() ?? t['warehouse_outlet_to']?['outlet']?['nama_outlet']?.toString();
    final fromName = t['warehouse_outlet_from']?['name']?.toString() ?? '-';
    final toName = t['warehouse_outlet_to']?['name']?.toString() ?? '-';
    final creator = t['creator']?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = t['creator']?['avatar']?.toString();
    final notes = t['notes']?.toString();
    final items = (t['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final flows = (t['approval_flows'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(number, dateText, status),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Informasi Outlet & Gudang',
            rows: [
              if (outletFromName != null || outletToName != null) ...[
                _InfoRow(label: 'Dari Outlet', value: outletFromName ?? '-'),
                _InfoRow(label: 'Ke Outlet', value: outletToName ?? '-'),
              ],
              _InfoRow(label: 'Warehouse Asal', value: fromName),
              _InfoRow(label: 'Warehouse Tujuan', value: toName),
              _InfoRow(label: 'Dibuat Oleh', valueWidget: _buildCreator(creator, creatorAvatar)),
              _InfoRow(label: 'Keterangan', value: (notes != null && notes.isNotEmpty) ? notes : '-'),
            ],
          ),
          if (flows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildApprovalFlowCard(flows),
          ],
          const SizedBox(height: 16),
          const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          ...items.map(_buildItemCard),
          const SizedBox(height: 24),
          if (status == 'draft')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _submit,
                icon: _actionLoading ? const SizedBox(width: 20, height: 20, child: AppLoadingIndicator(size: 18, color: Colors.white)) : const Icon(Icons.send),
                label: const Text('Submit untuk Approval'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          if (status == 'submitted' && _canApprove) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : () => _approveOrReject('approve'),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionLoading ? null : () => _approveOrReject('reject'),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String number, String date, String status) {
    Color statusBg;
    Color statusFg;
    String statusLabel;
    switch (status) {
      case 'draft':
        statusBg = const Color(0xFFF1F5F9);
        statusFg = const Color(0xFF64748B);
        statusLabel = 'Draft';
        break;
      case 'submitted':
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFFB45309);
        statusLabel = 'Menunggu Approval';
        break;
      case 'approved':
        statusBg = const Color(0xFFD1FAE5);
        statusFg = const Color(0xFF047857);
        statusLabel = 'Disetujui';
        break;
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusFg = const Color(0xFFB91C1C);
        statusLabel = 'Ditolak';
        break;
      default:
        statusBg = Colors.grey.shade200;
        statusFg = Colors.grey.shade700;
        statusLabel = status;
    }

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
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusFg)),
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
                    SizedBox(width: 120, child: Text(row.label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                    Expanded(child: row.valueWidget ?? Text(row.value ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildApprovalFlowCard(List<Map<String, dynamic>> flows) {
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
          const Text('Approver', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Daftar approver dan status persetujuan', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          ...flows.map((f) {
            final status = (f['status'] ?? '').toString();
            final approver = f['approver'] is Map ? f['approver'] as Map<String, dynamic> : null;
            final name = approver?['nama_lengkap']?.toString() ?? '-';
            final level = f['approval_level']?.toString() ?? '';
            String statusLabel = status;
            if (status == 'APPROVED') statusLabel = 'Disetujui';
            else if (status == 'REJECTED') statusLabel = 'Ditolak';
            else if (status == 'PENDING') statusLabel = 'Menunggu';
            Color statusColor = Colors.grey;
            if (status == 'APPROVED') statusColor = const Color(0xFF16A34A);
            if (status == 'REJECTED') statusColor = const Color(0xFFDC2626);
            if (status == 'PENDING') statusColor = const Color(0xFFB45309);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: statusColor.withOpacity(0.2), child: Text(level, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
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
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['item']?['name']?.toString() ?? '-';
    final sku = item['item']?['sku']?.toString() ?? '-';
    final qty = item['quantity']?.toString() ?? '0';
    final unit = item['unit']?['name']?.toString() ?? '-';
    final note = item['note']?.toString();

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
          const SizedBox(height: 4),
          Text('SKU: $sku', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPill(Icons.scale_rounded, '$qty $unit'),
              if (note != null && note.isNotEmpty) ...[const SizedBox(width: 8), _buildPill(Icons.note, note)],
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

  Widget _buildCreator(String name, String? avatarPath) {
    final initials = name.isEmpty ? 'U' : (name.trim().split(' ').length >= 2 ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase() : name[0].toUpperCase());
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE2E8F0)),
          child: ClipOval(
            child: hasAvatar
                ? CachedNetworkImage(
                    imageUrl: '${AuthService.storageUrl}/storage/$avatarPath',
                    fit: BoxFit.cover,
                    width: 24,
                    height: 24,
                    placeholder: (_, __) => _buildInitials(initials),
                    errorWidget: (_, __, ___) => _buildInitials(initials),
                  )
                : _buildInitials(initials),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildInitials(String s) {
    return Center(child: Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))));
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Data tidak ditemukan', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw ?? '-';
    }
  }
}

class _InfoRow {
  final String label;
  final String? value;
  final Widget? valueWidget;
  _InfoRow({required this.label, this.value, this.valueWidget});
}
