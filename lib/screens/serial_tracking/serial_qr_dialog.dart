import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'serial_tracking_ui.dart';

Future<void> showSerialQrDialog(BuildContext context, String serialNumber) {
  final sn = serialNumber.trim();
  if (sn.isEmpty) return Future.value();

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'QR Nomor Seri',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SerialTrackingUi.slate900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sn,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SerialTrackingUi.indigoDark,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SerialTrackingUi.border),
              ),
              child: QrImageView(
                data: sn,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan QR untuk mendapatkan nomor seri',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SerialTrackingUi.slate500),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: SerialTrackingUi.border),
                ),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
