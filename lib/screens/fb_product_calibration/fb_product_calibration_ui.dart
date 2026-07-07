import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FbCalibrationUi {
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryDark = Color(0xFF6D28D9);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static const Color scheduled = Color(0xFF7C3AED);
  static const Color inProgress = Color(0xFF2563EB);
  static const Color completed = Color(0xFF16A34A);

  static BoxDecoration headerGradient = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
        return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {}
    return value;
  }

  static String modeLabel(String? mode, {String? modeLabelFromApi}) {
    if (modeLabelFromApi != null && modeLabelFromApi.isNotEmpty) return modeLabelFromApi;
    return mode == 'bar' ? 'Bar' : 'Kitchen';
  }

  static String statusLabel(String? status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status ?? '-';
    }
  }

  static Color statusColor(String? status) {
    switch (status) {
      case 'scheduled':
        return scheduled;
      case 'in_progress':
        return inProgress;
      case 'completed':
        return completed;
      default:
        return textMuted;
    }
  }

  static Color parseHexColor(String hex, {Color fallback = scheduled}) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}
