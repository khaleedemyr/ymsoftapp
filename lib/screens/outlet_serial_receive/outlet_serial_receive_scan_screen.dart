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

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_cameraProcessing || _scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    final value = barcode.rawValue!.trim();
    _cameraProcessing = true;
    _processScannedValue(value).then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _cameraProcessing = false;
      });
    });
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

  Future<void> _playSuccessSound() async {
    HapticFeedback.lightImpact();
    try {
      final bytes = _generateToneWav(frequency: 1200, durationMs: 150, volume: 0.5);
      await _audioPlayer.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> _playErrorSound() async {
    HapticFeedback.heavyImpact();
    try {
      final bytes = _generateToneWav(frequency: 400, durationMs: 300, volume: 0.5);
      await _audioPlayer.play(BytesSource(bytes));
    } catch (_) {}
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

  Future<void> _processScannedValue(String input) async {
    if (input.isEmpty) return;

    if (_scannedSerials.any((s) => s['serial_number'] == input)) {
      setState(() {
        _feedback = 'Nomor seri ini sudah di-scan.';
        _feedbackSuccess = false;
      });
      _playErrorSound();
      _showSnack('Duplikat: Nomor seri sudah ada di daftar.', isError: true);
      return;
    }

    setState(() {
      _scanning = true;
      _feedback = '';
    });

    try {
      final res = await _service.validateSerial(input);

      if (res != null && res['valid'] == true) {
        final serial = Map<String, dynamic>.from(res['serial']);
        setState(() {
          _scannedSerials.insert(0, serial);
          _feedback = '✓ ${serial['item_name']}';
          _feedbackSuccess = true;
        });
        _playSuccessSound();
      } else {
        final msg = res?['message'] ?? 'Serial tidak valid.';
        setState(() {
          _feedback = msg;
          _feedbackSuccess = false;
        });
        _playErrorSound();
        _showSnack(msg, isError: true);
      }
    } catch (e) {
      setState(() {
        _feedback = 'Gagal memvalidasi serial.';
        _feedbackSuccess = false;
      });
      _playErrorSound();
    }

    setState(() => _scanning = false);
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
          _buildScanCard(),
          _buildStatsRow(),
          Expanded(child: _buildSerialList()),
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
                height: 220,
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
                          if (_scanning || _cameraProcessing)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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

  Widget _buildSerialList() {
    if (_scannedSerials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Scan nomor seri untuk memulai', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _scannedSerials.length,
      itemBuilder: (context, index) {
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
                          Text(
                            s['serial_number'] ?? '',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_fmtQty(s['qty'])} ${s['unit_name'] ?? ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
      },
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
