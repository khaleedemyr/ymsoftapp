import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/internal_warehouse_transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class InternalWarehouseTransferDetailScreen extends StatefulWidget {
  final int transferId;

  const InternalWarehouseTransferDetailScreen({super.key, required this.transferId});

  @override
  State<InternalWarehouseTransferDetailScreen> createState() => _InternalWarehouseTransferDetailScreenState();
}

class _InternalWarehouseTransferDetailScreenState extends State<InternalWarehouseTransferDetailScreen> {
  final InternalWarehouseTransferService _service = InternalWarehouseTransferService();
  Map<String, dynamic>? _transfer;
  bool _isLoading = true;

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
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Internal Warehouse Transfer',
      showDrawer: false,
      body: _isLoading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFF0EA5E9)))
          : _transfer == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = _transfer!;
    final number = (t['transfer_number'] ?? '-').toString();
    final dateText = _formatDate(t['transfer_date']?.toString());
    final outletName = t['outlet']?['nama_outlet']?.toString() ?? '-';
    final fromName = t['warehouse_outlet_from']?['name']?.toString() ?? '-';
    final toName = t['warehouse_outlet_to']?['name']?.toString() ?? '-';
    final creator = t['creator']?['nama_lengkap']?.toString() ?? '-';
    final creatorAvatar = t['creator']?['avatar']?.toString();
    final notes = t['notes']?.toString();
    final items = (t['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(number, dateText),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Informasi Outlet & Gudang',
            rows: [
              _InfoRow(label: 'Outlet', value: outletName),
              _InfoRow(label: 'Warehouse Asal', value: fromName),
              _InfoRow(label: 'Warehouse Tujuan', value: toName),
              _InfoRow(label: 'Dibuat Oleh', valueWidget: _buildCreator(creator, creatorAvatar)),
              _InfoRow(label: 'Keterangan', value: (notes != null && notes.isNotEmpty) ? notes : '-'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          ...items.map(_buildItemCard),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String number, String date) {
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
          Text(number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
          Icon(Icons.warehouse_rounded, size: 48, color: Colors.grey.shade400),
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
