import 'package:flutter/material.dart';

class AssetSerialTheme {
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color accent = Color(0xFF14B8A6);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;

  static LinearGradient headerGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
  );
}

PreferredSizeWidget assetSerialAppBar(BuildContext context, String title, {List<Widget>? actions}) {
  return AppBar(
    elevation: 0,
    centerTitle: false,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
    flexibleSpace: Container(decoration: BoxDecoration(gradient: AssetSerialTheme.headerGradient)),
    foregroundColor: Colors.white,
    actions: actions,
  );
}

Widget assetSerialSearchField({
  required TextEditingController controller,
  required String hint,
  VoidCallback? onSubmitted,
  VoidCallback? onClear,
  bool showClear = false,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: TextField(
      controller: controller,
      onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 22),
        suffixIcon: showClear
            ? IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: onClear)
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

Widget assetSerialMenuTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
          ],
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget assetSerialStatusChip(String? status) {
  Color bg;
  Color fg;
  String label;
  switch (status) {
    case 'available':
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'AVAILABLE';
    case 'in_service':
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
      label = 'IN SERVICE';
    case 'disposed':
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      label = 'DISPOSED';
    case 'in_transfer':
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      label = 'IN TRANSFER';
    default:
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      label = (status ?? '-').toUpperCase();
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.3)),
  );
}

Widget assetSerialInfoRow(IconData icon, String label, String? value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AssetSerialTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AssetSerialTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value?.isNotEmpty == true ? value! : '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget assetSerialEmptyState({required IconData icon, required String title, String? subtitle}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ],
      ),
    ),
  );
}

Widget assetSerialPrimaryButton({
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
  Color? color,
  bool outlined = false,
}) {
  final c = color ?? AssetSerialTheme.primary;
  if (outlined) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.touch_app_rounded, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.check_rounded, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: c,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

Widget assetSerialCard({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
      ],
    ),
    child: child,
  );
}

/// Footer tetap di bawah layar — aman dari gesture bar / navigator sistem HP.
Widget assetSerialBottomBar({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: child,
      ),
    ),
  );
}
