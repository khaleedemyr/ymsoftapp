import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeCoachingUi {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static BoxDecoration headerGradient = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: card,
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

  static String formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      final parts = value.split('-');
      if (parts.length >= 3) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {}
    return value;
  }

  static String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
