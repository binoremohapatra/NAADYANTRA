import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Spectral Matrix Background
///
/// Designed specifically for Session Detail & Forensic FFT Analysis.
/// Renders an acoustic frequency spectrogram matrix with oscillating harmonic
/// spectral bands, Nyquist frequency markers, and dB graduation scales.
class SpectralMatrixBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const SpectralMatrixBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<SpectralMatrixBackground> createState() =>
      _SpectralMatrixBackgroundState();
}

class _SpectralMatrixBackgroundState extends State<SpectralMatrixBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
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
          painter: _SpectralMatrixPainter(
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
          painter: _SpectralMatrixPainter(
            progress: _controller.value,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _SpectralMatrixPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double opacity;

  _SpectralMatrixPainter({
    required this.progress,
    required this.isDark,
    required this.opacity,
  });

  static const List<String> _freqLabels = [
    '48 kHz (Ultrasonic Peak)',
    '36 kHz (Harmonic Band)',
    '24 kHz (Nyquist Limit)',
    '12 kHz (Acoustic Mid)',
    '0 kHz (Baseline)',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final barPaint = Paint()..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      fontSize: 8.5,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: (isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite)
          .withValues(alpha: 0.4 * opacity),
    );

    // Draw 5 horizontal frequency band guidelines
    final bandSpacing = size.height * 0.16;
    final startY = size.height * 0.18;

    for (int i = 0; i < _freqLabels.length; i++) {
      final y = startY + (i * bandSpacing);

      linePaint.color =
          i ==
              2 // Nyquist Limit
          ? AppColors.burntOrange.withValues(alpha: 0.35 * opacity)
          : (isDark ? AppColors.darkBorder : AppColors.warmStone).withValues(
              alpha: 0.3 * opacity,
            );

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

      // Label at right edge
      final textPainter = TextPainter(
        text: TextSpan(text: _freqLabels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 12, y - 11),
      );
    }

    // Oscillating vertical spectral FFT bars in the background
    const barCount = 18;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + (barWidth * 0.2);
      final phase = (progress * 2 * math.pi) + (i * 0.45);
      final harmonic = math.sin(phase) * 0.5 + 0.5;

      // Ultrasonic focus around bars 10-14 (leak signature frequencies)
      final isUltrasonic = i >= 9 && i <= 14;
      final maxBarHeight = size.height * (isUltrasonic ? 0.35 : 0.22);
      final barHeight = maxBarHeight * (0.3 + 0.7 * harmonic);

      barPaint.color = isUltrasonic
          ? AppColors.burntOrange.withValues(
              alpha: (0.08 + 0.08 * harmonic) * opacity,
            )
          : (isDark ? AppColors.darkSurfaceElevated : AppColors.warmStone)
                .withValues(alpha: 0.12 * opacity);

      final rect = Rect.fromLTWH(
        x,
        startY + (4 * bandSpacing) - barHeight,
        barWidth * 0.6,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectralMatrixPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
