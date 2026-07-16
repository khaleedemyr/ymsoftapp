import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SopDevelopmentCompletionUi {
  static const Color primary = Color(0xFF4F46E5);
  static const Color textMuted = Color(0xFF64748B);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration get headerGradient => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  static String statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'pending':
        return 'Menunggu Approval';
      case 'approved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'draft':
        return const Color(0xFF475569);
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  static Color statusBg(String status) {
    switch (status) {
      case 'draft':
        return const Color(0xFFF1F5F9);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'approved':
        return const Color(0xFFDCFCE7);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  static String formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('d MMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return date;
    }
  }

  static String formatDateTime(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('d MMM yyyy HH:mm', 'id_ID').format(parsed);
    } catch (_) {
      return date;
    }
  }
}
