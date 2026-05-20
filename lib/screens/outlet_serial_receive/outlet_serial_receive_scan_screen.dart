import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/outlet_serial_receive_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';

class OutletSerialReceiveScanScreen extends StatefulWidget {
  const OutletSerialReceiveScanScreen({super.key});

  @override
  State<OutletSerialReceiveScanScreen> createState() => _OutletSerialReceiveScanScreenState();
}

class _OutletSerialReceiveScanScreenState extends State<OutletSerialReceiveScanScreen> {
  final OutletSerialReceiveService _service = OutletSerialReceiveService();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _serialFocus = FocusNode();

  final AudioPlayer _audioPlayer = AudioPlayer();
  MobileScannerController? _cameraController;

  List<Map<String, dynamic>> _scannedSerials = [];
  bool _scanning = false;
  bool _saving = false;
  String _feedback = '';
  bool _feedbackSuccess = false;
  String _outletName = '';
  bool _cameraMode = false;
  bool _cameraProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serialFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _serialController.dispose();
    _notesController.dispose();
    _serialFocus.dispose();
    _audioPlayer.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleCameraMode() {
    setState(() {
      _cameraMode = !_cameraMode;
      if (_cameraMode) {
        _cameraController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
        );
      } else {
        _cameraController?.dispose();
        _cameraController = null;
        _serialFocus.requestFocus();
      }
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_cameraProcessing || (_scanning && !_cameraMode)) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    final value = barcode.rawValue!.trim();
    if (!mounted) return;
    setState(() => _cameraProcessing = true);

    try {
      await _processScannedValue(value, fromCamera: true);
    } finally {
      // Debounce agar tidak double-scan barcode yang sama
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _cameraProcessing = false);
    }
  }

  Future<void> _loadUserInfo() async {
    final auth = AuthService();
    final userData = await auth.getUserData();
    if (userData != null && mounted) {
      final outletId = userData['id_outlet']?.toString();
      if (outletId != null && outletId.isNotEmpty) {
        final res = await _service.getList(page: 1, perPage: 1);
        if (res != null && mounted) {
          setState(() {
            _outletName = res['user_outlet']?['name'] ?? outletId;
          });
        }
      }
    }
  }

  Future<void> _playTone(double frequency, int durationMs, {double volume = 0.5}) async {
    try {
      final bytes = _generateToneWav(frequency: frequency, durationMs: durationMs, volume: volume);
      await _audioPlayer.play(BytesSource(bytes));
      await Future.delayed(Duration(milliseconds: durationMs + 40));
    } catch (_) {}
  }

  /// Dua nada naik — jelas terdengar sebagai "berhasil".
  Future<void> _playSuccessSound() async {
    HapticFeedback.lightImpact();
    await _playTone(1568, 90, volume: 0.55);
    await Future.delayed(const Duration(milliseconds: 60));
    await _playTone(2093, 130, volume: 0.55);
  }

  /// Tiga nada turun — jelas terdengar sebagai "gagal / error".
  Future<void> _playErrorSound() async {
    HapticFeedback.heavyImpact();
    await _playTone(440, 130, volume: 0.65);
    await Future.delayed(const Duration(milliseconds: 45));
    await _playTone(330, 150, volume: 0.65);
    await Future.delayed(const Duration(milliseconds: 45));
    await _playTone(220, 220, volume: 0.7);
  }

  Future<void> _showScanFailureFeedback({
    required String message,
    String? serialNumber,
  }) async {
    if (!mounted) return;

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
                        if (serialNumber != null && serialNumber.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              serialNumber,
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

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize - 8, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // PCM
    header.setUint16(22, 1, Endian.little);  // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little);  // block align
    header.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(fileSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, samples.buffer.asUint8List());
    return result;
  }

  Future<void> _onScan() async {
    final input = _serialController.text.trim();
    if (input.isEmpty) return;
    await _processScannedValue(input);
    _serialController.clear();
    _serialFocus.requestFocus();
  }

  Future<void> _processScannedValue(String input, {bool fromCamera = false}) async {
    if (input.isEmpty) return;

    if (_scannedSerials.any((s) => s['serial_number'] == input)) {
      if (mounted) {
        setState(() {
          _feedback = 'Nomor seri ini sudah di-scan.';
          _feedbackSuccess = false;
        });
      }
      await _playErrorSound();
      await _showScanFailureFeedback(
        message: 'Nomor seri ini sudah ada di daftar scan.',
        serialNumber: input,
      );
      return;
    }

    if (mounted) {
      setState(() {
        if (!fromCamera) _scanning = true;
        _feedback = fromCamera ? 'Memvalidasi...' : '';
        _feedbackSuccess = false;
      });
    }

    try {
      final res = await _service.validateSerial(input);

      if (!mounted) return;

      if (res != null && res['valid'] == true) {
        final serial = Map<String, dynamic>.from(res['serial']);
        final itemName = serial['item_name']?.toString() ?? '';
        setState(() {
          _scannedSerials.insert(0, serial);
          _feedback = itemName.isNotEmpty ? '✓ $itemName' : '✓ Berhasil';
          _feedbackSuccess = true;
        });
        unawaited(_playSuccessSound());
      } else {
        final msg = res?['message'] ?? 'Nomor seri tidak ditemukan atau tidak valid.';
        setState(() {
          _feedback = msg;
          _feedbackSuccess = false;
        });
        await _playErrorSound();
        await _showScanFailureFeedback(message: msg, serialNumber: input);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Gagal memvalidasi serial.';
        _feedbackSuccess = false;
      });
      await _playErrorSound();
      await _showScanFailureFeedback(
        message: 'Tidak dapat memvalidasi nomor seri. Periksa koneksi internet lalu coba lagi.',
        serialNumber: input,
      );
    } finally {
      if (mounted && !fromCamera) {
        setState(() => _scanning = false);
      }
    }
  }

  void _removeSerial(int index) {
    setState(() => _scannedSerials.removeAt(index));
  }

  Future<void> _onSave() async {
    if (_scannedSerials.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Simpan GR Serial?'),
        content: Text('${_scannedSerials.length} serial akan diproses dan masuk inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);

    final res = await _service.store(
      serials: _scannedSerials,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    setState(() => _saving = false);

    if (res != null && res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Berhasil disimpan.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      _showSnack(res?['message'] ?? 'Gagal menyimpan.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _fmtRupiah(dynamic val) {
    if (val == null) return '-';
    final n = double.tryParse(val.toString()) ?? 0;
    if (n == 0) return '-';
    return 'Rp ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _fmtQty(dynamic val) {
    if (val == null) return '-';
    final n = double.tryParse(val.toString()) ?? 0;
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  int get _uniqueDOs => _scannedSerials.map((s) => s['do_number']).toSet().length;
  int get _uniqueItems => _scannedSerials.map((s) => s['item_id']).toSet().length;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buat GR Serial',
      showDrawer: false,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildScanCard()),
                SliverToBoxAdapter(child: _buildStatsRow()),
                _buildSerialListSliver(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          if (_outletName.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_rounded, size: 16, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Text(_outletName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                ],
              ),
            ),
          Text(
            'Hanya serial untuk outlet ini yang dapat di-scan',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),

          // Mode toggle: Scanner Eksternal vs Kamera
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _cameraMode ? _toggleCameraMode : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_cameraMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_cameraMode
                            ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_rounded, size: 18, color: !_cameraMode ? const Color(0xFF4F46E5) : Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Scanner',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: !_cameraMode ? FontWeight.w700 : FontWeight.w500,
                              color: !_cameraMode ? const Color(0xFF4F46E5) : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: !_cameraMode ? _toggleCameraMode : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _cameraMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _cameraMode
                            ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 18, color: _cameraMode ? const Color(0xFF4F46E5) : Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Kamera',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _cameraMode ? FontWeight.w700 : FontWeight.w500,
                              color: _cameraMode ? const Color(0xFF4F46E5) : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_cameraMode) ...[
            // Camera preview
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: _cameraController != null
                    ? Stack(
                        children: [
                          MobileScanner(
                            controller: _cameraController!,
                            onDetect: _onBarcodeDetected,
                          ),
                          // Overlay scan line animation
                          Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.6), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (_cameraProcessing)
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
                                    Text('Validasi...', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arahkan kamera ke barcode nomor seri',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            _buildCameraScannedList(),
          ] else ...[
            // External scanner text input
            TextField(
              controller: _serialController,
              focusNode: _serialFocus,
              enabled: !_scanning && !_saving,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Scan nomor seri...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4F46E5)),
                suffixIcon: _scanning
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => _onScan(),
            ),
          ],

          if (_feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _feedback,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _feedbackSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraScannedList() {
    if (_scannedSerials.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'Belum ada serial di-scan',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Text(
                  'Sudah di-scan (${_scannedSerials.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('No. Seri', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
                Expanded(flex: 4, child: Text('Nama', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _scannedSerials.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 10, endIndent: 10),
              itemBuilder: (context, index) {
                final s = _scannedSerials[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          s['serial_number']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          s['item_name']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _fmtQty(s['qty']),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s['unit_name']?.toString() ?? '-',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_saving)
                        InkWell(
                          onTap: () => _removeSerial(index),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatChip('${_scannedSerials.length}', 'Serial', const Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          _buildStatChip('$_uniqueDOs', 'DO', const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          _buildStatChip('$_uniqueItems', 'Item', const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildSerialListSliver() {
    if (_scannedSerials.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text('Scan nomor seri untuk memulai', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildSerialListItem(index),
          childCount: _scannedSerials.length,
        ),
      ),
    );
  }

  Widget _buildSerialListItem(int index) {
    final s = _scannedSerials[index];
    return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['item_name'] ?? '-',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s['serial_number'] ?? '',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_fmtQty(s['qty'])} ${s['unit_name'] ?? ''}'.trim(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DO: ${s['do_number'] ?? '-'} • ${_fmtRupiah(s['cost_small'])}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (!_saving)
                  InkWell(
                    onTap: () => _removeSerial(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                    ),
                  ),
              ],
            ),
          ),
        );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Catatan...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _scannedSerials.isEmpty || _saving ? null : _onSave,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text('Simpan (${_scannedSerials.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
