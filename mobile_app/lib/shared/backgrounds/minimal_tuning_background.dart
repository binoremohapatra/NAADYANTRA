import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Minimal Tuning & Optical Calibration Background
///
/// Designed specifically for Workstation Settings.
/// Provides a calm, low-distraction mechanical vernier dial ring with subtle
/// graduation ticks and warm ambient optical gradients.
class MinimalTuningBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const MinimalTuningBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<MinimalTuningBackground> createState() =>
      _MinimalTuningBackgroundState();
}

class _MinimalTuningBackgroundState extends State<MinimalTuningBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    );

    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    if (isReduced) {
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _MinimalTuningPainter(
            progress: 0.0,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _MinimalTuningPainter(
            progress: _controller.value,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _MinimalTuningPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double opacity;

  _MinimalTuningPainter({
    required this.progress,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.9, size.height * 0.82);
    final dialRadius = size.width * 0.45;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.35 * opacity);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.burntOrange.withValues(alpha: 0.3 * opacity);

    // Draw concentric dials
    canvas.drawCircle(center, dialRadius, ringPaint);
    canvas.drawCircle(center, dialRadius * 0.75, ringPaint);
    canvas.drawCircle(center, dialRadius * 0.45, ringPaint);

    // Vernier dial ticks rotating slowly
    final rot = progress * 2 * math.pi;
    const tickCount = 36;
    for (int i = 0; i < tickCount; i++) {
      final angle = rot + (i * 2 * math.pi / tickCount);
      final isMajor = i % 6 == 0;
      final innerR = dialRadius - (isMajor ? 10 : 5);
      final outerR = dialRadius;

      final p1 = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );

      tickPaint.strokeWidth = isMajor ? 1.4 : 0.8;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Gentle horizontal baseline grid in top area
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.22 * opacity);

    for (double y = 80; y < size.height * 0.6; y += 60) {
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalTuningPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
