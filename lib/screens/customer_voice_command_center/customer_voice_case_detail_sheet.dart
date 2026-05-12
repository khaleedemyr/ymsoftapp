import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/auth_service.dart';
import '../../services/customer_voice_command_center_service.dart';
import '../../widgets/customer_voice/capa_display_helpers.dart';
import '../../widgets/customer_voice/capa_form_panel_widget.dart';
import '../../widgets/customer_voice/customer_voice_index_helpers.dart';
import '../../widgets/customer_voice/notify_user_multi_picker.dart';

abstract final class _CvDetailTokens {
  static const Color canvas = Color(0xFFF1F5F9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color accent = Color(0xFF0D9488);
  static const Color accentSoft = Color(0xFFCCFBF1);
}

/// Bottom sheet body: ringkas info case (selaras web) + form CAPA penuh.
class CustomerVoiceCaseDetailSheet extends StatefulWidget {
  const CustomerVoiceCaseDetailSheet({
    super.key,
    required this.item,
    required this.dashboard,
    required this.service,
    required this.onCaseUpdated,
  });

  final CustomerVoiceCaseItem item;
  final CustomerVoiceDashboard dashboard;
  final CustomerVoiceCommandCenterService service;
  final VoidCallback onCaseUpdated;

  @override
  State<CustomerVoiceCaseDetailSheet> createState() =>
      _CustomerVoiceCaseDetailSheetState();
}

class _CustomerVoiceCaseDetailSheetState
    extends State<CustomerVoiceCaseDetailSheet> {
  Map<String, dynamic>? _brief;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _authUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = await AuthService().getUserData();
      final brief = await widget.service.getCaseBrief(widget.item.id);
      if (!mounted) return;
      setState(() {
        _authUser = auth;
        _brief = brief;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final activities =
        widget.dashboard.activities[item.id] ?? const <CustomerVoiceActivity>[];

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              _CvDetailTokens.canvas,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _loading
                    ? Center(
                        key: const ValueKey('loading'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: _CvDetailTokens.accent,
                              strokeWidth: 2.5,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Memuat detail case…',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            key: ValueKey(_error),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 44,
                                    color: Colors.red.shade400,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: _CvDetailTokens.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            key: const ValueKey('content'),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHero(context, item),
                                const SizedBox(height: 18),
                                _buildInfoPanel(item, _brief ?? item.rawRow),
                                const SizedBox(height: 18),
                                _CaseUpdateCard(
                                  item: item,
                                  dashboard: widget.dashboard,
                                  service: widget.service,
                                  authUser: _authUser,
                                  initialRegionalUserIds: parseRegionalUserIds(
                                    (_brief ??
                                        item.rawRow)['regional_user_ids'],
                                  ),
                                  onNoteSaved: widget.onCaseUpdated,
                                  onCaseSaved: () {
                                    widget.onCaseUpdated();
                                    Navigator.pop(context);
                                  },
                                ),
                                const SizedBox(height: 18),
                                if (_brief != null &&
                                    _brief!['gcf_capa'] is Map &&
                                    _hasGcfCapaContent(_brief!['gcf_capa']))
                                  _buildGcfCapaCard(_brief!['gcf_capa'] as Map<String, dynamic>),
                                if (_brief != null &&
                                    _brief!['gcf_capa'] is Map &&
                                    _hasGcfCapaContent(_brief!['gcf_capa']))
                                  const SizedBox(height: 18),
                                if (_brief != null)
                                  CapaFormPanelWidget(
                                    key: ValueKey(
                                      'capa-${item.id}-${_brief.hashCode}',
                                    ),
                                    caseId: item.id,
                                    caseRow: _brief!,
                                    assignees: widget.dashboard.assignees,
                                    authUser: _authUser,
                                  ),
                                if (_brief != null) const SizedBox(height: 18),
                                _timelineCard(activities),
                              ],
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasGcfCapaContent(dynamic gcfCapa) {
    if (gcfCapa is! Map) return false;
    final k = (gcfCapa['kronologi']?.toString() ?? '').trim();
    final c = (gcfCapa['corrective_action']?.toString() ?? '').trim();
    final p = (gcfCapa['preventive_action']?.toString() ?? '').trim();
    return k.isNotEmpty || c.isNotEmpty || p.isNotEmpty;
  }

  Widget _buildGcfCapaCard(Map<String, dynamic> gcfCapa) {
    final filledByName = gcfCapa['filled_by_name']?.toString() ?? '';
    final filledAt = gcfCapa['filled_at']?.toString() ?? '';
    String filledAtFormatted = '';
    if (filledAt.isNotEmpty) {
      try {
        filledAtFormatted = DateFormat('dd MMM yyyy · HH:mm', 'id_ID')
            .format(DateTime.parse(filledAt).toLocal());
      } catch (_) {
        filledAtFormatted = filledAt;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.clipboard_outlined,
                  color: Colors.green.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAPA DARI OUTLET LEADER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        'Diisi saat verifikasi Guest Comment',
                        if (filledByName.isNotEmpty) 'oleh $filledByName',
                        if (filledAtFormatted.isNotEmpty) '· $filledAtFormatted',
                      ].join(' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _gcfCapaField('Kronologi', gcfCapa['kronologi']?.toString() ?? ''),
          const SizedBox(height: 10),
          _gcfCapaField('Corrective Action', gcfCapa['corrective_action']?.toString() ?? ''),
          const SizedBox(height: 10),
          _gcfCapaField('Preventive Action', gcfCapa['preventive_action']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _gcfCapaField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.trim().isNotEmpty ? value.trim() : '—',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, CustomerVoiceCaseItem item) {
    final slaText = slaLabelForRow(status: item.status, dueAt: item.dueAt);
    final slaCol = slaColorForLabel(slaText);

    return Container(
      decoration: BoxDecoration(
        color: _CvDetailTokens.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _CvDetailTokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: _CvDetailTokens.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.headline,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                letterSpacing: -0.3,
                                color: _CvDetailTokens.ink,
                              ),
                            ),
                          ),
                          if (item.riskScore != null) ...[
                            const SizedBox(width: 8),
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
                                item.riskScore!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Material(
                            color: const Color(0xFFF1F5F9),
                            shape: const CircleBorder(),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.grey.shade700,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _heroMetaChip(
                            Icons.event_rounded,
                            item.eventAt != null
                                ? DateFormat(
                                    'dd MMM yyyy · HH:mm',
                                    'id_ID',
                                  ).format(item.eventAt!)
                                : '—',
                          ),
                          if (item.dueAt != null)
                            _heroMetaChip(
                              Icons.flag_outlined,
                              'Due ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(item.dueAt!)}',
                              foreground: slaCol,
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: slaText == 'Overdue'
                                  ? const Color(0xFFFFF1F2)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: slaText == 'Overdue'
                                    ? const Color(0xFFFECACA)
                                    : _CvDetailTokens.border,
                              ),
                            ),
                            child: Text(
                              slaText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: slaCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pillBadge(
                            _statusLabel(item.status),
                            _statusColor(item.status),
                          ),
                          _pillBadge(
                            _severityLabel(item.severity),
                            _severityColor(item.severity),
                          ),
                          _pillBadge(
                            _sourceLabel(item.sourceType),
                            const Color(0xFF475569),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroMetaChip(
    IconData icon,
    String text, {
    Color? foreground,
  }) {
    final fg = foreground ?? _CvDetailTokens.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    );
  }

  Widget _pillBadge(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
          color: accent,
        ),
      ),
    );
  }

  Widget _capsLabel(String text, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
            color: _CvDetailTokens.muted,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailPair(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _CvDetailTokens.border),
            ),
            child: Icon(icon, size: 18, color: _CvDetailTokens.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _CvDetailTokens.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: _CvDetailTokens.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(CustomerVoiceCaseItem item, Map<String, dynamic> row) {
    final topics = (row['complaint_type_labels'] as List<dynamic>?) ?? [];
    final impact = impactLine(row['impact']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _CvDetailTokens.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _CvDetailTokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _CvDetailTokens.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: _CvDetailTokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _capsLabel(
                  'Ringkasan case',
                  subtitle: 'Data operasional & konteks tamu',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _detailPair(Icons.storefront_outlined, 'Outlet', item.outletName),
          _detailPair(
              Icons.person_outline_rounded, 'Tamu / author', item.authorName),
          _detailPair(
            Icons.phone_outlined,
            'Kontak',
            item.customerContact?.trim().isNotEmpty == true
                ? item.customerContact!
                : '—',
          ),
          _detailPair(
            Icons.email_outlined,
            'Email',
            row['customer_email']?.toString().trim().isNotEmpty == true
                ? row['customer_email'].toString()
                : '—',
          ),
          _detailPair(
            Icons.label_outline_rounded,
            'Sumber',
            _sourceLabel(item.sourceType),
          ),
          _detailPair(
            Icons.flag_circle_outlined,
            'FU target',
            followUpLabel(row['follow_up_target']?.toString()),
          ),
          _detailPair(Icons.bubble_chart_outlined, 'Dampak (source)', impact),
          _detailPair(
            Icons.badge_outlined,
            'PIC',
            '${item.assignedToName ?? '—'}${row['assigned_to_jabatan'] != null ? ' · ${row['assigned_to_jabatan']}' : ''}',
          ),
          _detailPair(
            Icons.tag_rounded,
            'Summary ID',
            item.summaryId?.trim().isNotEmpty == true ? item.summaryId! : '—',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ),
          _capsLabel('Waktu & tenggat'),
          const SizedBox(height: 12),
          _detailPair(
            Icons.schedule_rounded,
            'Event',
            item.eventAt != null ? _fmt(item.eventAt!) : '—',
          ),
          _detailPair(
            Icons.alarm_rounded,
            'Due',
            item.dueAt != null ? _fmt(item.dueAt!) : '—',
          ),
          _detailPair(
            Icons.check_circle_outline_rounded,
            'Resolved',
            item.resolvedAt != null ? _fmt(item.resolvedAt!) : '—',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ),
          _capsLabel('Jenis komplain'),
          const SizedBox(height: 10),
          if (topics.isEmpty)
            Text(
              '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics.map((e) {
                return Chip(
                  label: Text(
                    e.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: const Color(0xFFF5F3FF),
                  side: const BorderSide(color: Color(0xFFE9D5FF)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          const SizedBox(height: 18),
          _capsLabel('Voice of customer'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _CvDetailTokens.border),
            ),
            child: Text(
              item.rawText.trim().isEmpty ? '—' : item.rawText.trim(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard(List<CustomerVoiceActivity> activities) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _CvDetailTokens.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _CvDetailTokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _CvDetailTokens.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _CvDetailTokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _capsLabel(
                  'Timeline',
                  subtitle: 'Riwayat aktivitas pada case ini',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _CvDetailTokens.border),
              ),
              child: Text(
                'Belum ada aktivitas untuk case ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            ...activities.map(_activityTile),
        ],
      ),
    );
  }

  Widget _activityTile(CustomerVoiceActivity activity) {
    final accent = _activityColor(activity.activityType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _CvDetailTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _CvDetailTokens.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activityLabel(activity),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _CvDetailTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${activity.actorName?.trim().isNotEmpty == true ? activity.actorName! : 'System'} · ${activity.createdAt != null ? _fmt(activity.createdAt!) : '—'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _CvDetailTokens.muted,
                          ),
                        ),
                        if (activity.note?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            activity.note!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return DateFormat('dd MMM yyyy · HH:mm', 'id_ID').format(dt);
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'note':
        return const Color(0xFF6366F1);
      case 'capa_updated':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0F766E);
    }
  }

  String _activityLabel(CustomerVoiceActivity activity) {
    switch (activity.activityType) {
      case 'note':
        return 'Catatan';
      case 'capa_updated':
        return 'CAPA diperbarui';
      default:
        return activity.activityType;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return 'New';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'ignored':
        return 'Ignored';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF059669);
      case 'ignored':
        return const Color(0xFF64748B);
      case 'in_progress':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'severe':
        return 'Severe';
      case 'negative':
        return 'Negative';
      case 'mild_negative':
        return 'Mild Negative';
      case 'positive':
        return 'Positive';
      default:
        return severity;
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'severe':
        return const Color(0xFFB91C1C);
      case 'negative':
        return const Color(0xFFEA580C);
      case 'positive':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'google_review':
        return 'Google Review';
      case 'instagram_comment':
        return 'Instagram';
      case 'guest_comment':
        return 'Guest Comment';
      default:
        return source;
    }
  }
}

/// Status & PIC update — sama payload dengan layanan yang sudah ada.
class _CaseUpdateCard extends StatefulWidget {
  const _CaseUpdateCard({
    required this.item,
    required this.dashboard,
    required this.service,
    required this.authUser,
    required this.initialRegionalUserIds,
    required this.onNoteSaved,
    required this.onCaseSaved,
  });

  final CustomerVoiceCaseItem item;
  final CustomerVoiceDashboard dashboard;
  final CustomerVoiceCommandCenterService service;
  final Map<String, dynamic>? authUser;
  final List<int> initialRegionalUserIds;
  final VoidCallback onNoteSaved;
  final VoidCallback onCaseSaved;

  @override
  State<_CaseUpdateCard> createState() => _CaseUpdateCardState();
}

class _CaseUpdateCardState extends State<_CaseUpdateCard> {
  late String _status;
  int? _assignee;
  late List<int> _regionalUserIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _assignee = widget.item.assignedTo;
    _regionalUserIds = List<int>.from(widget.initialRegionalUserIds);
  }

  static const List<MapEntry<String, String>> _statusOptions = [
    MapEntry('new', 'New'),
    MapEntry('courtesy_by_cs', 'Courtesy by CS'),
    MapEntry('follow_up_by_ops', 'Follow up by Ops'),
    MapEntry('done', 'Done'),
    MapEntry('in_progress', 'In Progress'),
    MapEntry('resolved', 'Resolved'),
    MapEntry('ignored', 'Ignored'),
  ];

  List<CustomerVoiceOption> _mergedAssignees() {
    return mergeCustomerVoiceAssigneesWithAuth(
      assignees: widget.dashboard.assignees,
      authUser: widget.authUser,
    );
  }

  Future<void> _pickPic() async {
    final id = await showCustomerVoiceSingleUserPicker(
      context: context,
      assignees: _mergedAssignees(),
      title: 'Pilih PIC',
      selectedId: _assignee,
    );
    if (!mounted) return;
    setState(() => _assignee = id);
  }

  Future<void> _pickRegional() async {
    final next = await showCustomerVoiceMultiUserPicker(
      context: context,
      assignees: widget.dashboard.assignees,
      title: 'Pilih regional (notifikasi)',
      initialSelectedIds: _regionalUserIds,
    );
    if (!mounted || next == null) return;
    setState(() => _regionalUserIds = next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _CvDetailTokens.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _CvDetailTokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _CvDetailTokens.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: _CvDetailTokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PERBARUI CASE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: _CvDetailTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status, PIC & regional',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: 'Status',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _CvDetailTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _CvDetailTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _CvDetailTokens.accent,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: _statusOptions
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 14),
          CustomerVoiceUserPickerTrigger(
            sectionLabel: 'PIC',
            valueText: _assignee == null
                ? 'Belum di-assign — ketuk untuk mencari PIC'
                : customerVoiceAssigneeLine(_assignee!, _mergedAssignees()),
            onTap: _pickPic,
            leadingIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 10),
          Text(
            'Regional: pilih satu atau lebih user. Saat Simpan, notifikasi FU & CAPA otomatis ke user terpilih (bukan ke akun yang sedang login).',
            style: TextStyle(
                fontSize: 11, height: 1.35, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          CustomerVoiceUserPickerTrigger(
            sectionLabel: 'Regional',
            valueText: customerVoiceRegionalSummary(
              _regionalUserIds,
              widget.dashboard.assignees,
            ),
            onTap: _pickRegional,
            leadingIcon: Icons.groups_outlined,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await showDialog<void>(
                            context: context,
                            builder: (ctx) {
                              final c = TextEditingController();
                              var loading = false;
                              return StatefulBuilder(
                                builder: (ctx, setS) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text('Tambah catatan'),
                                    content: TextField(
                                      controller: c,
                                      maxLines: 5,
                                      decoration: InputDecoration(
                                        hintText: 'Catatan…',
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: loading
                                            ? null
                                            : () => Navigator.pop(ctx),
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
                                                  if (ctx.mounted) {
                                                    Navigator.pop(ctx);
                                                  }
                                                  widget.onNoteSaved();
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Catatan tersimpan',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  setS(() => loading = false);
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text('$e'),
                                                    ),
                                                  );
                                                }
                                              },
                                        child: const Text('Simpan'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Catatan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await widget.service.updateCase(
                              caseId: widget.item.id,
                              status: _status,
                              assignedTo: _assignee,
                              regionalUserIds: _regionalUserIds,
                              notifyFollowerUserIds: const [],
                            );
                            if (context.mounted) {
                              final messenger = ScaffoldMessenger.of(context);
                              final uid = int.tryParse(
                                    '${widget.authUser?['id'] ?? 0}',
                                  ) ??
                                  0;
                              if (uid > 0 &&
                                  _regionalUserIds.isNotEmpty &&
                                  _regionalUserIds.every((id) => id == uid)) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Regional: tidak ada notifikasi ke akun ini karena hanya berisi Anda sendiri. Pilih user lain untuk menguji notifikasi.',
                                    ),
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              }
                              widget.onCaseSaved();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
