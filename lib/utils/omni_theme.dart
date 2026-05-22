import 'package:flutter/material.dart';

/// Palet omnichannel — modern, tidak meniru WA hijau mentah.
abstract final class OmniTheme {
  static const primary = Color(0xFF4F46E5);
  static const primaryDark = Color(0xFF4338CA);
  static const primaryLight = Color(0xFFEEF2FF);
  static const accent = Color(0xFF06B6D4);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const outboundBubble = Color(0xFFDCFCE7);
  static const inboundBubble = Colors.white;
  static const internalNote = Color(0xFFFEF3C7);
  static const internalBorder = Color(0xFFFCD34D);
  static const chatBackground = Color(0xFFF1F5F9);

  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? primary.withValues(alpha: 0.4) : border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
