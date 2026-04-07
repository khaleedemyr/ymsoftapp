import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_loading_indicator.dart';

class ImageLightbox extends StatelessWidget {
  final String imageUrl;
  final String? fileName;
  final Map<String, String>? headers;

  const ImageLightbox({
    super.key,
    required this.imageUrl,
    this.fileName,
    this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Full screen image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: headers != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      httpHeaders: headers,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: AppLoadingIndicator(size: 30, color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: AppLoadingIndicator(size: 30, color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
            ),
          ),
          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // File name at bottom
          if (fileName != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fileName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String imageUrl,
    String? fileName,
    Map<String, String>? headers,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ImageLightbox(
        imageUrl: imageUrl,
        fileName: fileName,
        headers: headers,
      ),
    );
  }
}

