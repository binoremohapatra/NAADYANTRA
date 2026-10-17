import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Live Acoustic Sonar Background
///
/// Designed specifically for the Live Inspection Screen.
/// Renders an active acoustic sonar range radar sweep radiating from the
/// diagnostic probe origin, coupled with real-time pressure acoustic wave oscillations.
class LiveSonarBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const LiveSonarBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<LiveSonarBackground> createState() => _LiveSonarBackgroundState();
}

class _LiveSonarBackgroundState extends State<LiveSonarBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
          painter: _LiveSonarPainter(
            progress: 0.25,
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
          painter: _LiveSonarPainter(
            progress: _controller.value,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _LiveSonarPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double opacity;

  _LiveSonarPainter({
    required this.progress,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.32);
    final maxRadius = math.min(size.width * 0.65, size.height * 0.45);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final ringColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.45 * opacity)
        : AppColors.warmStone.withValues(alpha: 0.5 * opacity);

    ringPaint.color = ringColor;
    crossPaint.color = ringColor;

    // Draw 4 concentric sonar range rings
    const ringCount = 4;
    for (int i = 1; i <= ringCount; i++) {
      final r = maxRadius * (i / ringCount);
      canvas.drawCircle(center, r, ringPaint);
    }

    // Expanding sonar pulse wave
    final pulseRadius = maxRadius * (progress % 1.0);
    final pulseAlpha = (1.0 - (progress % 1.0)) * 0.4 * opacity;
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = AppColors.burntOrange.withValues(alpha: pulseAlpha);
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Crosshairs through sonar center
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );

    // Diagonal tick marks
    for (double deg = 45; deg < 360; deg += 90) {
      final rad = deg * math.pi / 180;
      final p1 = Offset(
        center.dx + math.cos(rad) * (maxRadius * 0.2),
        center.dy + math.sin(rad) * (maxRadius * 0.2),
      );
      final p2 = Offset(
        center.dx + math.cos(rad) * maxRadius,
        center.dy + math.sin(rad) * maxRadius,
      );
      canvas.drawLine(p1, p2, crossPaint);
    }

    // Rotating ultrasonic sweep beam (360 degrees)
    final sweepAngle = progress * 2 * math.pi;
    final beamRect = Rect.fromCircle(center: center, radius: maxRadius);

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: sweepAngle - (math.pi * 0.35),
      endAngle: sweepAngle,
      colors: [
        Colors.transparent,
        AppColors.burntOrange.withValues(alpha: 0.08 * opacity),
        AppColors.burntOrange.withValues(alpha: 0.28 * opacity),
      ],
      stops: const [0.0, 0.7, 1.0],
      transform: GradientRotation(0.0),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(beamRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Leading sweep line
    final lineEnd = Offset(
      center.dx + math.cos(sweepAngle) * maxRadius,
      center.dy + math.sin(sweepAngle) * maxRadius,
    );
    final leadLinePaint = Paint()
      ..color = AppColors.burntOrange.withValues(alpha: 0.7 * opacity)
      ..strokeWidth = 1.5;
    canvas.drawLine(center, lineEnd, leadLinePaint);

    // Bottom acoustic waveform oscillation (reflecting live acoustic sensor stream)
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int w = 0; w < 3; w++) {
      final path = Path();
      final baseY = size.height * (0.75 + (w * 0.08));
      final freq = 0.015 + (w * 0.008);
      final speed = (progress * 2 * math.pi * (w + 1));
      final amp = 14.0 - (w * 3.0);

      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 8) {
        final y =
            baseY + math.sin((x * freq) + speed) * amp * math.cos(x * 0.005);
        path.lineTo(x, y);
      }

      wavePaint.color = AppColors.burntOrange.withValues(
        alpha: (0.12 - (w * 0.03)) * opacity,
      );
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveSonarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
