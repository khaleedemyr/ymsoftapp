import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'serial_qr_dialog.dart';
import 'serial_tracking_ui.dart';

class SerialNumberActions extends StatelessWidget {
  const SerialNumberActions({
    super.key,
    required this.serialNumber,
    this.showLabel = false,
    this.compact = false,
  });

  final String serialNumber;
  final bool showLabel;
  final bool compact;

  Future<void> _copy(BuildContext context) async {
    final sn = serialNumber.trim();
    if (sn.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: sn));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nomor seri disalin'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1800),
      ),
    );
  }

  void _showQr(BuildContext context) {
    showSerialQrDialog(context, serialNumber);
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 14.0 : 16.0;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 6);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          onPressed: () => _copy(context),
          icon: Icons.copy_rounded,
          label: showLabel ? 'Copy' : null,
          iconSize: iconSize,
          padding: padding,
          foreground: SerialTrackingUi.slate600,
          border: SerialTrackingUi.border,
        ),
        const SizedBox(width: 4),
        _ActionButton(
          onPressed: () => _showQr(context),
          icon: Icons.qr_code_rounded,
          label: showLabel ? 'QR' : null,
          iconSize: iconSize,
          padding: padding,
          foreground: SerialTrackingUi.indigoDark,
          border: const Color(0xFFC7D2FE),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.iconSize,
    required this.padding,
    required this.foreground,
    required this.border,
    this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double iconSize;
  final EdgeInsets padding;
  final Color foreground;
  final Color border;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: foreground),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: foreground)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
