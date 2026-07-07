import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class DrColors {
  static const primary = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFFEEF2FF);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
}

String? drUserAvatarUrl(Map<String, dynamic>? user) {
  if (user == null) return null;
  final raw = (user['avatar'] ?? user['upload_latest_color_photo'])?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  var n = raw.replaceFirst(RegExp(r'^/'), '');
  if (n.startsWith('storage/')) return '${AuthService.storageUrl}/$n';
  if (n.startsWith('public/')) {
    n = n.replaceFirst(RegExp(r'^public/'), '');
    return '${AuthService.storageUrl}/storage/$n';
  }
  return '${AuthService.storageUrl}/storage/$n';
}

String drUserInitials(String? name) {
  final s = name?.trim() ?? '';
  if (s.isEmpty) return '?';
  final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s[0].toUpperCase();
}

class DrUserAvatar extends StatelessWidget {
  final Map<String, dynamic>? user;
  final double size;

  const DrUserAvatar({super.key, this.user, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final url = drUserAvatarUrl(user);
    final name = user?['nama_lengkap']?.toString();
    final initials = drUserInitials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: url == null
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: [
          BoxShadow(color: DrColors.primary.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: url != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initials(initials, size),
                errorWidget: (_, __, ___) => _initials(initials, size),
              ),
            )
          : _initials(initials, size),
    );
  }

  Widget _initials(String text, double s) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: s * 0.34,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class DrStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const DrStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: gradient.last.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                  Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onFilterTap;
  final bool filterActive;

  const DrSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onFilterTap,
    this.filterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DrColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DrColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Cari outlet atau department...',
                hintStyle: TextStyle(color: DrColors.textSecondary.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search_rounded, color: DrColors.textSecondary.withValues(alpha: 0.8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          Container(width: 1, height: 28, color: DrColors.border),
          IconButton(
            onPressed: onFilterTap,
            icon: Icon(
              filterActive ? Icons.tune_rounded : Icons.filter_list_rounded,
              color: filterActive ? DrColors.primary : DrColors.textSecondary,
            ),
            tooltip: 'Filter',
          ),
        ],
      ),
    );
  }
}

class DrChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const DrChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class DrSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const DrSectionCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DrColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DrColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

InputDecoration drInputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, size: 20) : null,
    filled: true,
    fillColor: DrColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DrColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DrColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DrColors.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
