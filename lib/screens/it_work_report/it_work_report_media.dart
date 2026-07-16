import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../widgets/app_loading_indicator.dart';
import 'it_work_report_ui.dart';

bool itWorkIsNetworkUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

bool itWorkIsLocalPath(String url) {
  if (url.isEmpty) return false;
  if (itWorkIsNetworkUrl(url)) return false;
  if (url.startsWith('file://') || url.startsWith('file:')) return true;
  if (url.startsWith('/storage/') || url.startsWith('storage/')) return false;
  if (url.startsWith('/data/') ||
      url.startsWith('/private/') ||
      url.startsWith('/var/') ||
      RegExp(r'^[A-Za-z]:[/\\]').hasMatch(url)) {
    return true;
  }
  return !url.startsWith('/');
}

String itWorkLocalPath(String raw) {
  if (raw.startsWith('file://')) return raw.substring(7);
  return raw;
}

String itWorkResolveUrl(String raw) {
  if (raw.isEmpty) return '';
  if (itWorkIsLocalPath(raw)) return itWorkLocalPath(raw);
  return ItWorkReportUi.mediaUrl(raw);
}

/// Stamp photo like web: black semi-transparent bar at bottom with white text
/// lines — datetime, address, lat/lng, maps_url.
Future<File> stampPhotoWithTag(File file, Map meta) async {
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Gagal memuat foto');
  }

  final image = img.bakeOrientation(decoded);
  final date = meta['date']?.toString() ?? '';
  final time = meta['time']?.toString() ?? '';
  final address = meta['address']?.toString() ?? '';
  final lat = meta['latitude'];
  final lng = meta['longitude'];
  final mapsUrl = meta['maps_url']?.toString() ?? '';

  final coord = (lat != null && lng != null)
      ? '${_toFixed(lat, 6)}, ${_toFixed(lng, 6)}'
      : '';

  final lines = <String>[
    if (date.isNotEmpty || time.isNotEmpty) '$date $time'.trim(),
    if (address.isNotEmpty) address,
    if (coord.isNotEmpty) coord,
    if (mapsUrl.isNotEmpty) mapsUrl,
  ];

  final font = _pickFont(image.width);
  final fontSize = font.lineHeight;
  final padding = (fontSize * 0.6).round().clamp(6, 24);
  final lineHeight = (fontSize * 1.35).round();
  final boxHeight = padding * 2 + lineHeight * lines.length;
  final boxY = (image.height - boxHeight).clamp(0, image.height);

  img.fillRect(
    image,
    x1: 0,
    y1: boxY,
    x2: image.width,
    y2: image.height,
    color: img.ColorRgba8(0, 0, 0, 140),
  );

  final white = img.ColorRgb8(255, 255, 255);
  for (var i = 0; i < lines.length; i++) {
    final y = boxY + padding + i * lineHeight;
    img.drawString(
      image,
      lines[i],
      font: font,
      x: padding,
      y: y,
      color: white,
    );
  }

  final outBytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
  final dir = await getTemporaryDirectory();
  final base = file.uri.pathSegments.isNotEmpty
      ? file.uri.pathSegments.last.replaceAll(RegExp(r'\.\w+$'), '')
      : 'camera_${DateTime.now().millisecondsSinceEpoch}';
  final out = File('${dir.path}/${base}_tagged_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await out.writeAsBytes(outBytes, flush: true);
  return out;
}

img.BitmapFont _pickFont(int width) {
  if (width >= 2000) return img.arial48;
  if (width >= 900) return img.arial24;
  return img.arial14;
}

String _toFixed(dynamic v, int digits) {
  final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  return n.toStringAsFixed(digits);
}

String formatItWorkMetaShort(Map? meta) {
  if (meta == null) return '';
  final date = meta['date']?.toString() ?? '';
  final time = meta['time']?.toString() ?? '';
  final dt = (date.isNotEmpty || time.isNotEmpty) ? '$date $time'.trim() : '';
  final lat = meta['latitude'];
  final lng = meta['longitude'];
  final coord = (lat != null && lng != null)
      ? '${_toFixed(lat, 5)},${_toFixed(lng, 5)}'
      : '';
  return [dt, coord].where((e) => e.isNotEmpty).join(' · ');
}

String formatItWorkExistingMetaShort(Map ev) {
  final captured = ev['captured_at']?.toString() ?? '';
  final normalized = captured.replaceFirst('T', ' ');
  final dt = normalized.length >= 19 ? normalized.substring(0, 19) : normalized;
  final lat = ev['latitude'];
  final lng = ev['longitude'];
  final coord = (lat != null && lng != null)
      ? '${_toFixed(lat, 5)},${_toFixed(lng, 5)}'
      : '';
  return [dt, coord].where((e) => e.isNotEmpty).join(' · ');
}

/// Full-screen lightbox with PageView + InteractiveViewer for network or local paths.
void openItWorkLightbox(BuildContext context, List<String> urls, int index) {
  final resolved = urls.map(itWorkResolveUrl).where((u) => u.isNotEmpty).toList();
  if (resolved.isEmpty) return;
  final start = index.clamp(0, resolved.length - 1);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ItWorkLightboxPage(urls: resolved, initialIndex: start),
    ),
  );
}

class _ItWorkLightboxPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ItWorkLightboxPage({required this.urls, required this.initialIndex});

  @override
  State<_ItWorkLightboxPage> createState() => _ItWorkLightboxPageState();
}

class _ItWorkLightboxPageState extends State<_ItWorkLightboxPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _imageFor(String url) {
    if (itWorkIsNetworkUrl(url)) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: AppLoadingIndicator(size: 32, color: Colors.white),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
      );
    }
    return Image.file(
      File(itWorkLocalPath(url)),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(child: _imageFor(widget.urls[i])),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Text(
                  '${_index + 1} / ${widget.urls.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
