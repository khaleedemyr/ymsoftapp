import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UpsellingUi {
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

  static String formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(value);
  }

  static String formatPercent(double value) {
    if (value.isNaN || value.isInfinite) return '0%';
    return '${value.toStringAsFixed(1)}%';
  }

  static Color achievementColor(double percent) {
    if (percent >= 100) return const Color(0xFF059669);
    if (percent >= 75) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  static Color achievementBg(double percent) {
    if (percent >= 100) return const Color(0xFFD1FAE5);
    if (percent >= 75) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
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
