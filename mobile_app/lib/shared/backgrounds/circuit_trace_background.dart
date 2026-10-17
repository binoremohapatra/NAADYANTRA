import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Circuit Trace PCB Background
///
/// Designed specifically for Hardware Node / Device Details Screen.
/// Renders an authentic motherboard PCB copper trace bus with angular 45-degree
/// conduits, circular via pads, and traveling electron signal packets.
class CircuitTraceBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const CircuitTraceBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<CircuitTraceBackground> createState() => _CircuitTraceBackgroundState();
}

class _CircuitTraceBackgroundState extends State<CircuitTraceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
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
          painter: _CircuitTracePainter(
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
          painter: _CircuitTracePainter(
            progress: _controller.value,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _CircuitTracePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double opacity;

  _CircuitTracePainter({
    required this.progress,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tracePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.35 * opacity);

    final viaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.burntOrange.withValues(alpha: 0.45 * opacity);

    final signalPaint = Paint()..style = PaintingStyle.fill;

    // Define 6 hardware PCB bus traces with 45-degree angle jogs
    final traces = <List<Offset>>[
      [
        Offset(20, size.height * 0.15),
        Offset(size.width * 0.35, size.height * 0.15),
        Offset(size.width * 0.55, size.height * 0.35),
        Offset(size.width * 0.9, size.height * 0.35),
      ],
      [
        Offset(40, size.height * 0.28),
        Offset(size.width * 0.2, size.height * 0.28),
        Offset(size.width * 0.4, size.height * 0.48),
        Offset(size.width * 0.85, size.height * 0.48),
      ],
      [
        Offset(size.width * 0.15, size.height * 0.55),
        Offset(size.width * 0.5, size.height * 0.55),
        Offset(size.width * 0.7, size.height * 0.75),
        Offset(size.width * 0.95, size.height * 0.75),
      ],
      [
        Offset(size.width * 0.1, size.height * 0.72),
        Offset(size.width * 0.4, size.height * 0.72),
        Offset(size.width * 0.55, size.height * 0.87),
        Offset(size.width * 0.8, size.height * 0.87),
      ],
    ];

    for (int t = 0; t < traces.length; t++) {
      final points = traces[t];
      final path = Path()..moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      // Draw PCB copper trace line
      canvas.drawPath(path, tracePaint);

      // Draw circular via pads at start and end
      canvas.drawCircle(points.first, 3.0, viaPaint);
      canvas.drawCircle(points.last, 3.0, viaPaint);

      // Traveling signal packet along this trace path
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final totalLen = metric.length;
        final packetProgress = (progress * 1.6 + (t * 0.25)) % 1.0;
        final tangent = metric.getTangentForOffset(totalLen * packetProgress);

        if (tangent != null) {
          signalPaint.color = AppColors.burntOrange.withValues(
            alpha: (0.7 + 0.3 * math.sin(packetProgress * math.pi)) * opacity,
          );
          // Core packet dot
          canvas.drawCircle(tangent.position, 2.8, signalPaint);

          // Glow around signal packet
          final glowPaint = Paint()
            ..color = AppColors.burntOrange.withValues(alpha: 0.25 * opacity)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(tangent.position, 6.0, glowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitTracePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
