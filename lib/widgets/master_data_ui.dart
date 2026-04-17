import 'package:flutter/material.dart';

BoxDecoration _surfaceDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 14,
      ),
    ],
  );
}

Widget buildMasterHeaderCard({
  required IconData icon,
  required String title,
  required VoidCallback onAddPressed,
  String addLabel = 'Buat',
}) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAddPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1D4ED8),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(addLabel),
        ),
      ],
    ),
  );
}

Widget buildMasterFilterCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(14),
    decoration: _surfaceDecoration(),
    child: child,
  );
}

Widget buildMasterCodeChip(String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFDBEAFE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: Color(0xFF1D4ED8),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget buildMasterCardTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Color(0xFF0F172A),
    ),
  );
}

Widget buildMasterMetaText(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF475569),
      height: 1.3,
    ),
  );
}

Widget buildMasterMetaPill({
  required IconData icon,
  required String text,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF475569)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget buildMasterStatusBadge({
  required bool isActive,
  String activeText = 'Active',
  String inactiveText = 'Inactive',
  VoidCallback? onTap,
}) {
  final bgColor = isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9);
  final fgColor = isActive ? const Color(0xFF166534) : const Color(0xFF334155);

  final badge = Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      isActive ? activeText : inactiveText,
      style: TextStyle(
        color: fgColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  if (onTap == null) return badge;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: badge,
  );
}

Widget buildMasterActionButtons({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  String deleteLabel = 'Nonaktifkan',
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Edit'),
      ),
      FilledButton.icon(
        onPressed: onDelete,
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        icon: const Icon(Icons.delete_outline, size: 16),
        label: Text(deleteLabel),
      ),
    ],
  );
}
