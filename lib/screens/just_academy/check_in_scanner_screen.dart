import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/just_academy_service.dart';
import '../../widgets/app_loading_indicator.dart';
import 'just_academy_ui.dart';

class CheckInScannerScreen extends StatefulWidget {
  final int scheduleId;
  final String scheduleTitle;

  const CheckInScannerScreen({
    super.key,
    required this.scheduleId,
    required this.scheduleTitle,
  });

  @override
  State<CheckInScannerScreen> createState() => _CheckInScannerScreenState();
}

class _CheckInScannerScreenState extends State<CheckInScannerScreen> {
  final _service = JustAcademyService();
  final _tokenCtrl = TextEditingController();
  MobileScannerController? _cameraController;
  bool _processing = false;
  bool _useManual = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitToken(String raw) async {
    if (_processing) return;
    final token = raw.trim();
    if (token.isEmpty) return;

    setState(() => _processing = true);
    final ok = await _service.checkIn(widget.scheduleId, token);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in gagal. Pastikan QR code valid.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Check-in Training'),
        backgroundColor: JustAcademyUi.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.scheduleTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan QR code dari trainer untuk check-in',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _useManual
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _tokenCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Token QR',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF334155)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: JustAcademyUi.accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _processing ? null : () => _submitToken(_tokenCtrl.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: JustAcademyUi.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _processing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Check-in'),
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: MobileScanner(
                          controller: _cameraController,
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final value = barcode.rawValue;
                              if (value != null && value.isNotEmpty) {
                                _submitToken(value);
                                break;
                              }
                            }
                          },
                        ),
                      ),
                      if (_processing)
                        Container(
                          color: Colors.black54,
                          child: const Center(child: AppLoadingIndicator()),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => setState(() => _useManual = !_useManual),
              child: Text(
                _useManual ? 'Gunakan kamera' : 'Input token manual',
                style: const TextStyle(color: JustAcademyUi.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
