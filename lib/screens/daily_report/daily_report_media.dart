import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../services/daily_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/image_lightbox.dart';
import 'daily_report_ui.dart';

bool drIsVideoUrl(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.m4v');
}

void drOpenDocumentationPreview(BuildContext context, String rawUrl, {List<String>? allUrls}) {
  final resolved = (allUrls ?? [rawUrl]).map(DailyReportService.resolveUrl).where((u) => u.isNotEmpty).toList();
  if (resolved.isEmpty) return;

  final target = DailyReportService.resolveUrl(rawUrl);
  final initialIndex = resolved.indexOf(target);
  final index = initialIndex >= 0 ? initialIndex : 0;

  if (resolved.length == 1 && !drIsVideoUrl(resolved.first)) {
    ImageLightbox.show(context, imageUrl: resolved.first);
    return;
  }

  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _DrDocumentationGalleryDialog(urls: resolved, initialIndex: index),
  );
}

Widget drDocumentationThumbnail(
  BuildContext context, {
  required String rawUrl,
  required List<String> allUrls,
  double size = 88,
}) {
  final url = DailyReportService.resolveUrl(rawUrl);
  final isVideo = drIsVideoUrl(url);

  Widget thumb;
  if (isVideo) {
    thumb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
    );
  } else {
    thumb = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: DrColors.surface,
          child: const Center(child: AppLoadingIndicator(size: 20, color: DrColors.primary)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: DrColors.surface,
          child: const Icon(Icons.broken_image_outlined, color: DrColors.textSecondary),
        ),
      ),
    );
  }

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => drOpenDocumentationPreview(context, rawUrl, allUrls: allUrls),
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          thumb,
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isVideo ? Icons.play_arrow_rounded : Icons.zoom_in_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DrDocumentationGalleryDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _DrDocumentationGalleryDialog({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_DrDocumentationGalleryDialog> createState() => _DrDocumentationGalleryDialogState();
}

class _DrDocumentationGalleryDialogState extends State<_DrDocumentationGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              final url = widget.urls[i];
              if (drIsVideoUrl(url)) {
                return _DrVideoPage(url: url);
              }
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const AppLoadingIndicator(size: 32, color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrVideoPage extends StatefulWidget {
  final String url;

  const _DrVideoPage({required this.url});

  @override
  State<_DrVideoPage> createState() => _DrVideoPageState();
}

class _DrVideoPageState extends State<_DrVideoPage> {
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
    if (_loading) {
      return const Center(child: AppLoadingIndicator(size: 32, color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        ),
      );
    }
    final c = _controller!;
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              if (!c.value.isPlaying)
                Container(
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
