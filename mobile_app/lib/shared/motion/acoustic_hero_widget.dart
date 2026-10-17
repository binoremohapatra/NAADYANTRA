import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AcousticHeroWidget — home screen signature acoustic monitoring experience
//
// Shows a precision, multi-layer acoustic waveform on a technical datum grid.
// - When [isLive] is true: waveform oscillates dynamically (live streaming session)
// - When [isLive] is false: calm idle state with steady datum baseline
// - [rmsValue]: normalized 0.0–1.0 RMS value drives amplitude; null = baseline
// - [dataLabel]: e.g. "1240 ADC RMS"
// - [statusLabel]: e.g. "MONITORING ACTIVE" or "AWAITING SESSION"
// - [isInstrumentPanel]: renders an editorial charcoal studio instrument chassis
// ──────────────────────────────────────────────────────────────────────────────

class AcousticHeroWidget extends StatefulWidget {
  final bool isLive;
  final double? rmsValue; // 0.0 – 1.0 normalized
  final String? dataLabel;
  final String statusLabel;
  final Color? accentColor;
  final bool isInstrumentPanel;
  final String? deviceId;
  final String? freshnessLabel;

  const AcousticHeroWidget({
    super.key,
    required this.isLive,
    this.rmsValue,
    this.dataLabel,
    required this.statusLabel,
    this.accentColor,
    this.isInstrumentPanel = false,
    this.deviceId,
    this.freshnessLabel,
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
      duration: const Duration(milliseconds: 2800),
    );

    if (widget.isLive) {
      _controller.repeat();
    } else {
      _controller.animateTo(0.5, duration: const Duration(milliseconds: 800));
    }
  }

