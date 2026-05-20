import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Suara + dialog gagal scan (selaras GR Serial / Delivery Order / Pindah Gudang).
class InlineScanSound {
  final AudioPlayer _audioPlayer = AudioPlayer();

  void dispose() => _audioPlayer.dispose();

  Future<void> _playTone(double frequency, int durationMs, {double volume = 0.5}) async {
    try {
      final bytes = _generateToneWav(frequency: frequency, durationMs: durationMs, volume: volume);
      await _audioPlayer.play(BytesSource(bytes));
      await Future.delayed(Duration(milliseconds: durationMs + 40));
    } catch (_) {}
  }

  Future<void> playSuccess() async {
    HapticFeedback.lightImpact();
    await _playTone(1568, 90, volume: 0.55);
    await Future.delayed(const Duration(milliseconds: 60));
    await _playTone(2093, 130, volume: 0.55);
  }

  Future<void> playError() async {
    HapticFeedback.heavyImpact();
    await _playTone(440, 130, volume: 0.65);
    await Future.delayed(const Duration(milliseconds: 45));
    await _playTone(330, 150, volume: 0.65);
    await Future.delayed(const Duration(milliseconds: 45));
    await _playTone(220, 220, volume: 0.7);
  }

  Uint8List _generateToneWav({required double frequency, required int durationMs, double volume = 0.5}) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = i < numSamples * 0.1
          ? i / (numSamples * 0.1)
          : (numSamples - i) / (numSamples * 0.3);
      final amp = (sin(2 * pi * frequency * t) * volume * envelope.clamp(0.0, 1.0) * 32767).round();
      samples[i] = amp.clamp(-32768, 32767);
    }

    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final header = ByteData(44);

    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize - 8, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(fileSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, samples.buffer.asUint8List());
    return result;
  }
}

Future<void> showInlineScanFailureDialog(
  BuildContext context, {
  required String message,
  String? scannedValue,
}) async {
  const accent = Color(0xFFDC2626);
  const headerBg = Color(0xFFFEF2F2);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (dialogContext) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                  decoration: const BoxDecoration(
                    color: headerBg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.cancel_rounded, size: 60, color: accent),
                      SizedBox(height: 12),
                      Text(
                        'Scan Gagal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      if (scannedValue != null && scannedValue.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            scannedValue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget buildInlineScanModeToggle({
  required bool cameraMode,
  required Color accent,
  required VoidCallback onScannerTap,
  required VoidCallback onCameraTap,
}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: cameraMode ? onScannerTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: !cameraMode ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: !cameraMode
                    ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_rounded, size: 18, color: !cameraMode ? accent : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Scanner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: !cameraMode ? FontWeight.w700 : FontWeight.w500,
                      color: !cameraMode ? accent : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: !cameraMode ? onCameraTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: cameraMode ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: cameraMode
                    ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, size: 18, color: cameraMode ? accent : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Kamera',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: cameraMode ? FontWeight.w700 : FontWeight.w500,
                      color: cameraMode ? accent : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildInlineCameraPreview({
  required MobileScannerController? controller,
  required Color accent,
  required bool processing,
  required void Function(BarcodeCapture) onDetect,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 180,
      width: double.infinity,
      child: controller != null
          ? Stack(
              children: [
                MobileScanner(controller: controller, onDetect: onDetect),
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: accent.withOpacity(0.6), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (processing)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Memproses...', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(child: CircularProgressIndicator(color: accent)),
    ),
  );
}
