import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/lost_breakage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'lost_breakage_form_screen.dart';

class LostBreakageDetailScreen extends StatefulWidget {
  final int headerId;
  const LostBreakageDetailScreen({super.key, required this.headerId});

  @override
  State<LostBreakageDetailScreen> createState() => _LostBreakageDetailScreenState();
}

class _LostBreakageDetailScreenState extends State<LostBreakageDetailScreen> {
  final LostBreakageService _service = LostBreakageService();
  Map<String, dynamic>? _header;
  List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _flows = [];
  bool _loading = true;
  bool _actionLoading = false;
  bool _canRecordReplacements = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _service.getDetail(widget.headerId);
      if (!mounted) return;
      if (res != null && res['success'] == true) {
        setState(() {
          _header = res['header'] is Map ? Map<String, dynamic>.from(res['header']) : null;
          _details = (res['details'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _flows = (res['approval_flows'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _canRecordReplacements = res['can_record_replacements'] == true;
        });
      }
    } catch (e) {
      debugPrint('Error loading detail: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approve() async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteCtrl,
          decoration: InputDecoration(
            labelText: 'Catatan (opsional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _actionLoading = true);
    final res = await _service.approve(widget.headerId, note: noteCtrl.text);
    setState(() => _actionLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Gagal')));
      if (res?['success'] == true) _load();
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: 'Alasan penolakan (wajib)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirm != true || reasonCtrl.text.isEmpty) return;
    setState(() => _actionLoading = true);
    final res = await _service.reject(widget.headerId, reason: reasonCtrl.text);
    setState(() => _actionLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Gagal')));
      if (res?['success'] == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail Lost & Breakage',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 26, color: Color(0xFFE65100)))
          : _header == null
              ? _buildEmpty()
              : RefreshIndicator(color: const Color(0xFFE65100), onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final status = _header!['status']?.toString().toUpperCase() ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildHeaderCard(status),
        const SizedBox(height: 16),
        _buildInfoCard(),
        if (_flows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildApprovalFlowCard(),
        ],
        const SizedBox(height: 16),
        const Text('Detail Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        ..._details.map(_buildItemCard),
        const SizedBox(height: 24),
        if (status == 'SUBMITTED') _buildActionButtons(),
        if (status == 'DRAFT') _buildEditButton(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeaderCard(String status) {
    final number = _header!['number']?.toString() ?? '-';
    final dateText = _formatDate(_header!['date']?.toString());
    final statusInfo = _getStatusStyle(status);

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
                decoration: BoxDecoration(color: statusInfo.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(statusInfo.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusInfo.fg)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final creator = _header!['creator_name']?.toString() ?? '-';
    final creatorAvatar = _header!['creator_avatar']?.toString();
    final notes = _header!['notes']?.toString();

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
          _buildInfoRow('Outlet', _header!['outlet_name']?.toString() ?? '-'),
          _buildInfoRow('Dibuat Oleh', null, valueWidget: _buildCreator(creator, creatorAvatar)),
          if (notes != null && notes.isNotEmpty) _buildInfoRow('Catatan', notes),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, {Widget? valueWidget}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
          Expanded(child: valueWidget ?? Text(value ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildCreator(String name, String? avatarPath) {
    final initials = name.isEmpty
        ? 'U'
        : (name.trim().split(' ').length >= 2
            ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase()
            : name[0].toUpperCase());
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
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildInitials(String s) {
    return Center(child: Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))));
  }

  Widget _buildApprovalFlowCard() {
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
          const Text('Approval Flow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Daftar approver dan status persetujuan', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          ..._flows.map(_buildFlowTile),
        ],
      ),
    );
  }

  Widget _buildFlowTile(Map<String, dynamic> f) {
    final status = (f['status'] ?? 'PENDING').toString().toUpperCase();
    final name = f['approver_name']?.toString() ?? '-';
    final jabatan = f['approver_jabatan']?.toString();
    final level = f['approval_level']?.toString() ?? '';
    final comments = f['comments']?.toString();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'APPROVED':
        statusColor = const Color(0xFF16A34A);
        statusLabel = 'Disetujui';
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Ditolak';
        break;
      default:
        statusColor = const Color(0xFFB45309);
        statusLabel = 'Menunggu';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withOpacity(0.2),
            child: Text(level, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                if (jabatan != null && jabatan.isNotEmpty)
                  Text(jabatan, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
                if (f['approved_at'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Approved: ${_formatDateTime(f['approved_at'].toString())}', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                  ),
                if (f['rejected_at'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Rejected: ${_formatDateTime(f['rejected_at'].toString())}', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                  ),
                if (comments != null && comments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('"$comments"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReplacementDialog(Map<String, dynamic> detail) async {
    final detailId = int.tryParse(detail['id'].toString()) ?? 0;
    final unitId = int.tryParse(detail['unit_id'].toString()) ?? 0;
    final qtyLine = double.tryParse(detail['qty']?.toString() ?? '0') ?? 0;
    final repSum =
        double.tryParse(detail['replaced_qty_total']?.toString() ?? '0') ?? 0;
    final remaining = detail['remaining_qty'] != null
        ? (double.tryParse(detail['remaining_qty'].toString()) ??
            (qtyLine - repSum))
        : (qtyLine - repSum);

    if (remaining <= 1e-9 || detailId == 0 || unitId == 0) return;

    final qtyCtrl = TextEditingController(
      text: (remaining >= 1 ? 1.0 : remaining).toString(),
    );
    final noteCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    int? selectedReplacementItemId;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Catat penggantian',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sisa: ${remaining.toStringAsFixed(4)} ${detail['unit_name'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Qty pengganti *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Item pengganti (opsional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'SKU / nama...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              final r = await _service
                                  .getAssetItems(search: searchCtrl.text);
                              setSt(() => results = r);
                            },
                          ),
                        ],
                      ),
                      if (selectedReplacementItemId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Item terpilih: #$selectedReplacementItemId',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF047857)),
                          ),
                        ),
                      SizedBox(
                        height: 120,
                        child: results.isEmpty
                            ? const Center(
                                child: Text('Cari lalu tap hasil',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)))
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (_, i) {
                                  final it = results[i];
                                  final id =
                                      int.tryParse(it['id'].toString()) ?? 0;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                        it['name']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(
                                        it['sku']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 11)),
                                    onTap: () {
                                      selectedReplacementItemId = id;
                                      setSt(() {});
                                    },
                                  );
                                },
                              ),
                      ),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final q = double.tryParse(qtyCtrl.text) ?? 0;
                    if (q <= 0 || q > remaining + 1e-6) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Qty tidak valid')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, {
                      'qty': q,
                      'replacement_item_id': selectedReplacementItemId,
                      'note': noteCtrl.text.trim(),
                    });
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    qtyCtrl.dispose();
    noteCtrl.dispose();
    searchCtrl.dispose();

    if (payload == null || !mounted) return;

    setState(() => _actionLoading = true);
    final res = await _service.storeReplacement(
      widget.headerId,
      detailId,
      qtyReplaced: (payload['qty'] as num).toDouble(),
      unitId: unitId,
      replacementItemId: payload['replacement_item_id'] as int?,
      note: (payload['note'] as String?)?.isNotEmpty == true
          ? payload['note'] as String
          : null,
    );
    setState(() => _actionLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res?['message'] ?? 'Gagal')),
    );
    if (res?['success'] == true) _load();
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['item_name']?.toString() ?? '-';
    final type = item['type']?.toString() ?? 'lost';
    final qty = item['qty']?.toString() ?? '0';
    final unit = item['unit_name']?.toString() ?? '';
    final note = item['note']?.toString();
    final hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
    final reps = (item['replacements'] as List?) ?? [];
    final repTotal =
        double.tryParse(item['replaced_qty_total']?.toString() ?? '0') ?? 0;
    final remaining =
        double.tryParse(item['remaining_qty']?.toString() ?? '') ??
            (double.tryParse(qty) ?? 0) - repTotal;
    final fulfillment = item['replacement_fulfillment']?.toString() ?? 'none';

    Color typeBg;
    Color typeFg;
    String typeLabel;
    if (type == 'breakage') {
      typeBg = const Color(0xFFFEE2E2);
      typeFg = const Color(0xFFB91C1C);
      typeLabel = 'Breakage';
    } else {
      typeBg = const Color(0xFFFEF3C7);
      typeFg = const Color(0xFFB45309);
      typeLabel = 'Lost';
    }

    String fulLabel;
    Color fulBg;
    Color fulFg;
    switch (fulfillment) {
      case 'complete':
        fulLabel = 'Pengganti lengkap';
        fulBg = const Color(0xFFD1FAE5);
        fulFg = const Color(0xFF047857);
        break;
      case 'partial':
        fulLabel = 'Pengganti parsial';
        fulBg = const Color(0xFFFEF3C7);
        fulFg = const Color(0xFFB45309);
        break;
      default:
        fulLabel = 'Belum pengganti';
        fulBg = const Color(0xFFF1F5F9);
        fulFg = const Color(0xFF64748B);
    }

    final showRepBtn =
        _canRecordReplacements && remaining > 1e-6;

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
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(999)),
                child: Text(typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: typeFg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPill(Icons.scale_rounded, '$qty $unit'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: fulBg, borderRadius: BorderRadius.circular(999)),
                child: Text(fulLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fulFg)),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPill(Icons.note, note),
          ],
          if (repTotal > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Terpenuhi: ${repTotal.toStringAsFixed(4)} / $qty  ·  Sisa: ${remaining.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
          if (reps.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Riwayat penggantian', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            ...reps.map((r) {
              final m = r is Map<String, dynamic>
                  ? r
                  : Map<String, dynamic>.from(r as Map);
              final q = m['qty_replaced']?.toString() ?? '';
              final rn = m['replacement_item_name']?.toString();
              final by = m['replaced_by_name']?.toString() ?? '';
              final line = rn != null && rn.isNotEmpty
                  ? '$q — $rn'
                  : '$q (identik)';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $line${by.isNotEmpty ? ' · $by' : ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
              );
            }),
          ],
          if (hasPhoto) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showPhotoDialog(item['photo'].toString()),
              child: Row(
                children: [
                  const Icon(Icons.photo_outlined, size: 14, color: Color(0xFFE65100)),
                  const SizedBox(width: 4),
                  const Text('Lihat Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                ],
              ),
            ),
          ],
          if (showRepBtn) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _actionLoading ? null : () => _openReplacementDialog(item),
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('Catat penggantian'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(color: Color(0xFFE65100)),
                ),
              ),
            ),
          ],
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
          Flexible(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _actionLoading ? null : _approve,
            icon: _actionLoading
                ? const SizedBox(width: 18, height: 18, child: AppLoadingIndicator(size: 18, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _actionLoading ? null : _reject,
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => LostBreakageFormScreen(headerId: widget.headerId)));
          if (result == true && mounted) _load();
        },
        icon: const Icon(Icons.edit),
        label: const Text('Edit Draft'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showPhotoDialog(String path) {
    final url = '${AuthService.storageUrl}/storage/$path';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFE65100),
              child: Row(
                children: [
                  const Expanded(child: Text('Foto Bukti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Padding(padding: EdgeInsets.all(32), child: AppLoadingIndicator(size: 24, color: Color(0xFFE65100))),
              errorWidget: (_, __, ___) => const Padding(padding: EdgeInsets.all(32), child: Icon(Icons.broken_image, size: 48, color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Data tidak ditemukan', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  _StatusStyle _getStatusStyle(String status) {
    switch (status) {
      case 'DRAFT':
        return _StatusStyle(const Color(0xFFF1F5F9), const Color(0xFF64748B), 'Draft');
      case 'SUBMITTED':
        return _StatusStyle(const Color(0xFFFEF3C7), const Color(0xFFB45309), 'Menunggu Approval');
      case 'APPROVED':
        return _StatusStyle(const Color(0xFFD1FAE5), const Color(0xFF047857), 'Disetujui');
      case 'REJECTED':
        return _StatusStyle(const Color(0xFFFEE2E2), const Color(0xFFB91C1C), 'Ditolak');
      default:
        return _StatusStyle(const Color(0xFFF1F5F9), const Color(0xFF64748B), status);
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

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

class _StatusStyle {
  final Color bg;
  final Color fg;
  final String label;
  _StatusStyle(this.bg, this.fg, this.label);
}

