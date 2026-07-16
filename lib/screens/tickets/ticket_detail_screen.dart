import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/ticket_due_date.dart';
import '../../utils/ticket_permissions.dart';
import '../../utils/ticket_status.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/tickets/ticket_status_change_dialog.dart';
import '../it_work_report/it_work_report_form_screen.dart';
import 'ticket_editor_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  final TicketService _svc = TicketService();
  final TextEditingController _comment = TextEditingController();

  Map<String, dynamic>? _ticket;
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;
  bool _workExecutorSaving = false;
  String? _error;
  bool _canManageTickets = false;
  Map<String, dynamic>? _userData;
  late TabController _tab;
  List<File> _commentFiles = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await _svc.getTicket(widget.ticketId);
    if (!mounted) return;
    if (r['success'] != true) {
      setState(() {
        _loading = false;
        _error = r['message']?.toString() ?? 'Gagal memuat';
      });
      return;
    }
    bool canManage = false;
    if (r.containsKey('can_manage_tickets')) {
      final v = r['can_manage_tickets'];
      canManage = v == true || v == 1;
    } else {
      final u = await AuthService().getUserData();
      _userData = u;
      canManage = TicketPermissions.userCanManage(u);
    }
    if (_userData == null) {
      _userData = await AuthService().getUserData();
    }
    _ticket = r['ticket'] as Map<String, dynamic>?;
    _canManageTickets = canManage;
    final cr = await _svc.getComments(widget.ticketId);
    if (!mounted) return;
    if (cr['success'] == true) {
      _comments = cr['data'] as List<dynamic>? ?? [];
    }
    setState(() => _loading = false);
  }

  Future<void> _openUrl(String path) async {
    final u = TicketService.attachmentUrl(path);
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _canUpdateStatus =>
      TicketPermissions.ticketCanUpdateStatus(_ticket, _userData);

  bool get _canManageTicket =>
      TicketPermissions.ticketCanManage(_ticket, _userData);

  bool get _canUpdateVendorName =>
      TicketPermissions.ticketCanUpdateVendorName(_ticket, _userData);

  bool get _canSetWorkExecutorType =>
      TicketPermissions.ticketCanSetWorkExecutorType(_ticket, _userData);

  Future<void> _promptVendorName() async {
    final ctrl = TextEditingController(text: _ticket?['vendor_name']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nama Vendor'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nama vendor (opsional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final name = ctrl.text.trim();
    final res = await _svc.updateVendorName(widget.ticketId, name.isEmpty ? null : name);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _ticket!['vendor_name'] = name.isEmpty ? null : name);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama vendor diperbarui')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')),
      );
    }
  }

  Future<void> _changeStatus() async {
    final opt = await _svc.getFormOptions();
    if (opt['success'] != true || !mounted) return;
    final statuses = opt['statuses'] as List<dynamic>? ?? [];
    final current = _ticket?['status'] is Map ? (_ticket!['status']['id'] as num?)?.toInt() : null;
    final currentSlug =
        _ticket?['status'] is Map ? _ticket!['status']['slug']?.toString() : null;

    final chosen = await showTicketStatusChangeDialog(
      context: context,
      statuses: statuses,
      currentStatusId: current,
      currentStatusSlug: currentSlug,
    );
    if (chosen == null || chosen.statusId == current || !mounted) return;

    final res = await _svc.updateStatus(
      widget.ticketId,
      chosen.statusId,
      closeNote: chosen.closeNote,
      closeEvidenceFiles:
          chosen.closeEvidenceFiles.isEmpty ? null : chosen.closeEvidenceFiles,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status diperbarui')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')),
      );
    }
  }

  Future<void> _updateWorkExecutorType(String? value) async {
    if (_ticket == null || _workExecutorSaving) return;
    final current = _ticket!['work_executor_type']?.toString();
    if ((current ?? '') == (value ?? '')) return;

    String? vendorName = _ticket!['vendor_name']?.toString();
    if (value == 'external_vendor') {
      final ctrl = TextEditingController(text: vendorName ?? '');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('External Vendor'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Nama vendor (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      vendorName = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    }

    setState(() => _workExecutorSaving = true);
    final res = await _svc.updateWorkExecutorType(
      widget.ticketId,
      value,
      vendorName: value == 'external_vendor' ? vendorName : null,
    );
    if (!mounted) return;
    setState(() => _workExecutorSaving = false);
    if (res['success'] == true) {
      setState(() {
        _ticket!['work_executor_type'] = value;
        _ticket!['work_executor_type_label'] = TicketPermissions.workExecutorTypeLabel(value);
        _ticket!['vendor_name'] = value == 'external_vendor' ? vendorName : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Dikerjakan oleh diperbarui')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal memperbarui')),
      );
    }
  }

  Future<void> _assignTeam() async {
    final opt = await _svc.getFormOptions();
    if (opt['success'] != true || !mounted) return;
    final users = opt['assignable_users'] as List<dynamic>? ?? [];
    final assigned = _ticket?['assigned_users'] as List<dynamic>? ?? [];
    final pre = assigned.map((u) => (u['id'] as num).toInt()).toSet();
    final sel = Set<int>.from(pre);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Assign tim'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: users.map((u) {
                  final m = u as Map<String, dynamic>;
                  final id = (m['id'] as num).toInt();
                  final name = m['nama_lengkap']?.toString() ?? '';
                  return CheckboxListTile(
                    value: sel.contains(id),
                    title: Text(name),
                    onChanged: (v) {
                      setSt(() {
                        if (v == true) {
                          sel.add(id);
                        } else {
                          sel.remove(id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                onPressed: () {
                  if (sel.isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || sel.isEmpty) {
      if (confirmed == true && sel.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal satu user')));
      }
      return;
    }
    final ids = sel.toList();
    final res = await _svc.assignTeam(
      widget.ticketId,
      userIds: ids,
      primaryUserId: ids.first,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team di-assign')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus ticket?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _svc.deleteTicket(widget.ticketId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')),
      );
    }
  }

  Future<void> _sendComment() async {
    final t = _comment.text.trim();
    if (t.isEmpty && _commentFiles.isEmpty) return;
    setState(() => _sending = true);
    final res = await _svc.addComment(
      widget.ticketId,
      comment: t.isEmpty ? null : t,
      files: _commentFiles.isEmpty ? null : _commentFiles,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      _comment.clear();
      _commentFiles = [];
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal kirim')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detail ticket',
      showDrawer: false,
      actions: _loading || _ticket == null
          ? null
          : [
              if (_canManageTicket)
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketEditorScreen(initialTicket: _ticket),
                      ),
                    );
                    if (ok == true && mounted) _load();
                  },
                ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'status') _changeStatus();
                  if (v == 'del') _delete();
                  if (v == 'it_work') {
                    final t = _ticket!;
                    final outletRaw = t['outlet_id'] ?? t['id_outlet'];
                    final outletId = outletRaw is int
                        ? outletRaw
                        : int.tryParse(outletRaw?.toString() ?? '');
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItWorkReportFormScreen(
                          prefillTicketId: widget.ticketId,
                          prefillTicketNumber: t['ticket_number']?.toString(),
                          prefillTicketTitle: t['title']?.toString(),
                          prefillOutletId: outletId,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (_canUpdateStatus)
                    const PopupMenuItem(value: 'status', child: Text('Ubah status')),
                  const PopupMenuItem(value: 'it_work', child: Text('Buat IT Work Report')),
                  if (_canManageTickets)
                    const PopupMenuItem(value: 'del', child: Text('Hapus ticket')),
                ],
              ),
            ],
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 36, color: Color(0xFF4F46E5), useLogo: false))
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: _header(),
                      ),
                    ),
                    TabBar(
                      controller: _tab,
                      labelColor: const Color(0xFF4F46E5),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF4F46E5),
                      tabs: const [
                        Tab(text: 'Komentar'),
                        Tab(text: 'Riwayat'),
                      ],
                    ),
                    Expanded(
                      flex: 4,
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _commentsTab(),
                          _historyTab(),
                        ],
                      ),
                    ),
                    _commentBar(),
                  ],
                ),
    );
  }

  Widget _header() {
    final t = _ticket!;
    final num = t['ticket_number']?.toString() ?? '';
    final title = t['title']?.toString() ?? '';
    final statusSlugRaw = t['status'] is Map ? t['status']['slug']?.toString() : null;
    final statusSlug = normalizeTicketStatusSlug(statusSlugRaw);
    final st = displayTicketStatusName(
      t['status'] is Map ? t['status']['name']?.toString() : null,
      statusSlugRaw,
    );
    final pr = t['priority'] is Map ? t['priority']['name']?.toString() : null;
    final div = t['divisi'] is Map ? t['divisi']['nama_divisi']?.toString() : null;
    final out = t['outlet'] is Map ? t['outlet']['nama_outlet']?.toString() : null;
    final due = t['due_date']?.toString();
    final closedAt = t['closed_at']?.toString();
    final resolvedAt = t['resolved_at']?.toString();
    final desc = t['description']?.toString() ?? '';

    final assignees = t['assigned_users'] as List<dynamic>? ?? [];
    final pay = t['payment_info'] as List<dynamic>? ?? [];
    final atts = t['attachments'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (st != null) _chip(st, const Color(0xFFE0E7FF)),
              if (pr != null) _chip(pr, const Color(0xFFFEF3C7)),
              if (div != null) _chip(div, const Color(0xFFF1F5F9)),
              if (out != null) _chip(out, const Color(0xFFECFDF5)),
              if (due != null && due.isNotEmpty)
                TicketDueDateRow(
                  dueIso: due,
                  statusSlug: statusSlug,
                  closedAtIso: closedAt,
                  resolvedAtIso: resolvedAt,
                  dateLabel: _fmt(due),
                  fontSize: 11,
                  expandDateToFit: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(desc, style: const TextStyle(height: 1.45, fontSize: 14)),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dikerjakan Oleh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                if (_canSetWorkExecutorType)
                  DropdownButtonFormField<String?>(
                    value: t['work_executor_type']?.toString(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text('— Pilih —')),
                      DropdownMenuItem<String?>(value: 'internal', child: Text('Internal')),
                      DropdownMenuItem<String?>(value: 'external_vendor', child: Text('External Vendor')),
                    ],
                    onChanged: _workExecutorSaving ? null : _updateWorkExecutorType,
                  )
                else
                  Text(
                    t['work_executor_type_label']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 14),
                  ),
                if (_canSetWorkExecutorType)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Hanya divisi terkait yang dapat mengisi.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                if (t['work_executor_type']?.toString() == 'external_vendor') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t['vendor_name']?.toString().isNotEmpty == true
                              ? t['vendor_name'].toString()
                              : '— belum ada nama vendor —',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_canUpdateVendorName)
                        TextButton(
                          onPressed: _workExecutorSaving ? null : _promptVendorName,
                          child: Text(t['vendor_name']?.toString().isNotEmpty == true ? 'Ubah' : 'Input'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (assignees.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Tim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: assignees
                  .map((u) => Chip(
                        label: Text((u['nama_lengkap'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          if (pay.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('PR terkait', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            ...pay.map((p) {
              final m = p as Map<String, dynamic>;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(m['pr_number']?.toString() ?? ''),
                subtitle: Text('${m['status']} · ${m['payment_status']}'),
              );
            }),
          ],
          if (atts.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Lampiran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            ...atts.map((a) {
              final m = a as Map<String, dynamic>;
              final name = m['file_name']?.toString() ?? 'file';
              final path = m['file_path']?.toString() ?? '';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_rounded, size: 20),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: path.isEmpty ? null : () => _openUrl(path),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _fmt(String iso) {
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Widget _commentsTab() {
    if (_comments.isEmpty) {
      return const Center(child: Text('Belum ada komentar'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _comments.length,
      itemBuilder: (_, i) {
        final c = _comments[i] as Map<String, dynamic>;
        final user = c['user'] is Map ? c['user']['nama_lengkap']?.toString() : null;
        final text = c['comment']?.toString() ?? '';
        final at = c['created_at']?.toString();
        final subs = c['attachments'] as List<dynamic>? ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE0E7FF),
                        child: Text(
                          () {
                            final u = user ?? '?';
                            return u.isNotEmpty ? u[0].toUpperCase() : '?';
                          }(),
                          style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            if (at != null)
                              Text(_fmt(at), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(text, style: const TextStyle(height: 1.4)),
                  ],
                  ...subs.map((a) {
                    final m = a as Map<String, dynamic>;
                    final name = m['file_name']?.toString() ?? '';
                    final path = m['file_path']?.toString() ?? '';
                    return TextButton.icon(
                      onPressed: path.isEmpty ? null : () => _openUrl(path),
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _historyTab() {
    final hist = _ticket?['history'] as List<dynamic>? ?? [];
    if (hist.isEmpty) return const Center(child: Text('Tidak ada riwayat'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: hist.length,
      itemBuilder: (_, i) {
        final h = hist[i] as Map<String, dynamic>;
        final desc = h['description']?.toString() ?? '';
        final user = h['user'] is Map ? h['user']['nama_lengkap']?.toString() : null;
        final at = h['created_at']?.toString();
        return ListTile(
          leading: const Icon(Icons.history_rounded, color: Color(0xFF94A3B8)),
          title: Text(desc, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${user ?? '-'} · ${at != null ? _fmt(at) : ''}'),
        );
      },
    );
  }

  Widget _commentBar() {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _sending
                    ? null
                    : () async {
                        final r = await FilePicker.platform.pickFiles(allowMultiple: true);
                        if (r == null) return;
                        setState(() {
                          for (final f in r.files) {
                            final p = f.path;
                            if (p != null) _commentFiles.add(File(p));
                          }
                        });
                      },
                icon: const Icon(Icons.attach_file_rounded),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_commentFiles.isNotEmpty)
                      Text('${_commentFiles.length} file', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    TextField(
                      controller: _comment,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar…',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                onPressed: _sending ? null : _sendComment,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
