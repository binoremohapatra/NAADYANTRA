import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AcousticHeroWidget — home screen focal point
//
// Shows a premium, animated multi-layer acoustic waveform.
// - When [isLive] is true: waveform oscillates (real session active)
// - When [isLive] is false: waveform is in calm idle state
// - [rmsValue]: normalized 0.0–1.0 RMS value drives amplitude; null = no data
// - [dataLabel]: optional label shown below (e.g. "1240 ADC RMS")
// - [statusLabel]: e.g. "MONITORING ACTIVE" or "AWAITING SESSION"
// ──────────────────────────────────────────────────────────────────────────────

class AcousticHeroWidget extends StatefulWidget {
  final bool isLive;
  final double? rmsValue; // 0.0 – 1.0 normalized
  final String? dataLabel;
  final String statusLabel;
  final Color? accentColor;

  const AcousticHeroWidget({
    super.key,
    required this.isLive,
    this.rmsValue,
    this.dataLabel,
    required this.statusLabel,
    this.accentColor,
  });

  @override
  State<AcousticHeroWidget> createState() => _AcousticHeroWidgetState();
}

class _AcousticHeroWidgetState extends State<AcousticHeroWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    if (widget.isLive && !MotionTokens.isReducedMotion(context)) {
      _controller.repeat();
    } else {
      // Idle: animate very slowly
      _controller.animateTo(0.5, duration: const Duration(seconds: 2));
    }
  }

  @override
  void didUpdateWidget(covariant AcousticHeroWidget old) {
    super.didUpdateWidget(old);
    final isReduced = MotionTokens.isReducedMotion(context);

    if (widget.isLive && !isReduced) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
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
    final accent = widget.accentColor ?? AppColors.burntOrange;
    final amplitude = widget.rmsValue ?? (widget.isLive ? 0.55 : 0.22);

    return RepaintBoundary(
      child: Column(
        children: [
          // ── Waveform canvas ──
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AcousticHeroPainter(
                    phase: _controller.value,
                    amplitude: amplitude,
                    isLive: widget.isLive,
                    isDark: isDark,
                    accent: accent,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Status row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing indicator
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final pulse = widget.isLive
                      ? 0.5 +
                          0.5 *
                              math.sin(_controller.value * math.pi * 2)
                      : 0.4;
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.isLive
                          ? accent.withValues(alpha: pulse)
                          : AppColors.warmGraphite.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                widget.statusLabel,
                style: AppTypography.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.isLive ? accent : AppColors.warmGraphite,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // ── RMS readout ──
          if (widget.dataLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.dataLabel!,
              style: AppTypography.mono(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.carbon,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CustomPainter — 3-layer sinusoidal waveform
// ──────────────────────────────────────────────────────────────────────────────

class _AcousticHeroPainter extends CustomPainter {
  final double phase;
  final double amplitude; // 0.0 – 1.0 (normalized)
  final bool isLive;
  final bool isDark;
  final Color accent;

  const _AcousticHeroPainter({
    required this.phase,
    required this.amplitude,
    required this.isLive,
    required this.isDark,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.5;
    final maxAmp = size.height * 0.38 * amplitude.clamp(0.05, 1.0);

    _drawWave(
      canvas,
      size,
      cy: cy,
      amplitude: maxAmp,
      frequency: 2.5,
      phaseOffset: 0,
      color: accent,
      strokeWidth: 2.0,
      opacity: isLive ? 0.9 : 0.45,
    );

    _drawWave(
      canvas,
      size,
      cy: cy,
      amplitude: maxAmp * 0.55,
      frequency: 4.2,
      phaseOffset: math.pi * 0.6,
      color: isDark ? AppColors.darkTextSecondary : AppColors.softSand,
      strokeWidth: 1.2,
      opacity: isLive ? 0.55 : 0.3,
    );

    _drawWave(
      canvas,
      size,
      cy: cy,
      amplitude: maxAmp * 0.28,
      frequency: 7.0,
      phaseOffset: math.pi * 1.2,
      color: isDark ? AppColors.darkBorder : AppColors.warmStone,
      strokeWidth: 0.8,
      opacity: isLive ? 0.4 : 0.2,
    );

    // Center horizontal baseline
    final baselinePaint = Paint()
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      baselinePaint,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double cy,
    required double amplitude,
    required double frequency,
    required double phaseOffset,
    required Color color,
    required double strokeWidth,
    required double opacity,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const steps = 120;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final y = cy +
          math.sin(
                  t * frequency * math.pi * 2 +
                      phase * math.pi * 2 +
                      phaseOffset) *
              amplitude *
              _envelopeDampen(t);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// Taper the waveform at left/right edges for a clean, editorial look.
  double _envelopeDampen(double t) {
    const edge = 0.06;
    if (t < edge) return t / edge;
    if (t > 1 - edge) return (1 - t) / edge;
    return 1.0;
  }

  @override
  bool shouldRepaint(_AcousticHeroPainter old) =>
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.isLive != isLive ||
      old.isDark != isDark;
}
