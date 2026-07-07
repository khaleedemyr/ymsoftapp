import 'package:flutter/material.dart';
import '../../models/npd_plan_report_models.dart';
import '../../services/npd_plan_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'npd_plan_report_form_screen.dart';
import 'npd_plan_report_ui.dart';

class NpdPlanReportShowScreen extends StatefulWidget {
  final int recordId;

  const NpdPlanReportShowScreen({super.key, required this.recordId});

  @override
  State<NpdPlanReportShowScreen> createState() => _NpdPlanReportShowScreenState();
}

class _NpdPlanReportShowScreenState extends State<NpdPlanReportShowScreen> {
  final _service = NpdPlanReportService();

  bool _loading = true;
  bool _approving = false;
  Map<String, dynamic>? _record;
  List<NpdReportItem> _items = [];
  List<NpdApprovalFlowItem> _flows = [];
  List<Map<String, dynamic>> _purposeOptions = [];
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canApprove = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDetail(widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat detail')));
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map);
    _items = (_record!['items'] as List? ?? [])
        .map((e) => NpdReportItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _flows = (_record!['approval_flows'] as List? ?? [])
        .map((e) => NpdApprovalFlowItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _purposeOptions = (res['purpose_options'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _canEdit = res['can_edit'] == true;
    _canDelete = res['can_delete'] == true;
    _canApprove = res['can_approve'] == true;

    setState(() => _loading = false);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Report?'),
        content: Text('Report ${_record?['number']} akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _service.delete(widget.recordId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Future<void> _processApproval(String action, {bool requireComment = false}) async {
    final commentCtrl = TextEditingController();
    final titles = {
      'approve': 'Approve Report',
      'reject': 'Not Approved',
      'requires_revision': 'Requires Revision',
    };
    final hints = {
      'approve': 'Komentar (opsional)...',
      'reject': 'Alasan not approved *',
      'requires_revision': 'Catatan revisi *',
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titles[action] ?? 'Approval'),
        content: TextField(
          controller: commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: hints[action]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (requireComment && commentCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _approving = true);
    final res = await _service.approve(
      id: widget.recordId,
      action: action,
      comments: commentCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _approving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: NpdPlanReportUi.textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NpdPlanReportUi.statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        NpdPlanReportUi.statusLabel(status),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NpdPlanReportUi.statusColor(status)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _record?['status']?.toString() ?? '';
    final creator = _record?['creator'] as Map?;

    return AppScaffold(
      title: 'Detail NPD Report',
      actions: [
        if (!_loading && _canDelete)
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: NpdPlanReportUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_record?['number']?.toString() ?? '-', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                          '${NpdPlanReportUi.formatMonth(_record?['report_month']?.toString())} · ${_record?['outlet_name'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        _statusChip(status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: NpdPlanReportUi.cardDecoration,
                    child: Column(
                      children: [
                        _infoRow('Dibuat Oleh', creator?['nama_lengkap']?.toString() ?? '-'),
                        if ((_record?['notes']?.toString() ?? '').isNotEmpty)
                          _infoRow('Catatan', _record?['notes']?.toString() ?? '-'),
                      ],
                    ),
                  ),
                  if (_canApprove) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('R&D Committee Approval', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                          const SizedBox(height: 8),
                          const Text('Pilih status approval untuk report ini.', style: TextStyle(fontSize: 13, color: Color(0xFF15803D))),
                          const SizedBox(height: 12),
                          if (_approving)
                            const Center(child: AppLoadingIndicator())
                          else
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => _processApproval('approve'),
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                                    child: const Text('Approved'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => _processApproval('requires_revision', requireComment: true),
                                    style: FilledButton.styleFrom(backgroundColor: NpdPlanReportUi.primary),
                                    child: const Text('Requires Revision'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => _processApproval('reject', requireComment: true),
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                    child: const Text('Not Approved'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ] else if (_flows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: NpdPlanReportUi.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status Approval', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 12),
                          ..._flows.map((flow) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: NpdPlanReportUi.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: NpdPlanReportUi.primary,
                                    child: Text('${flow.approvalLevel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(flow.approverName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if ((flow.comments ?? '').isNotEmpty)
                                          Text(flow.comments!, style: const TextStyle(fontSize: 11, color: NpdPlanReportUi.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Text(NpdPlanReportUi.flowStatusLabel(flow.status), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Daftar Produk (${_items.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: NpdPlanReportUi.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ${item.productName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _infoRow('Category', item.category ?? '-'),
                          _infoRow('PIC', item.pics.isEmpty ? '-' : item.pics.map((p) => p.name).join(', ')),
                          _infoRow('Dev. Date', NpdPlanReportUi.formatDate(item.developmentDate)),
                          _infoRow('Purpose', NpdPlanReportUi.purposeLabel(item.purpose, _purposeOptions)),
                          _infoRow('Launch Date', NpdPlanReportUi.formatDate(item.proposedLaunchDate)),
                          _infoRow('Area / Outlet', NpdPlanReportUi.joinNames(item.launchOutlets)),
                          _infoRow('F&B Cost', NpdPlanReportUi.formatCurrency(item.fbCost)),
                          _infoRow('Selling Price', NpdPlanReportUi.formatCurrency(item.sellingPrice)),
                        ],
                      ),
                    );
                  }),
                  if (_canEdit) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => NpdPlanReportFormScreen(recordId: widget.recordId)),
                          );
                          if (mounted) _load();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Report'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
