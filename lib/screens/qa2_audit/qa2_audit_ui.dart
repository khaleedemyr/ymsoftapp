import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class Qa2AuditUi {
  static const Color primary = Color(0xFF6366F1);
  static const Color rose = Color(0xFFE11D48);
  static const Color emerald = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);

  static String mediaUrl(dynamic raw) {
    final url = raw?.toString().trim() ?? '';
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/storage/') || url.startsWith('/uploads/')) {
      return '${AuthService.storageUrl}$url';
    }
    if (url.startsWith('storage/') || url.startsWith('uploads/')) {
      return '${AuthService.storageUrl}/$url';
    }
    if (url.startsWith('/')) return '${AuthService.storageUrl}$url';
    return '${AuthService.storageUrl}/storage/$url';
  }

  static int? outletId(Map<String, dynamic> outlet) {
    final raw = outlet['id_outlet'] ?? outlet['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String outletName(Map<String, dynamic> outlet) {
    return outlet['nama_outlet']?.toString() ?? outlet['name']?.toString() ?? '-';
  }

  static int? templateId(Map<String, dynamic> template) {
    final raw = template['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String templateName(Map<String, dynamic> template) {
    return template['name']?.toString() ?? template['title']?.toString() ?? '-';
  }

  static double auditScore(Map<String, dynamic> audit) {
    final c = int.tryParse('${audit['count_c']}') ?? 0;
    final nc = int.tryParse('${audit['count_nc']}') ?? 0;
    final denom = c + nc;
    if (denom <= 0) return 0;
    return (c / denom) * 100;
  }

  static double itemScore(List<Map<String, dynamic>> items) {
    var c = 0;
    var nc = 0;
    for (final it in items) {
      final r = it['result']?.toString();
      if (r == 'C') c++;
      if (r == 'NC') nc++;
    }
    final denom = c + nc;
    if (denom <= 0) return 0;
    return (c / denom) * 100;
  }

  static String formatScore(double score) => '${score.toStringAsFixed(0)}%';

  static ({String label, Color bg, Color fg}) resultBadge(double score) {
    if (score >= 91) {
      return (label: 'EXCELLENT', bg: const Color(0xFFD1FAE5), fg: const Color(0xFF047857));
    }
    if (score >= 85) {
      return (label: 'SATISFACTORY', bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
    }
    return (label: 'TO IMPROVE', bg: const Color(0xFFFFE4E6), fg: const Color(0xFFBE123C));
  }

  static Widget statusChip(String? status) {
    final s = status ?? 'draft';
    final submitted = s == 'submitted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: submitted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: submitted ? const Color(0xFF047857) : const Color(0xFFB45309),
        ),
      ),
    );
  }

  static ({String label, Color bg, Color fg, IconData? icon})? capStatusBadge(Map<String, dynamic> audit) {
    final status = audit['status']?.toString() ?? '';
    final nc = int.tryParse('${audit['count_nc']}') ?? 0;
    if (status != 'submitted' || nc <= 0) return null;

    final pending = int.tryParse('${audit['count_nc_pending_cap']}') ?? 0;
    final submission = audit['cap_submission_status']?.toString();

    if (pending > 0) {
      final label = pending == nc ? 'CAP Belum Diisi' : 'CAP Belum Lengkap ($pending)';
      return (label: label, bg: const Color(0xFFFFE4E6), fg: const Color(0xFFBE123C), icon: Icons.warning_amber_rounded);
    }
    if (submission == 'approved') {
      return (label: 'CAP Disetujui', bg: const Color(0xFFD1FAE5), fg: const Color(0xFF047857), icon: Icons.verified_rounded);
    }
    if (submission == 'pending_approval') {
      return (label: 'CAP Proses Approval', bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309), icon: Icons.schedule_rounded);
    }
    if (submission == 'rejected') {
      return (label: 'CAP Ditolak', bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C), icon: Icons.cancel_rounded);
    }
    return (label: 'CAP Terisi', bg: const Color(0xFFE0E7FF), fg: const Color(0xFF4338CA), icon: Icons.assignment_turned_in_rounded);
  }

  static Widget capStatusChip(Map<String, dynamic> audit) {
    final badge = capStatusBadge(audit);
    if (badge == null) {
      return const Text('-', style: TextStyle(color: slate500, fontSize: 11));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.icon != null) ...[
            Icon(badge.icon, size: 12, color: badge.fg),
            const SizedBox(width: 4),
          ],
          Text(
            badge.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badge.fg),
          ),
        ],
      ),
    );
  }

  static String userLabel(Map<String, dynamic> user) {
    final name = user['nama_lengkap']?.toString() ?? user['name']?.toString() ?? '-';
    final jabatan = user['jabatan']?.toString();
    if (jabatan != null && jabatan.isNotEmpty) return '$name ($jabatan)';
    return name;
  }

  static String personLabel(Map<String, dynamic> person) {
    final name = person['name']?.toString() ?? '-';
    final jabatan = person['jabatan']?.toString();
    if (jabatan != null && jabatan.isNotEmpty) return '$name\n$jabatan';
    return name;
  }

  static bool isParameterFilled(String? result) {
    return result == 'C' || result == 'NC' || result == 'NA';
  }

  static ({Color bg, Color border, Color badgeBg, Color badgeFg, String label}) parameterFillStyle(String? result) {
    switch (result) {
      case 'C':
        return (
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFF6EE7B7),
          badgeBg: const Color(0xFFD1FAE5),
          badgeFg: const Color(0xFF047857),
          label: 'C',
        );
      case 'NC':
        return (
          bg: const Color(0xFFFFF1F2),
          border: const Color(0xFFFDA4AF),
          badgeBg: const Color(0xFFFFE4E6),
          badgeFg: const Color(0xFFBE123C),
          label: 'NC',
        );
      case 'NA':
        return (
          bg: const Color(0xFFF8FAFC),
          border: const Color(0xFFCBD5E1),
          badgeBg: const Color(0xFFE2E8F0),
          badgeFg: const Color(0xFF475569),
          label: 'NA',
        );
      default:
        return (
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFCD34D),
          badgeBg: const Color(0xFFFEF3C7),
          badgeFg: const Color(0xFFB45309),
          label: 'Belum diisi',
        );
    }
  }
}
