import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JustAcademyUi {
  static const primary = Color(0xFF0D9488);
  static const primaryDark = Color(0xFF0F766E);
  static const accent = Color(0xFF14B8A6);
  static const surface = Color(0xFFF0FDFA);

  static String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  static Color statusColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('berlangsung') || lower.contains('live')) {
      return const Color(0xFF059669);
    }
    if (lower.contains('selesai')) return const Color(0xFF6366F1);
    if (lower.contains('tidak hadir')) return const Color(0xFFDC2626);
    if (lower.contains('sedang')) return const Color(0xFFD97706);
    return const Color(0xFF64748B);
  }

  static Widget progressBar(int percent, {double height = 6}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: (percent.clamp(0, 100)) / 100,
        minHeight: height,
        backgroundColor: const Color(0xFFE2E8F0),
        valueColor: const AlwaysStoppedAnimation<Color>(primary),
      ),
    );
  }

  static Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}
