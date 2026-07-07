import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompetitorBenchmarkReportUi {
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static BoxDecoration headerGradient = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static String formatMonth(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      final parts = value.split('-');
      if (parts.length >= 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return DateFormat('MMMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {}
    return value;
  }

  static String formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  static String statusLabel(String? status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Submitted';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Not Approved';
      case 'requires_revision':
        return 'Requires Revision';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status ?? '-';
    }
  }

  static Color statusColor(String? status) {
    switch (status) {
      case 'submitted':
        return const Color(0xFF2563EB);
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'requires_revision':
        return const Color(0xFFD97706);
      default:
        return textMuted;
    }
  }

  static Color statusBg(String? status) {
    switch (status) {
      case 'submitted':
        return const Color(0xFFDBEAFE);
      case 'approved':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      case 'requires_revision':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  static String flowStatusLabel(String? status) {
    switch (status) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Not Approved';
      case 'REQUIRES_REVISION':
        return 'Requires Revision';
      case 'PENDING':
        return 'Pending';
      default:
        return status ?? '-';
    }
  }

  static String joinPicNames(List<dynamic>? pics) {
    if (pics == null || pics.isEmpty) return '-';
    return pics
        .map((e) => (e as Map)['name']?.toString() ?? (e)['nama_lengkap']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .join(', ');
  }

  static int outletId(Map<String, dynamic> outlet) =>
      outlet['id_outlet'] as int? ?? int.tryParse(outlet['id_outlet']?.toString() ?? '') ?? 0;

  static String outletName(Map<String, dynamic> outlet) => outlet['nama_outlet']?.toString() ?? '-';
}
