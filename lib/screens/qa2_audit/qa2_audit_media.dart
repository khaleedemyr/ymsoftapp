import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/app_loading_indicator.dart';
import '../../widgets/image_lightbox.dart';
import 'qa2_audit_ui.dart';

bool qa2IsVideoMedia(Map<String, dynamic> media) {
  final type = media['media_type']?.toString();
  if (type == 'video') return true;
  final url = media['url']?.toString().toLowerCase() ?? '';
  return url.endsWith('.mp4') ||
      url.endsWith('.mov') ||
      url.endsWith('.webm') ||
      url.endsWith('.avi');
}

bool qa2IsLocalMedia(Map<String, dynamic> media) {
  if (media['local'] == true) return true;
  final url = media['url']?.toString() ?? '';
  if (url.isEmpty) return false;
  if (url.startsWith('file://') || url.startsWith('file:')) return true;
  if (url.startsWith('http://') || url.startsWith('https://')) return false;
  // Laravel Storage::url() — remote, bukan file di perangkat.
  if (url.startsWith('/storage/') || url.startsWith('storage/')) return false;
  // Path kamera/galeri di perangkat.
  if (url.startsWith('/data/') ||
      url.startsWith('/private/') ||
      url.startsWith('/var/') ||
      RegExp(r'^[A-Za-z]:\\').hasMatch(url)) {
    return true;
  }
  return false;
}

String qa2LocalMediaPath(String raw) {
  if (raw.startsWith('file://')) return raw.substring(7);
  return raw;
}

void qa2OpenMediaPreview(BuildContext context, Map<String, dynamic> media) {
  if (qa2IsLocalMedia(media) && !qa2IsVideoMedia(media)) {
    final path = qa2LocalMediaPath(media['url']?.toString() ?? '');
    if (path.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
    return;
  }

  final url = Qa2AuditUi.mediaUrl(media['url']);
  if (url.isEmpty) return;
  if (qa2IsVideoMedia(media)) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _Qa2VideoPreviewDialog(url: url),
    );
  } else {
    ImageLightbox.show(context, imageUrl: url);
  }
}

Widget qa2MediaThumbnail(Map<String, dynamic> media, {double size = 84}) {
  if (qa2IsVideoMedia(media)) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
    );
  }

  if (qa2IsLocalMedia(media)) {
    final path = qa2LocalMediaPath(media['url']?.toString() ?? '');
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined, color: Qa2AuditUi.slate500),
        ),
      ),
    );
  }

  final url = Qa2AuditUi.mediaUrl(media['url']);
  return CachedNetworkImage(
    imageUrl: url,
    width: size,
    height: size,
    fit: BoxFit.cover,
    placeholder: (_, __) => Container(
      width: size,
      height: size,
      color: const Color(0xFFF1F5F9),
      child: const Center(child: AppLoadingIndicator(size: 20, color: Qa2AuditUi.primary)),
    ),
    errorWidget: (_, __, ___) => Container(
      width: size,
      height: size,
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.broken_image_outlined, color: Qa2AuditUi.slate500),
    ),
  );
}

class _Qa2VideoPreviewDialog extends StatefulWidget {
  final String url;

  const _Qa2VideoPreviewDialog({required this.url});

  @override
  State<_Qa2VideoPreviewDialog> createState() => _Qa2VideoPreviewDialogState();
}

class _Qa2VideoPreviewDialogState extends State<_Qa2VideoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _loading = false;
      });
      await c.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: _controller?.value.isInitialized == true ? _controller!.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_loading)
              const AppLoadingIndicator(size: 32, color: Colors.white)
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              )
            else if (_controller != null)
              GestureDetector(
                onTap: () {
                  final c = _controller!;
                  setState(() {
                    c.value.isPlaying ? c.pause() : c.play();
                  });
                },
                child: VideoPlayer(_controller!),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
