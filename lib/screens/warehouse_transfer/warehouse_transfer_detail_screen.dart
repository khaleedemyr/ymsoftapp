import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/warehouse_transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class WarehouseTransferDetailScreen extends StatefulWidget {
  final int transferId;

  const WarehouseTransferDetailScreen({super.key, required this.transferId});

  @override
  State<WarehouseTransferDetailScreen> createState() => _WarehouseTransferDetailScreenState();
}

class _WarehouseTransferDetailScreenState extends State<WarehouseTransferDetailScreen> {
  final WarehouseTransferService _service = WarehouseTransferService();
  Map<String, dynamic>? _transfer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _service.getTransfer(widget.transferId);
    if (mounted) {
      setState(() {
        _transfer = result?['transfer'] ?? result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Pindah Gudang',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF6366F1)))
          : _transfer == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final transfer = _transfer!;
    final transferNumber = (transfer['transfer_number'] ?? '-').toString();
    final dateText = _formatDate(transfer['transfer_date']?.toString());
    final status = (transfer['status'] ?? 'draft').toString();
    final fromName = transfer['warehouse_from']?['name']?.toString() ?? '-';
    final toName = transfer['warehouse_to']?['name']?.toString() ?? '-';
    final creator = transfer['creator']?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = transfer['creator']?['avatar']?.toString();
    final notes = transfer['notes']?.toString();
    final items = (transfer['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(transferNumber, dateText, status),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Informasi Gudang',
            rows: [
              _InfoRow(label: 'Gudang Asal', value: fromName),
              _InfoRow(label: 'Gudang Tujuan', value: toName),
              _InfoRow(label: 'Dibuat Oleh', valueWidget: _buildCreatorValue(creator, creatorAvatar)),
              _InfoRow(label: 'Keterangan', value: notes?.isNotEmpty == true ? notes! : '-'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Detail Item',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),
          ...items.map(_buildItemCard).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String number, String date, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              _buildStatusChip(status),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      row.label,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  Expanded(
                    child: row.valueWidget ?? Text(
                      row.value ?? '',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('SKU: $sku', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPill(Icons.scale_rounded, '$qty $unit'),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildPill(Icons.note_outlined, note),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildCreatorValue(String name, String? avatarPath) {
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
    final initials = _getInitials(name);

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE2E8F0),
          ),
          child: ClipOval(
            child: hasAvatar
                ? CachedNetworkImage(
                    imageUrl: '${AuthService.storageUrl}/storage/$avatarPath',
                    fit: BoxFit.cover,
                    width: 22,
                    height: 22,
                    placeholder: (context, url) => _buildInitialsCircle(initials),
                    errorWidget: (context, url, error) => _buildInitialsCircle(initials),
                  )
                : _buildInitialsCircle(initials),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsCircle(String initials) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFE2E8F0),
      child: Text(
        initials,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
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
      final date = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return raw;
    }
  }
}

class _InfoRow {
  final String label;
  final String? value;
  final Widget? valueWidget;

  _InfoRow({required this.label, this.value, this.valueWidget});
}
