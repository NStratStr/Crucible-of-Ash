import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Highly optimized SpriteSheetAnimation widget.
/// Decodes and renders sprite sheets of any column x row dimensions.
/// Supports both one-shot attack VFX and looping animations.
class SpriteSheetAnimation extends StatefulWidget {
  final String assetPath;
  final int columns;
  final int rows;
  final int totalFrames;
  final Duration duration;
  final bool loop;
  final VoidCallback? onComplete;
  final BoxFit fit;
  final BlendMode? blendMode;
  final Color? colorFilter;

  const SpriteSheetAnimation({
    super.key,
    required this.assetPath,
    required this.columns,
    required this.rows,
    int? totalFrames,
    this.duration = const Duration(milliseconds: 500),
    this.loop = false,
    this.onComplete,
    this.fit = BoxFit.contain,
    this.blendMode,
    this.colorFilter,
  }) : totalFrames = totalFrames ?? (columns * rows);

  @override
  State<SpriteSheetAnimation> createState() => _SpriteSheetAnimationState();
}

class _SpriteSheetAnimationState extends State<SpriteSheetAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _image;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward().then((_) {
        if (mounted) {
          widget.onComplete?.call();
        }
      });
    }

    _loadSpriteSheet();
  }

  Future<void> _loadSpriteSheet() async {
    try {
      final ByteData data = await rootBundle.load(widget.assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frameInfo.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load sprite sheet: ${widget.assetPath}, error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant SpriteSheetAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _image == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = _controller.value;
        final int currentFrame = (progress * widget.totalFrames).floor().clamp(0, widget.totalFrames - 1);

        final int col = currentFrame % widget.columns;
        final int row = currentFrame ~/ widget.columns;

        return CustomPaint(
          painter: _SpriteSheetPainter(
            image: _image!,
            columns: widget.columns,
            rows: widget.rows,
            frameCol: col,
            frameRow: row,
            fit: widget.fit,
            blendMode: widget.blendMode,
            colorFilter: widget.colorFilter,
          ),
        );
      },
    );
  }
}

class _SpriteSheetPainter extends CustomPainter {
  final ui.Image image;
  final int columns;
  final int rows;
  final int frameCol;
  final int frameRow;
  final BoxFit fit;
  final BlendMode? blendMode;
  final Color? colorFilter;

  _SpriteSheetPainter({
    required this.image,
    required this.columns,
    required this.rows,
    required this.frameCol,
    required this.frameRow,
    required this.fit,
    this.blendMode,
    this.colorFilter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double frameWidth = image.width / columns;
    final double frameHeight = image.height / rows;

    final Rect srcRect = Rect.fromLTWH(
      frameCol * frameWidth,
      frameRow * frameHeight,
      frameWidth,
      frameHeight,
    );

    final Rect dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final Paint paint = Paint()..filterQuality = FilterQuality.high;
    if (colorFilter != null) {
      paint.colorFilter = ColorFilter.mode(colorFilter!, blendMode ?? BlendMode.srcIn);
    } else if (blendMode != null) {
      paint.blendMode = blendMode!;
    }

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpriteSheetPainter oldDelegate) {
    return oldDelegate.frameCol != frameCol ||
        oldDelegate.frameRow != frameRow ||
        oldDelegate.image != image;
  }
}
