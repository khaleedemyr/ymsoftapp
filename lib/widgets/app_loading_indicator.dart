import 'package:flutter/material.dart';
import 'dart:math' as math;

class AppLoadingIndicator extends StatefulWidget {
  final double? size;
  final Color? color;
  final bool useLogo;
  final double? strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.useLogo = true,
    this.strokeWidth,
  });

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 50.0;

    if (widget.useLogo) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Smooth rotation with pulse effect
          final rotation = _controller.value * 2 * math.pi;
          final pulse = 0.8 + (0.2 * math.sin(_controller.value * 4 * math.pi));
          
          return Transform.scale(
            scale: pulse,
            child: Transform.rotate(
              angle: rotation,
              child: Image.asset(
                'assets/images/logo-icon.png',
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to CircularProgressIndicator if image not found
                  return SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      strokeWidth: widget.strokeWidth ?? 3,
                      valueColor: widget.color != null
                          ? AlwaysStoppedAnimation<Color>(widget.color!)
                          : null,
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    } else {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: widget.strokeWidth ?? 3,
          valueColor: widget.color != null
              ? AlwaysStoppedAnimation<Color>(widget.color!)
              : null,
        ),
      );
    }
  }
}

