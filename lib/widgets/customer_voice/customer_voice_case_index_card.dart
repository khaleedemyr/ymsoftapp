import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/auth_service.dart';
import '../../services/customer_voice_command_center_service.dart';
import 'customer_voice_index_helpers.dart';
import 'notify_user_multi_picker.dart';

/// Kartu satu baris daftar — selaras kolom tabel web + Regional & CS PIC di indeks.
class CustomerVoiceCaseIndexCard extends StatefulWidget {
  const CustomerVoiceCaseIndexCard({
    super.key,
    required this.dashboard,
    required this.item,
    required this.service,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  final CustomerVoiceDashboard dashboard;
  final CustomerVoiceCaseItem item;
  final CustomerVoiceCommandCenterService service;
  final VoidCallback onRefresh;
  final void Function(CustomerVoiceCaseItem item) onOpenDetail;

  @override
  State<CustomerVoiceCaseIndexCard> createState() =>
      _CustomerVoiceCaseIndexCardState();
}

class _CustomerVoiceCaseIndexCardState
    extends State<CustomerVoiceCaseIndexCard> {
  static const _divisions = <MapEntry<String, String>>[
    MapEntry('service', 'Svc'),
    MapEntry('kitchen', 'Kit'),
    MapEntry('bar', 'Bar'),
  ];

  static const _statusFormOptions = <MapEntry<String, String>>[
    MapEntry('new', 'New'),
    MapEntry('internal_follow_up', 'Internal Follow Up'),
    MapEntry('courtesy_done', 'Courtesy Done'),
  ];

  static const _followUpStatusFormOptions = <MapEntry<String, String>>[
    MapEntry('new', 'New'),
    MapEntry('on_progress', 'On Progress'),
    MapEntry('done', 'Done'),
  ];

  late List<int> _regionalIds;
  int? _assignedTo;
  late String _statusForm;
  late String _followUpStatusForm;
  bool _saving = false;
  Map<String, dynamic>? _authUser;
  bool _expanded = false;

  Map<String, dynamic> get _row => widget.item.rawRow;

  @override
  void initState() {
    super.initState();
    _hydrateFromItem();
    AuthService().getUserData().then((u) {
      if (mounted) setState(() => _authUser = u);
    });
  }

  @override
  void didUpdateWidget(CustomerVoiceCaseIndexCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSig =
        '${widget.item.id}|${widget.item.status}|${widget.item.assignedTo}|${widget.item.rawRow['regional_user_ids']}';
    final oldSig =
        '${oldWidget.item.id}|${oldWidget.item.status}|${oldWidget.item.assignedTo}|${oldWidget.item.rawRow['regional_user_ids']}';
    if (newSig != oldSig) {
      _hydrateFromItem();
    }
  }

  void _hydrateFromItem() {
    _regionalIds = parseRegionalUserIds(_row['regional_user_ids']);
    _assignedTo = widget.item.assignedTo;
    _statusForm = canonicalVoiceCaseStatus(widget.item.status);
    _followUpStatusForm = widget.item.rawRow['follow_up_status']?.toString() ?? 'new';
  }

  List<CustomerVoiceOption> _mergedAssigneesList() {
    return mergeCustomerVoiceAssigneesWithAuth(
      assignees: widget.dashboard.assignees,
      authUser: _authUser,
    );
  }

  String _picSubtitle() {
    if (_assignedTo == null) {
      return 'Belum di-assign — ketuk untuk mencari CS PIC';
    }
    return customerVoiceAssigneeLine(_assignedTo!, _mergedAssigneesList());
  }

  Map<int, String> _assigneeNames() {
    final m = <int, String>{};
    for (final a in widget.dashboard.assignees) {
      if (a.id != null) {
        m[a.id!] = a.label;
      }
    }
    return m;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateCase(
        caseId: widget.item.id,
        status: _statusForm,
        followUpStatus: _followUpStatusForm,
        assignedTo: _assignedTo,
        regionalUserIds: _regionalIds,
        notifyFollowerUserIds: const [],
      );
      if (!mounted) return;
      final uid = int.tryParse('${_authUser?['id'] ?? 0}') ?? 0;
      if (uid > 0 &&
          _regionalIds.isNotEmpty &&
          _regionalIds.every((id) => id == uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Regional: tidak ada notifikasi ke akun ini karena hanya berisi Anda sendiri.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCapaPdf() async {
    final uri = widget.service.buildCapaExportPdfWebUri(widget.item.id);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCapaXls() async {
    final uri = widget.service.buildCapaExportExcelWebUri(widget.item.id);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickRegional() async {
    final next = await showCustomerVoiceMultiUserPicker(
      context: context,
      assignees: widget.dashboard.assignees,
      title: 'Pilih regional (notifikasi)',
      initialSelectedIds: _regionalIds,
    );
    if (!mounted || next == null) return;
    setState(() => _regionalIds = next);
  }

  Future<void> _pickPic() async {
    final id = await showCustomerVoiceSingleUserPicker(
      context: context,
      assignees: _mergedAssigneesList(),
      title: 'Pilih CS PIC',
      selectedId: _assignedTo,
    );
    if (!mounted) return;
    setState(() => _assignedTo = id);
  }

  void _openTimeline() {
    final acts = widget.dashboard.activities[widget.item.id] ??
        const <CustomerVoiceActivity>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Timeline aktivitas',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: acts.isEmpty
                    ? const Center(
                        child: Text('Belum ada aktivitas'),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: acts.length,
                        itemBuilder: (context, i) {
                          final a = acts[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.activityType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (a.createdAt != null)
                                      Text(
                                        DateFormat(
                                          'dd MMM yyyy HH:mm',
                                          'id_ID',
                                        ).format(a.createdAt!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    if (a.actorName != null &&
                                        a.actorName!.isNotEmpty)
                                      Text(
                                        'Oleh ${a.actorName}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    if (a.note != null &&
                                        a.note!.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          a.note!,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNoteDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final c = TextEditingController();
    var loading = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tambah catatan'),
          content: TextField(
            controller: c,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Catatan…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final note = c.text.trim();
                      if (note.isEmpty) return;
                      setS(() => loading = true);
                      try {
                        await widget.service.addNote(
                          caseId: widget.item.id,
                          note: note,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onRefresh();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Catatan tersimpan')),
                        );
                      } catch (e) {
                        setS(() => loading = false);
                        messenger.showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final noteCount = widget.dashboard.noteCounts[item.id] ?? 0;
    final slaText = slaLabelForRow(status: item.status, dueAt: item.dueAt);
    final slaCol = slaColorForLabel(slaText);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, color: const Color(0xFF14B8A6)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.headline,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.eventAt != null
                                    ? DateFormat(
                                        'dd/MM/yyyy, HH.mm.ss',
                                        'id_ID',
                                      ).format(item.eventAt!)
                                    : '—',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFCCFBF1),
                                    Color(0xFFE0F2FE),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                item.riskScore == null
                                    ? '—'
                                    : item.riskScore!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: _expanded ? 'Ringkas' : 'Perluas',
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              icon: AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: Colors.grey.shade700,
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                          voiceCaseStatusFormLabel(
                            canonicalVoiceCaseStatus(item.status),
                          ),
                          bg: const Color(0xFFEEF2FF),
                          fg: const Color(0xFF4338CA),
                        ),
                        _pill(
                          followUpStatusLabel(item.rawRow['follow_up_status']?.toString()),
                          bg: const Color(0xFFF0FDF4),
                          fg: const Color(0xFF15803D),
                        ),
                        _pill(
                          item.severity.isEmpty ? 'neutral' : item.severity,
                          bg: const Color(0xFFFFF1F2),
                          fg: const Color(0xFFB91C1C),
                        ),
                        _pill(
                          slaText,
                          bg: slaText == 'Overdue'
                              ? const Color(0xFFFFF1F2)
                              : const Color(0xFFFFFBEB),
                          fg: slaCol,
                        ),
                        if (noteCount > 0)
                          _pill(
                            '$noteCount catatan',
                            bg: const Color(0xFFF5F3FF),
                            fg: const Color(0xFF6D28D9),
                          ),
                      ],
                    ),
                    if (!_expanded) _buildCollapsedTail(item),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _expanded
                          ? _buildExpandedBody()
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBody() {
    final item = widget.item;
    final noteCount = widget.dashboard.noteCounts[item.id] ?? 0;
    final names = _assigneeNames();
    final slaText = slaLabelForRow(status: item.status, dueAt: item.dueAt);
    final slaCol = slaColorForLabel(slaText);
    final fu = followUpTargetLabel(_row['follow_up_target']?.toString());
    final complaintLabels = (_row['complaint_type_labels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final capaAudit = capaAuditLine(_row, names) ?? '';
    final verifAudit = verificationAuditLine(_row, names) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _sectionTag('Outlet & sumber'),
        const SizedBox(height: 8),
        _kv(Icons.storefront_outlined, item.outletName),
        _kv(
          Icons.label_outline_rounded,
          sourceTypeShortLabel(item.sourceType),
        ),
        _kv(Icons.person_outline_rounded, item.authorName),
        if (item.customerContact != null &&
            item.customerContact!.trim().isNotEmpty)
          _kv(Icons.phone_outlined, item.customerContact!),
        if (_row['customer_email'] != null &&
            '${_row['customer_email']}'.trim().isNotEmpty)
          _kv(
            Icons.email_outlined,
            '${_row['customer_email']}',
          ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FU target',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (fu != null)
                    _pill(
                      fu,
                      bg: fu == 'Customer'
                          ? const Color(0xFFF5F3FF)
                          : const Color(0xFFF8FAFC),
                      fg: fu == 'Customer'
                          ? const Color(0xFF5B21B6)
                          : const Color(0xFF475569),
                    )
                  else
                    Text(
                      '—',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SLA / due',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slaText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: slaCol,
                    ),
                  ),
                  if (item.dueAt != null)
                    Text(
                      'due ${DateFormat('dd/MM/yyyy, HH.mm.ss', 'id_ID').format(item.dueAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Jenis komplain',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        if (complaintLabels.isEmpty)
          Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: complaintLabels
                .map(
                  (t) => Chip(
                    label: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF5F3FF),
                    side: const BorderSide(
                      color: Color(0xFFE9D5FF),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        Text(
          'Ringkasan',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        if (item.summaryId != null && item.summaryId!.trim().isNotEmpty)
          Text(
            item.summaryId!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        Text(
          item.rawText.trim().isEmpty ? '—' : item.rawText.trim(),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 14),
        _sectionTag('CAPA per divisi'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _miniDivisionColumn(
                title: 'CAPA',
                filled: true,
                row: _row,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniDivisionColumn(
                title: 'Verif.',
                filled: false,
                row: _row,
              ),
            ),
          ],
        ),
        if (capaAudit.isNotEmpty || verifAudit.isNotEmpty) ...[
          const SizedBox(height: 6),
          if (capaAudit.isNotEmpty)
            Text(
              capaAudit,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          if (verifAudit.isNotEmpty)
            Text(
              verifAudit,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
        ],
        const SizedBox(height: 16),
        _sectionTag('Regional — notifikasi FU & CAPA'),
        const SizedBox(height: 6),
        Text(
          'Pilih user regional. Saat Simpan, notifikasi ke user terpilih (bukan akun Anda sendiri).',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        CustomerVoiceUserPickerTrigger(
          valueText: customerVoiceRegionalSummary(
            _regionalIds,
            widget.dashboard.assignees,
          ),
          onTap: _pickRegional,
          leadingIcon: Icons.groups_outlined,
        ),
        const SizedBox(height: 14),
        CustomerVoiceUserPickerTrigger(
          sectionLabel: 'CS PIC',
          valueText: _picSubtitle(),
          onTap: _pickPic,
          leadingIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: 14),
        Text(
          'Courtesy Status',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _statusForm,
              items: _statusFormOptions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _statusForm = v);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Follow Up Status',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _followUpStatusForm,
              items: _followUpStatusFormOptions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _followUpStatusForm = v);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => widget.onOpenDetail(widget.item),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Detail'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
            ),
            Badge(
              isLabelVisible: noteCount > 0,
              label: Text(
                noteCount > 99 ? '99+' : '$noteCount',
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: const Color(0xFF7C3AED),
              child: OutlinedButton.icon(
                onPressed: _openNoteDialog,
                icon: const Icon(Icons.note_alt_outlined, size: 18),
                label: const Text('Catatan'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _openTimeline,
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Timeline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                backgroundColor: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openCapaPdf,
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 18,
                ),
                label: const Text('CAPA PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF047857),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openCapaXls,
                icon: const Icon(
                  Icons.table_chart_outlined,
                  size: 18,
                ),
                label: const Text('CAPA XLS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollapsedTail(CustomerVoiceCaseItem item) {
    final teaser =
        '${item.outletName} · ${sourceTypeShortLabel(item.sourceType)} · ${item.authorName}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            teaser,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onOpenDetail(widget.item),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Detail'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => _expanded = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF99F6E4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lengkap'),
                    SizedBox(width: 4),
                    Icon(Icons.unfold_more_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTag(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _pill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _kv(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDivisionColumn({
    required String title,
    required bool filled,
    required Map<String, dynamic>? row,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        ..._divisions.map((e) {
          final id = e.key;
          final short = e.value;
          if (filled) {
            final ok = divisionCapaFilledFromRow(row, id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      short,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  _roundIcon(
                    ok ? Icons.check_rounded : Icons.remove_rounded,
                    fg: ok ? const Color(0xFF047857) : const Color(0xFF64748B),
                    bg: ok ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    border:
                        ok ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                  ),
                ],
              ),
            );
          }
          final vu = divisionVerificationUi(row, id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    short,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Tooltip(
                  message: vu.tooltip,
                  child: _roundIcon(
                    vu.icon,
                    fg: vu.fg,
                    bg: vu.bg,
                    border: vu.border,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _roundIcon(
    IconData icon, {
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Icon(icon, size: 15, color: fg),
    );
  }
}
