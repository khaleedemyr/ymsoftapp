import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Cyan theme matching web IT Work Report (cyan-600).
class ItWorkReportUi {
  static const Color primary = Color(0xFF0891B2);
  static const Color primaryDark = Color(0xFF0E7490);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

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

  static int? userId(Map<String, dynamic> user) {
    final raw = user['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String userName(Map<String, dynamic> user) {
    return user['nama_lengkap']?.toString() ?? user['name']?.toString() ?? '-';
  }
}
