import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NpdPlanReportUi {
  static const Color primary = Color(0xFFF59E0B);
  static const Color primaryDark = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static BoxDecoration headerGradient = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
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
      final dt = DateTime.parse(value);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return value;
    }
  }

  static String formatCurrency(num? value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value ?? 0);
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

  static String purposeLabel(String? value, List<Map<String, dynamic>> options) {
    for (final opt in options) {
      if (opt['value']?.toString() == value) {
        return opt['label']?.toString() ?? value ?? '-';
      }
    }
    return value ?? '-';
  }

  static String joinNames(List<Map<String, dynamic>> items, {String nameKey = 'name'}) {
    if (items.isEmpty) return '-';
    return items.map((e) => e[nameKey]?.toString() ?? e['nama_outlet']?.toString() ?? '').where((e) => e.isNotEmpty).join(', ');
  }

  static int outletId(Map<String, dynamic> outlet) =>
      outlet['id_outlet'] as int? ?? int.tryParse(outlet['id_outlet']?.toString() ?? '') ?? 0;

  static String outletName(Map<String, dynamic> outlet) => outlet['nama_outlet']?.toString() ?? '-';

  static int categoryId(Map<String, dynamic> category) =>
      category['id'] as int? ?? int.tryParse(category['id']?.toString() ?? '') ?? 0;

  static String categoryName(Map<String, dynamic> category) => category['name']?.toString() ?? '-';
}
