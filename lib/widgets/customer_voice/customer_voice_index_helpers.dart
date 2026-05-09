import 'package:flutter/material.dart';

/// Selaras logika tampilan baris daftar web `CustomerVoiceCommandCenter/Index.vue`.

String canonicalVoiceCaseStatus(String raw) {
  final s = raw.toLowerCase();
  if (s == 'in_progress') return 'follow_up_by_ops';
  if (s == 'resolved' || s == 'ignored') return 'done';
  return raw;
}

String voiceCaseStatusFormLabel(String formStatus) {
  switch (formStatus.toLowerCase()) {
    case 'new':
      return 'New';
    case 'courtesy_by_cs':
      return 'Courtesy by CS';
    case 'follow_up_by_ops':
      return 'Follow Up by Ops';
    case 'done':
      return 'Done';
    default:
      return formStatus;
  }
}

String sourceTypeShortLabel(String? sourceType) {
  final s = sourceType ?? '';
  if (s == 'google_review') return 'Google';
  if (s == 'instagram_comment') return 'Instagram';
  if (s == 'guest_comment') return 'Guest Comment';
  return s.isEmpty ? '-' : s;
}

String? followUpTargetLabel(String? v) {
  if (v == null || v.isEmpty) return null;
  final s = v.toLowerCase();
  if (s == 'customer') return 'Customer';
  if (s == 'internal') return 'Internal';
  return v;
}

bool _isOpenDbStatus(String statusValue) {
  final s = statusValue.toLowerCase();
  return s == 'new' ||
      s == 'courtesy_by_cs' ||
      s == 'follow_up_by_ops' ||
      s == 'in_progress';
}

/// Satu baris teks SLA seperti web `slaLabel`.
String slaLabelForRow({
  required String status,
  required DateTime? dueAt,
}) {
  if (dueAt == null) return 'Tanpa SLA';
  if (!_isOpenDbStatus(status)) return 'Closed';
  final due = dueAt.millisecondsSinceEpoch;
  final nowTs = DateTime.now().millisecondsSinceEpoch;
  if (due < nowTs) return 'Overdue';
  final diffMs = due - nowTs;
  final diffMin = diffMs ~/ 60000;
  if (diffMin < 60) return '${diffMin}m tersisa';
  final diffHour = diffMin ~/ 60;
  final remMin = diffMin % 60;
  return '${diffHour}j ${remMin}m tersisa';
}

Color slaColorForLabel(String label) {
  if (label == 'Overdue') return const Color(0xFFB91C1C);
  if (label.contains('tersisa')) return const Color(0xFFD97706);
  if (label == 'Closed') return const Color(0xFF15803D);
  return const Color(0xFF64748B);
}

class DivisionVerifUiData {
  const DivisionVerifUiData({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.border,
    required this.tooltip,
  });

  final IconData icon;
  final Color fg;
  final Color bg;
  final Color border;
  final String tooltip;
}

DivisionVerifUiData divisionVerificationUi(Map<String, dynamic>? row, String divisionId) {
  final perDiv = row?['capa_division_verification'];
  if (perDiv is Map && perDiv[divisionId] is Map) {
    final v = Map<String, dynamic>.from(perDiv[divisionId] as Map);
    final state = (v['state'] ?? 'none').toString().toLowerCase();
    final result = (v['result'] ?? '').toString().toLowerCase();
    if (state.isEmpty || state == 'none') {
      return const DivisionVerifUiData(
        icon: Icons.remove_rounded,
        fg: Color(0xFF64748B),
        bg: Color(0xFFF8FAFC),
        border: Color(0xFFE2E8F0),
        tooltip: 'Belum ada verifikator / belum proses verifikasi',
      );
    }
    if (state == 'pending') {
      return const DivisionVerifUiData(
        icon: Icons.hourglass_bottom_rounded,
        fg: Color(0xFFB45309),
        bg: Color(0xFFFFFBEB),
        border: Color(0xFFFDE68A),
        tooltip: 'Verifikator ditunjuk — hasil belum diisi',
      );
    }
    if (result == 'effective') {
      return const DivisionVerifUiData(
        icon: Icons.check_rounded,
        fg: Color(0xFF047857),
        bg: Color(0xFFECFDF5),
        border: Color(0xFFA7F3D0),
        tooltip: 'Verifikasi selesai — efektif',
      );
    }
    return const DivisionVerifUiData(
      icon: Icons.close_rounded,
      fg: Color(0xFFB91C1C),
      bg: Color(0xFFFFF1F2),
      border: Color(0xFFFECDD3),
      tooltip: 'Verifikasi selesai — tidak efektif',
    );
  }
  return const DivisionVerifUiData(
    icon: Icons.remove_rounded,
    fg: Color(0xFF64748B),
    bg: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    tooltip: 'Belum ada verifikasi',
  );
}

bool divisionCapaFilledFromRow(Map<String, dynamic>? row, String divisionId) {
  final flags = row?['capa_division_filled'];
  if (flags is Map && flags.containsKey(divisionId)) {
    return flags[divisionId] == true;
  }
  return false;
}

String? capaAuditLine(Map<String, dynamic>? row, Map<int, String> assigneeNames) {
  final a = row?['capa_audit'];
  if (a is! Map) return null;
  final uid = a['updated_by_user_id'];
  final at = a['updated_at']?.toString();
  final id = int.tryParse('$uid') ?? 0;
  final by = id > 0 ? (assigneeNames[id] ?? '#$id') : '';
  if (by.isEmpty && (at == null || at.isEmpty)) return null;
  return '${by.isEmpty ? '-' : by} · ${at ?? '-'}';
}

String? verificationAuditLine(Map<String, dynamic>? row, Map<int, String> assigneeNames) {
  final a = row?['capa_audit'];
  if (a is! Map) return null;
  final uid = a['verified_by_user_id'];
  final at = a['verified_at']?.toString();
  final id = int.tryParse('$uid') ?? 0;
  final by = id > 0 ? (assigneeNames[id] ?? '#$id') : '';
  if (by.isEmpty && (at == null || at.isEmpty)) return null;
  return '${by.isEmpty ? '-' : by} · ${at ?? '-'}';
}