  @override
  void didUpdateWidget(covariant AcousticHeroWidget old) {
    super.didUpdateWidget(old);
    if (widget.isLive) {
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
    final isReduced = MotionTokens.isReducedMotion(context);
    final accent = widget.accentColor ?? AppColors.burntOrange;
    final amplitude = widget.rmsValue ?? (widget.isLive ? 0.55 : 0.22);

    Widget waveformCanvas = SizedBox(
      height: widget.isInstrumentPanel ? 136 : 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AcousticHeroPainter(
              phase: isReduced ? 0.5 : _controller.value,
              amplitude: amplitude,
              isLive: widget.isLive,
              isDark: isDark,
              accent: accent,
              showReticles: widget.isInstrumentPanel,
            ),
            size: Size.infinite,
          );
        },
      ),
    );

    if (!widget.isInstrumentPanel) {
      return RepaintBoundary(
        child: Column(
          children: [
            waveformCanvas,
            const SizedBox(height: 12),
            // Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final pulse = widget.isLive && !isReduced
                        ? 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2)
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
            if (widget.dataLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.dataLabel!,
                style: AppTypography.mono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ── Signature Industrial Precision Instrument Panel ──
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top telemetry header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.isLive
                            ? AppColors.burntOrange
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.warmGraphite),
                        shape: BoxShape.circle,
                        boxShadow: widget.isLive
                            ? [
                                BoxShadow(
                                  color: AppColors.burntOrange.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.deviceId != null && widget.deviceId!.isNotEmpty
                          ? widget.deviceId!
                          : 'NO NODE CONNECTED',
                      style: AppTypography.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.carbon,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isLive
                        ? AppColors.burntOrange.withValues(alpha: 0.12)
                        : (isDark
                              ? AppColors.darkCanvas
                              : AppColors.industrialIvory),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.isLive
                          ? AppColors.burntOrange.withValues(alpha: 0.35)
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.warmStone),
                    ),
                  ),
                  child: Text(
                    widget.freshnessLabel ??
                        (widget.isLive ? 'LIVE STREAM' : 'STANDBY'),
                    style: AppTypography.mono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: widget.isLive
                          ? AppColors.burntOrange
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.warmGraphite),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Oscilloscope Waveform Surface
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141517)
                    : const Color(0xFFF4F1EA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: waveformCanvas,
              ),
            ),

            const SizedBox(height: 12),

            // Measurement & Callout Row (Expanded column prevents right overflow)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.statusLabel,
                        style: AppTypography.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.isLive
                              ? AppColors.burntOrange
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.warmGraphite),
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.dataLabel ?? (widget.isLive ? 'ACTIVE' : '--'),
                        style: AppTypography.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.carbon,
                          letterSpacing: -0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF232527)
                        : const Color(0xFFF0ECE4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF323538)
                          : AppColors.warmStone,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ACOUSTIC BAND',
                        style: AppTypography.mono(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : AppColors.warmGraphite,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '0–2000 HZ · NYQUIST',
                        style: AppTypography.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.burntOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CustomPainter — multi-harmonic acoustic waveform on precision reticle grid
// ──────────────────────────────────────────────────────────────────────────────

class _AcousticHeroPainter extends CustomPainter {
  final double phase;
  final double amplitude; // 0.0 – 1.0 (normalized)
  final bool isLive;
  final bool isDark;
  final Color accent;
  final bool showReticles;

  const _AcousticHeroPainter({
    required this.phase,
    required this.amplitude,
    required this.isLive,
    required this.isDark,
    required this.accent,
    this.showReticles = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.5;
    final maxAmp = size.height * 0.40 * amplitude.clamp(0.06, 1.0);

    // Precision Studio Reticles & dB Grid lines
    if (showReticles) {
      final gridPaint = Paint()
        ..color = (isDark ? const Color(0xFF26282B) : AppColors.warmStone)
            .withValues(alpha: isDark ? 0.6 : 0.75)
        ..strokeWidth = 0.8;

      // Horizontal reference lines (+10dB, 0dB, -10dB)
      canvas.drawLine(
        Offset(0, cy - size.height * 0.28),
        Offset(size.width, cy - size.height * 0.28),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, cy + size.height * 0.28),
        Offset(size.width, cy + size.height * 0.28),
        gridPaint,
      );

      // Vertical sample dividers
      for (double x = 40; x < size.width; x += 40) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    // 1. Primary harmonic wave (Fundamental leak signature)
    _drawWave(
      canvas,
      size,
      cy: cy,
      amplitude: maxAmp,
      frequency: 2.8,
      phaseOffset: phase * math.pi * 2,
      color: accent,
      strokeWidth: 2.4,
      opacity: isLive ? 0.95 : 0.45,
    );

    // 2. Secondary harmonic wave (Resonant pipe mode)
    _drawWave(
      canvas,
      size,
      cy: cy,
      amplitude: maxAmp * 0.52,
      frequency: 4.8,
      phaseOffset: (phase * math.pi * 2) + (math.pi * 0.6),
      color: isDark ? const Color(0xFFD8C9BA) : AppColors.darkBurntOrange,
      strokeWidth: 1.4,
      opacity: isLive ? 0.65 : 0.35,
    );

    // 3. High-frequency turbulence ripple (Hiss & cavitations)
    _drawWave(
      canvas,
      size,
      cy: cy,
      amplitude: maxAmp * 0.25,
      frequency: 8.5,
      phaseOffset: (phase * math.pi * 2) + (math.pi * 1.3),
      color: isDark ? const Color(0xFF71757A) : AppColors.carbon,
      strokeWidth: 0.9,
      opacity: isLive ? 0.45 : 0.25,
    );

    // Center horizontal datum baseline
    final baselinePaint = Paint()
      ..color = (isDark ? const Color(0xFF383A3D) : AppColors.warmStone)
          .withValues(alpha: isDark ? 0.6 : 0.8)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), baselinePaint);
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
    const step = 2.0;
    bool first = true;

    for (double x = 0; x <= size.width; x += step) {
      final normalizedX = x / size.width;
      // Windowing envelope (Tukey/Hann) so waveform tapers cleanly at screen edges
      final window = math.sin(normalizedX * math.pi);
      final y =
          cy +
          math.sin((normalizedX * frequency * math.pi * 2) + phaseOffset) *
              amplitude *
              window;

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AcousticHeroPainter old) {
    return old.phase != phase ||
        old.amplitude != amplitude ||
        old.isLive != isLive ||
        old.accent != accent;
  }
}
