import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Blueprint Isometric & Precision Calibration Background
///
/// Designed specifically for Vocational Assessments and Certification Rubrics.
/// Renders an isometric drafting grid with technical crosshairs, tolerance gauge arcs,
/// and subtle engineering measurement calipers.
class BlueprintIsoBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const BlueprintIsoBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<BlueprintIsoBackground> createState() => _BlueprintIsoBackgroundState();
}

class _BlueprintIsoBackgroundState extends State<BlueprintIsoBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
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
          painter: _BlueprintIsoPainter(
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
          painter: _BlueprintIsoPainter(
            progress: _controller.value,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _BlueprintIsoPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double opacity;

  _BlueprintIsoPainter({
    required this.progress,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.3 * opacity);

    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite)
          .withValues(alpha: 0.35 * opacity);

    final gaugePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.burntOrange.withValues(alpha: 0.25 * opacity);

    // Draw isometric grid lines (angled 30 degrees)
    const spacing = 52.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      // 30-degree diagonal up-right
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.577, 0),
        gridPaint,
      );
      // 30-degree diagonal down-right
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.577, size.height),
        gridPaint,
      );
    }

    // Precision crosshairs at intersections
    for (double y = 60; y < size.height; y += 120) {
      for (double x = 40; x < size.width; x += 100) {
        canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), crossPaint);
        canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), crossPaint);
      }
    }

    // Rotating calibration protractor arc in the upper right
    final arcCenter = Offset(size.width * 0.85, size.height * 0.22);
    final arcRadius = size.width * 0.28;
    final startAngle = progress * 2 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: arcCenter, radius: arcRadius),
      startAngle,
      math.pi * 0.65,
      false,
      gaugePaint,
    );

    // Subtle ISO standard rubric text watermark
    final textStyle = TextStyle(
      fontSize: 9,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: AppColors.burntOrange.withValues(alpha: 0.22 * opacity),
    );
    final watermark = TextPainter(
      text: const TextSpan(
        text: 'ISO-10816 / VOCATIONAL RUBRIC GRID',
        style: null,
      ),
      textDirection: TextDirection.ltr,
    );
    watermark.text = TextSpan(
      text: 'ISO-10816 / VOCATIONAL RUBRIC GRID',
      style: textStyle,
    );
    watermark.layout();
    watermark.paint(canvas, Offset(24, size.height - 30));
  }

  @override
  bool shouldRepaint(covariant _BlueprintIsoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
