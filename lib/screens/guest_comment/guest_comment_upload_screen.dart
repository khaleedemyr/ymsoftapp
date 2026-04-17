import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/guest_comment_service.dart';
import 'guest_comment_form_screen.dart';

/// Unggah foto formulir guest comment → OCR di server → lanjut verifikasi.
class GuestCommentUploadScreen extends StatefulWidget {
  const GuestCommentUploadScreen({super.key});

  @override
  State<GuestCommentUploadScreen> createState() =>
      _GuestCommentUploadScreenState();
}

class _GuestCommentUploadScreenState extends State<GuestCommentUploadScreen> {
  final _service = GuestCommentService();
  final _picker = ImagePicker();
  File? _file;
  bool _uploading = false;

  Future<void> _pick(ImageSource src) async {
    // 1600px + server resize; OCR bisa pakai Gemini Flash di server (lebih murah) dengan resolusi tetap layak.
    final x = await _picker.pickImage(
      source: src,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (x == null) return;
    setState(() => _file = File(x.path));
  }

  Future<void> _upload() async {
    if (_file == null) return;
    setState(() => _uploading = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    'Mengunggah & mengolah OCR…',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Map<String, dynamic> res;
    try {
      res = await _service.uploadImage(_file!);
    } catch (e) {
      res = {'success': false, 'message': e.toString()};
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _uploading = false);
      }
    }

    if (!mounted) return;

    if (res['success'] == true && res['form'] != null) {
      final id = res['form']['id'];
      int? fid;
      if (id is int) fid = id;
      if (id is num) fid = id.toInt();
      if (fid != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Berhasil',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  res['message']?.toString() ?? 'Foto tersimpan. Silakan verifikasi data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.35, color: Colors.grey.shade800),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  minimumSize: const Size(120, 44),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Lanjut'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => GuestCommentFormScreen(formId: fid!),
          ),
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? 'Gagal mengunggah'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Foto formulir'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Pilih sumber gambar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Formulir panjang? Usahakan pencahayaan terang dan teks terbaca.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SourceCard(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  color: cs.primary,
                  onTap: () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SourceCard(
                  icon: Icons.photo_camera_rounded,
                  label: 'Kamera',
                  color: const Color(0xFF059669),
                  onTap: () => _pick(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_file != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 210 / 297,
                child: Image.file(
                  _file!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_uploading ? 'Mengunggah & OCR…' : 'Unggah & lanjut'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color.darken(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Color {
  Color darken([double a = 0.2]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - a).clamp(0.0, 1.0))
        .toColor();
  }
}
