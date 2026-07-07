import 'package:flutter/material.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import '../qa2_audit/qa2_audit_media.dart';
import '../qa2_audit/qa2_audit_ui.dart';

class Qa2CapApprovalDetailScreen extends StatefulWidget {
  final int auditId;

  const Qa2CapApprovalDetailScreen({super.key, required this.auditId});

  @override
  State<Qa2CapApprovalDetailScreen> createState() => _Qa2CapApprovalDetailScreenState();
}

class _Qa2CapApprovalDetailScreenState extends State<Qa2CapApprovalDetailScreen> {
  final _service = ApprovalService();
  Map<String, dynamic>? _audit;
  List<Map<String, dynamic>> _capItems = [];
  List<Map<String, dynamic>> _flows = [];
  bool _loading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _service.getQa2CapApprovalDetails(widget.auditId);
      if (!mounted) return;
      if (res != null && res['success'] == true) {
        setState(() {
          _audit = res['audit'] is Map ? Map<String, dynamic>.from(res['audit'] as Map) : null;
          _capItems = (res['cap_items'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _flows = (res['approval_flows'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    } catch (e) {
      debugPrint('Error loading QA2 CAP detail: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _mediaList(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _approve() async {
    if (_actionLoading) return;
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve CAP?', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final res = await _service.approveQa2Cap(widget.auditId, note: noteCtrl.text);
    setState(() => _actionLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')),
    );
    if (res['success'] == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _reject() async {
    if (_actionLoading) return;
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak CAP?', style: TextStyle(fontWeight: FontWeight.bold)),
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
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirm != true || reasonCtrl.text.trim().isEmpty) return;

    setState(() => _actionLoading = true);
    final res = await _service.rejectQa2Cap(widget.auditId, note: reasonCtrl.text.trim());
    setState(() => _actionLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')),
    );
    if (res['success'] == true) {
      Navigator.pop(context, true);
    }
  }

  Widget _mediaGrid(List<Map<String, dynamic>> medias) {
    if (medias.isEmpty) {
      return const Text('Tidak ada lampiran', style: TextStyle(fontSize: 12, color: Qa2AuditUi.slate500));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: medias.map((m) {
        final normalized = Map<String, dynamic>.from(m);
        if (normalized['url'] != null) {
          normalized['url'] = Qa2AuditUi.mediaUrl(normalized['url']);
        }
        return GestureDetector(
          onTap: () => qa2OpenMediaPreview(context, normalized),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 72, height: 72, child: qa2MediaThumbnail(normalized)),
          ),
        );
      }).toList(),
    );
  }

  Widget _capItemCard(Map<String, dynamic> item) {
    final cap = item['cap'] is Map ? Map<String, dynamic>.from(item['cap'] as Map) : <String, dynamic>{};
    final auditorMedia = _mediaList(item['auditor_media']);
    final capMedia = _mediaList(cap['media'] ?? cap['medias']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['parameter_code']?.toString() ?? '-',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Qa2AuditUi.slate500),
          ),
          const SizedBox(height: 4),
          Text(
            item['parameter_text']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Qa2AuditUi.slate900),
          ),
          if (item['category_name'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '${item['category_name']} / ${item['subcategory_name'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: Qa2AuditUi.slate500),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Temuan Auditor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                Text(item['comment']?.toString().isNotEmpty == true ? item['comment'].toString() : '-'),
                if (item['due_date'] != null) ...[
                  const SizedBox(height: 6),
                  Text('Due: ${item['due_date']}', style: const TextStyle(fontSize: 12, color: Qa2AuditUi.slate600)),
                ],
                const SizedBox(height: 8),
                _mediaGrid(auditorMedia),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Action Plan', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBE123C))),
                const SizedBox(height: 6),
                Text(cap['action_plan']?.toString().isNotEmpty == true ? cap['action_plan'].toString() : '-'),
                if (cap['target_date'] != null) ...[
                  const SizedBox(height: 6),
                  Text('Target: ${cap['target_date']}', style: const TextStyle(fontSize: 12, color: Qa2AuditUi.slate600)),
                ],
                if (cap['status'] != null) ...[
                  const SizedBox(height: 4),
                  Text('Status: ${cap['status']}', style: const TextStyle(fontSize: 12, color: Qa2AuditUi.slate600)),
                ],
                if (capMedia.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Media CAP', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFBE123C))),
                  const SizedBox(height: 6),
                  _mediaGrid(capMedia),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalFlowCard() {
    if (_flows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval Flow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._flows.map((f) {
            final status = (f['status'] ?? 'PENDING').toString().toUpperCase();
            Color color;
            switch (status) {
              case 'APPROVED':
                color = const Color(0xFF16A34A);
                break;
              case 'REJECTED':
                color = const Color(0xFFDC2626);
                break;
              default:
                color = const Color(0xFFB45309);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      f['approval_level']?.toString() ?? '',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['approver_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(status, style: TextStyle(fontSize: 11, color: color)),
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

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _actionLoading ? null : _reject,
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Tolak'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _actionLoading ? null : _approve,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: _actionLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Approve'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Approval CAP QA2',
      showDrawer: false,
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 36, color: Qa2AuditUi.primary))
          : RefreshIndicator(
              color: Qa2AuditUi.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_audit != null) ...[
                    Text(
                      _audit!['audit_number']?.toString() ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(_audit!['outlet_name']?.toString() ?? '', style: const TextStyle(color: Qa2AuditUi.slate600)),
                    Text(_audit!['template_name']?.toString() ?? '', style: const TextStyle(color: Qa2AuditUi.slate600)),
                    if (_audit!['submitter_name'] != null)
                      Text('Submitter: ${_audit!['submitter_name']}', style: const TextStyle(color: Qa2AuditUi.slate600)),
                  ],
                  const SizedBox(height: 16),
                  _approvalFlowCard(),
                  const Text('Detail CAP per Parameter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._capItems.map(_capItemCard),
                  const SizedBox(height: 16),
                  _actionButtons(),
                ],
              ),
            ),
    );
  }
}
