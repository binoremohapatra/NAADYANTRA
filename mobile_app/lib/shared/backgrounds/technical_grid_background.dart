import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Technical Grid Background
///
/// Renders a precision engineering grid with coordinate crosshairs (+)
/// and an optional low-frequency scanning light beam. Adapts to both Light
/// (Industrial Ivory) and Dark (Carbon) themes. Wrapped in RepaintBoundary.
class TechnicalGridBackground extends StatefulWidget {
  final Widget? child;
  final bool showScanLine;
  final double gridSpacing;
  final double opacity;

  const TechnicalGridBackground({
    super.key,
    this.child,
    this.showScanLine = true,
    this.gridSpacing = 36.0,
    this.opacity = 0.55,
  });

  @override
  State<TechnicalGridBackground> createState() =>
      _TechnicalGridBackgroundState();
}

class _TechnicalGridBackgroundState extends State<TechnicalGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationAmbient,
    );

    if (widget.showScanLine) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant TechnicalGridBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showScanLine != oldWidget.showScanLine) {
      if (widget.showScanLine) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _TechnicalGridPainter(
              progress: isReduced || !widget.showScanLine
                  ? 0.0
                  : _controller.value,
              gridSpacing: widget.gridSpacing,
              isDark: isDark,
              opacity: widget.opacity,
              showScanLine: widget.showScanLine && !isReduced,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _TechnicalGridPainter extends CustomPainter {
  final double progress;
  final double gridSpacing;
  final bool isDark;
  final double opacity;
  final bool showScanLine;

  _TechnicalGridPainter({
    required this.progress,
    required this.gridSpacing,
    required this.isDark,
    required this.opacity,
    required this.showScanLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isDark
        ? const Color(0xFF333333).withValues(alpha: opacity * 0.5)
        : AppColors.warmStone.withValues(alpha: opacity * 0.7);

    final crosshairColor = isDark
        ? AppColors.burntOrange.withValues(alpha: opacity * 0.4)
        : AppColors.burntOrange.withValues(alpha: opacity * 0.35);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final crosshairPaint = Paint()
      ..color = crosshairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Grid lines
    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Crosshair ticks at every 2nd intersection
    const tickLen = 3.0;
    for (double x = gridSpacing; x < size.width; x += gridSpacing * 2) {
      for (double y = gridSpacing; y < size.height; y += gridSpacing * 2) {
        canvas.drawLine(
          Offset(x - tickLen, y),
          Offset(x + tickLen, y),
          crosshairPaint,
        );
        canvas.drawLine(
          Offset(x, y - tickLen),
          Offset(x, y + tickLen),
          crosshairPaint,
        );
      }
    }

    // Slow scanning line beam
    if (showScanLine) {
      final scanY = size.height * progress;
      final scanRect = Rect.fromLTWH(0, scanY - 45, size.width, 90);

      final scanPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.burntOrange.withValues(alpha: 0.0),
            AppColors.burntOrange.withValues(alpha: 0.16 * opacity),
            AppColors.burntOrange.withValues(alpha: 0.0),
          ],
        ).createShader(scanRect);

      canvas.drawRect(scanRect, scanPaint);

      final lineBeamPaint = Paint()
        ..color = AppColors.burntOrange.withValues(alpha: 0.60 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawLine(
        Offset(0, scanY),
        Offset(size.width, scanY),
        lineBeamPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TechnicalGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
