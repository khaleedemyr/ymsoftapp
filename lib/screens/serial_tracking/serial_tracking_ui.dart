import 'package:flutter/material.dart';

/// Gaya UI selaras Outlet Transfer + warna web Serial Tracking.
class SerialTrackingUi {
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoDark = Color(0xFF4F46E5);
  static const Color amber = Color(0xFFD97706);
  static const Color amberDark = Color(0xFFB45309);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      );

  static InputDecoration fieldDecoration({String? hint, IconData? prefix}) => InputDecoration(
        hintText: hint,
        prefixIcon: prefix != null ? Icon(prefix, size: 20, color: indigo) : null,
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: indigo, width: 1.5),
        ),
      );

  static bool isTruthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v == 1;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static Widget serialStatusBadge(Map<String, dynamic> s) {
    String label;
    Color bg;
    Color fg;
    if (isTruthy(s['is_out'])) {
      label = 'Keluar';
      bg = const Color(0xFFFFFBEB);
      fg = amberDark;
    } else if (isTruthy(s['is_received'])) {
      label = 'Di outlet';
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else {
      label = 'Gudang';
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
