import 'package:flutter/material.dart';
import 'serial_number_actions.dart';
import 'serial_tracking_ui.dart';

/// Kartu nomor seri — layout vertikal agar aman di layar sempit (hindari overflow tabel).
class SerialTrackingSerialCard extends StatelessWidget {
  const SerialTrackingSerialCard({
    super.key,
    required this.serial,
    this.onTrack,
    this.showStatus = false,
    this.compactActions = true,
  });

  final Map<String, dynamic> serial;
  final VoidCallback? onTrack;
  final bool showStatus;
  final bool compactActions;

  String get _serialNumber => serial['serial_number']?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    final itemName = serial['item_name']?.toString();
    final itemSku = serial['item_sku']?.toString();
    final unitName = serial['unit_name']?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: SerialTrackingUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _serialNumber,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: SerialTrackingUi.indigoDark,
            ),
          ),
          if (itemName != null && itemName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              itemSku != null && itemSku.isNotEmpty ? '$itemName ($itemSku)' : itemName,
              style: const TextStyle(fontSize: 12, color: SerialTrackingUi.slate900),
            ),
          ],
          if (unitName != null && unitName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Unit: $unitName', style: const TextStyle(fontSize: 11, color: SerialTrackingUi.slate500)),
          ],
          if (showStatus) ...[
            const SizedBox(height: 8),
            SerialTrackingUi.serialStatusBadge(serial),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SerialNumberActions(
                serialNumber: _serialNumber == '—' ? '' : _serialNumber,
                compact: compactActions,
              ),
              if (onTrack != null)
                TextButton(
                  onPressed: onTrack,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: SerialTrackingUi.indigoDark,
                  ),
                  child: const Text('Lacak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
