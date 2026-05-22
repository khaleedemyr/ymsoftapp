import 'package:flutter/material.dart';

/// Badge / ikon sumber channel (WA, IG, FB, TikTok).
class OmniChannelIcon extends StatelessWidget {
  final String channel;
  final double size;
  final bool showLabel;

  const OmniChannelIcon({
    super.key,
    required this.channel,
    this.size = 20,
    this.showLabel = false,
  });

  static String normalize(String? raw) => (raw ?? 'whatsapp').toLowerCase().trim();

  static Color brandColor(String channel) {
    switch (normalize(channel)) {
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'facebook':
      case 'messenger':
        return const Color(0xFF1877F2);
      case 'tiktok':
        return const Color(0xFF010101);
      case 'whatsapp':
      default:
        return const Color(0xFF25D366);
    }
  }

  static String shortLabel(String channel) {
    switch (normalize(channel)) {
      case 'instagram':
        return 'IG';
      case 'facebook':
      case 'messenger':
        return 'FB';
      case 'tiktok':
        return 'TT';
      case 'whatsapp':
      default:
        return 'WA';
    }
  }

  static IconData iconData(String channel) {
    switch (normalize(channel)) {
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'facebook':
      case 'messenger':
        return Icons.thumb_up_alt_outlined;
      case 'tiktok':
        return Icons.music_note_outlined;
      case 'whatsapp':
      default:
        return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = normalize(channel);
    final color = brandColor(ch);
    final label = shortLabel(ch);

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Icon(iconData(ch), size: size * 0.55, color: Colors.white),
    );

    if (!showLabel) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

/// Avatar kontak + badge channel di pojok kanan bawah.
class OmniContactAvatar extends StatelessWidget {
  final String title;
  final String channel;
  final double radius;
  final String? imageUrl;

  const OmniContactAvatar({
    super.key,
    required this.title,
    required this.channel,
    this.radius = 26,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final brand = OmniChannelIcon.brandColor(channel);
    final resolvedUrl = imageUrl != null && imageUrl!.trim().isNotEmpty ? imageUrl!.trim() : null;

    Widget avatarChild;
    if (resolvedUrl != null) {
      avatarChild = ClipOval(
        child: Image.network(
          resolvedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialAvatar(initial, brand),
        ),
      );
    } else {
      avatarChild = _initialAvatar(initial, brand);
    }

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarChild,
          Positioned(
            right: -2,
            bottom: -2,
            child: OmniChannelIcon(channel: channel, size: radius * 0.72),
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar(String initial, Color brand) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: brand.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(color: brand, fontWeight: FontWeight.bold, fontSize: radius * 0.85),
      ),
    );
  }
}

/// Badge nama akun bisnis (IG page / WA number) seperti di web.
class OmniChannelAccountBadge extends StatelessWidget {
  final String channel;
  final String label;

  const OmniChannelAccountBadge({
    super.key,
    required this.channel,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (channel) {
      'instagram' => (
          const Color(0xFFFDF2F8),
          const Color(0xFF9D174D),
          const Color(0xFFFBCFE8),
        ),
      'messenger' || 'facebook' => (
          const Color(0xFFEFF6FF),
          const Color(0xFF1D4ED8),
          const Color(0xFFBFDBFE),
        ),
      _ => (
          const Color(0xFFF0FDF4),
          const Color(0xFF166534),
          const Color(0xFFBBF7D0),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
