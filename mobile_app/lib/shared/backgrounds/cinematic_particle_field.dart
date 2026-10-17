import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// CinematicParticleField
///
/// Full-screen premium animated background with:
/// - Floating glowing particles drifting upward (burnt orange + warm graphite)
/// - Radial ambient glow pulse centered on screen
/// - Horizontal acoustic scan lines drifting slowly
/// - Subtle grid of measurement tick marks
///
/// Designed as the NAADYANTRA global app background.
class CinematicParticleField extends StatefulWidget {
  final Widget? child;
  final double opacity;

  const CinematicParticleField({super.key, this.child, this.opacity = 1.0});

  @override
  State<CinematicParticleField> createState() => _CinematicParticleFieldState();
}

class _CinematicParticleFieldState extends State<CinematicParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _random = math.Random(42); // Fixed seed for consistency

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Generate 28 particles with deterministic positions
    _particles = List.generate(28, (i) => _Particle.random(_random, i));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReduced = MotionTokens.isReducedMotion(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isReduced) {
      return widget.child != null ? widget.child! : const SizedBox.expand();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CinematicPainter(
              t: _controller.value,
              particles: _particles,
              isDark: isDark,
              opacity: widget.opacity,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _Particle {
  final double xFraction; // 0..1 horizontal starting position
  final double yStart; // 0..1 vertical start (bottom)
  final double size; // radius in logical pixels
  final double speed; // 0..1 drift speed multiplier
  final double phase; // animation phase offset 0..1
  final double swayAmp; // horizontal sway amplitude
  final double swayFreq; // sway oscillation frequency
  final bool isOrange; // burnt orange vs soft graphite

  const _Particle({
    required this.xFraction,
    required this.yStart,
    required this.size,
    required this.speed,
    required this.phase,
    required this.swayAmp,
    required this.swayFreq,
    required this.isOrange,
  });

  factory _Particle.random(math.Random rng, int index) {
    return _Particle(
      xFraction: rng.nextDouble(),
      yStart: rng.nextDouble(),
      size: 1.5 + rng.nextDouble() * 4.5,
      speed: 0.08 + rng.nextDouble() * 0.18,
      phase: rng.nextDouble(),
      swayAmp: 4.0 + rng.nextDouble() * 20.0,
      swayFreq: 0.5 + rng.nextDouble() * 2.0,
      isOrange: index % 5 == 0 || index % 7 == 0,
    );
  }
}

class _CinematicPainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;
  final bool isDark;
  final double opacity;

  _CinematicPainter({
    required this.t,
    required this.particles,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawAmbientGlow(canvas, size);
    _drawScanLines(canvas, size);
    _drawParticles(canvas, size);
  }

  void _drawAmbientGlow(Canvas canvas, Size size) {
    // Soft radial glow that breathes slowly
    final pulseT = (math.sin(t * 2 * math.pi) * 0.5 + 0.5); // 0..1
    final glowRadius = size.width * (0.55 + pulseT * 0.12);
    final center = Offset(size.width * 0.5, size.height * 0.35);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.burntOrange.withValues(
            alpha: (isDark ? 0.07 : 0.045) * opacity * (0.8 + pulseT * 0.4),
          ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, paint);

    // Second glow at bottom (warm accent)
    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.darkBurntOrange.withValues(
                alpha: (isDark ? 0.05 : 0.03) * opacity,
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.2, size.height * 0.85),
              radius: size.width * 0.5,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.85),
      size.width * 0.5,
      paint2,
    );
  }

  void _drawScanLines(Canvas canvas, Size size) {
    // Two slow-drifting horizontal scan lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int i = 0; i < 2; i++) {
      final yFraction = ((t * 0.4 + i * 0.5) % 1.0);
      final y = yFraction * size.height;

      // Fade near edges
      final fade = math.sin(yFraction * math.pi);

      linePaint.color = AppColors.burntOrange.withValues(
        alpha: 0.12 * fade * opacity,
      );

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Vertical measurement ticks every ~60px
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.35 * opacity);

    final tickSpacing = 60.0;
    final cols = (size.width / tickSpacing).ceil();
    for (int c = 0; c <= cols; c++) {
      final x = c * tickSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), tickPaint);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in particles) {
      // Compute current y: particle drifts upward from yStart
      final cycleT = ((t * p.speed + p.phase) % 1.0);
      final y = size.height * (1.0 - cycleT);

      // Sway horizontally with a sine function
      final x =
          size.width * p.xFraction +
          math.sin(cycleT * p.swayFreq * 2 * math.pi) * p.swayAmp;

      // Fade in/out: bright in middle of journey, invisible at endpoints
      final lifeFade = math.sin(cycleT * math.pi).clamp(0.0, 1.0);

      final baseColor = p.isOrange
          ? AppColors.burntOrange
          : AppColors.warmGraphite;
      final alpha = (isDark ? 0.55 : 0.30) * lifeFade * opacity;

      // Glow halo
      final haloPaint = Paint()
        ..color = baseColor.withValues(alpha: alpha * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), p.size * 2.0, haloPaint);

      // Solid core
      final corePaint = Paint()..color = baseColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), p.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CinematicPainter old) {
    return old.t != t || old.isDark != isDark || old.opacity != opacity;
  }
}
