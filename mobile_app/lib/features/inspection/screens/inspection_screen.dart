import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/device.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/industrial_button.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/backgrounds/diagnostic_radar_sweep.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

// deviceStatusProvider and latestTelemetryProvider are in providers.dart.
// The local recentEventsProvider is preserved for the event-stream list
// at the bottom of the screen (shows last 10 events).
final recentEventsProvider = FutureProvider.autoDispose<List<Event>>((
  ref,
) async {
  final activeDeviceId = ref.watch(activeDeviceIdProvider);
  if (activeDeviceId == null || activeDeviceId.isEmpty) return const <Event>[];
  final repo = ref.watch(deviceRepositoryProvider);
  return await repo.getDeviceEvents(activeDeviceId, limit: 10);
});

// ─────────────────────────────────────────────
//  ARC GAUGE — RMS level (CustomPainter)
// ─────────────────────────────────────────────
class _ArcGaugePainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color arcColor;
  final Color trackColor;
  static const double thresholdProgress = 400.0 / 4096.0;

  _ArcGaugePainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final radius = math.min(size.width * 0.38, cy - 12);

    // Symmetric sweep: 230 degrees centered at 270 deg (top apex)
    const startAngle = math.pi * 0.86;
    const sweepMax = math.pi * 1.28;

    // 1. Dial scale graduation tick marks
    final tickTrackColor = trackColor.withValues(alpha: 0.55);
    final tickPaint = Paint()
      ..color = tickTrackColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = tickTrackColor.withValues(alpha: 0.95)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    const int totalTicks = 24;
    for (int i = 0; i <= totalTicks; i++) {
      final tickAngle = startAngle + (sweepMax * (i / totalTicks));
      final bool isMajor = (i % 6 == 0);
      final tickInnerR = radius + (isMajor ? 7.0 : 11.0);
      final tickOuterR = radius + 15.0;

      final p1 = Offset(
        cx + tickInnerR * math.cos(tickAngle),
        cy + tickInnerR * math.sin(tickAngle),
      );
      final p2 = Offset(
        cx + tickOuterR * math.cos(tickAngle),
        cy + tickOuterR * math.sin(tickAngle),
      );
      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
    }

    // Threshold indicator pip on ticks ring (at 400 ADC)
    final threshAngle =
        startAngle + sweepMax * thresholdProgress.clamp(0.0, 1.0);
    final thPip1 = Offset(
      cx + (radius + 5.0) * math.cos(threshAngle),
      cy + (radius + 5.0) * math.sin(threshAngle),
    );
    final thPip2 = Offset(
      cx + (radius + 18.0) * math.cos(threshAngle),
      cy + (radius + 18.0) * math.sin(threshAngle),
    );
    canvas.drawLine(
      thPip1,
      thPip2,
      Paint()
        ..color = AppColors.darkBurntOrange
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // 2. Base track (smooth, rounded)
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepMax,
      false,
      trackPaint,
    );

    // 3. Active Arc Fill
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepMax * progress.clamp(0.0, 1.0),
        false,
        fillPaint,
      );

      // Glow effect and bead on the active tip
      final tipAngle = startAngle + sweepMax * progress.clamp(0.0, 1.0);
      final tipX = cx + radius * math.cos(tipAngle);
      final tipY = cy + radius * math.sin(tipAngle);

      // Outer bloom glow
      canvas.drawCircle(
        Offset(tipX, tipY),
        10,
        Paint()
          ..color = arcColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      // Bright core bead
      canvas.drawCircle(
        Offset(tipX, tipY),
        4.0,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawCircle(Offset(tipX, tipY), 2.2, Paint()..color = arcColor);
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}

// ─────────────────────────────────────────────
//  SPARKLINE — RMS history (CustomPainter)
// ─────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  final List<double> values; // ordered oldest → newest
  final Color lineColor;

  _SparklinePainter({required this.values, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, double.infinity);

    double xStep = size.width / (values.length - 1);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * xStep;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient fill under line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot on latest value
    final lastX = (values.length - 1) * xStep;
    final lastY = size.height - ((values.last - minV) / range) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = lineColor);
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()
        ..color = lineColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

// ─────────────────────────────────────────────
//  ANIMATED ARC GAUGE WIDGET
// ─────────────────────────────────────────────
class _AnimatedArcGauge extends StatefulWidget {
  final double value; // raw value (e.g. RMS 0–4095)
  final double maxValue;
  final String label;
  final String unit;
  final Color color;

  const _AnimatedArcGauge({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.unit,
    required this.color,
  });

  @override
  State<_AnimatedArcGauge> createState() => _AnimatedArcGaugeState();
}

class _AnimatedArcGaugeState extends State<_AnimatedArcGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.value / widget.maxValue,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedArcGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.value / widget.maxValue,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: SizedBox(
        height: 135,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, _) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArcGaugePainter(
                    progress: _anim.value,
                    arcColor: widget.color,
                    trackColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.warmStone,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.value > 0 ? widget.value.toStringAsFixed(0) : '--',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: widget.color,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.warmStone.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.warmStone,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${widget.unit} · RMS AMPLITUDE',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warmGraphite,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  OSCILLOSCOPE STANDBY VIEW & GRID
// ─────────────────────────────────────────────
class _OscilloscopeStandbyView extends StatelessWidget {
  final bool isDark;

  const _OscilloscopeStandbyView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.industrialIvory,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 0.8,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 52),
            painter: _OscilloscopeGridPainter(isDark: isDark),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulsingBeacon(size: 6, color: AppColors.burntOrange),
              const SizedBox(width: 8),
              Text(
                'BUFFER PRIMED · AWAITING 2+ TELEMETRY SAMPLES',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.softSand : AppColors.warmGraphite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OscilloscopeGridPainter extends CustomPainter {
  final bool isDark;

  _OscilloscopeGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.45)
      ..strokeWidth = 0.6;

    // Horizontal grid lines
    const int hDivs = 4;
    for (int i = 1; i < hDivs; i++) {
      final y = size.height * (i / hDivs);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines
    const int vDivs = 8;
    for (int i = 1; i < vDivs; i++) {
      final x = size.width * (i / vDivs);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_OscilloscopeGridPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────
//  ANIMATED LEAK RING WIDGET
// ─────────────────────────────────────────────
class _LeakRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _LeakRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );

      // glow
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_LeakRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _AnimatedLeakRing extends StatefulWidget {
  final double? leakProbability; // 0.0 – 1.0 or null
  const _AnimatedLeakRing({this.leakProbability});

  @override
  State<_AnimatedLeakRing> createState() => _AnimatedLeakRingState();
}

class _AnimatedLeakRingState extends State<_AnimatedLeakRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.leakProbability ?? 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedLeakRing old) {
    super.didUpdateWidget(old);
    if (old.leakProbability != widget.leakProbability) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.leakProbability ?? 0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = widget.leakProbability;
    final isCritical = pct != null && pct > 0.6;
    final ringColor = pct == null
        ? AppColors.warmGraphite
        : (isCritical ? AppColors.alertDanger : AppColors.alertOk);

    return RepaintBoundary(
      child: SizedBox(
        width: 110,
        height: 110,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, _) => Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(110, 110),
                painter: _LeakRingPainter(
                  progress: _anim.value,
                  color: ringColor,
                  trackColor: isDark
                      ? AppColors.darkBorder
                      : AppColors.warmStone,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pct != null ? '${(pct * 100).toInt()}%' : '--',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: ringColor,
                    ),
                  ),
                  Text(
                    'LEAK',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmGraphite,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED GAS BAR WIDGET
// ─────────────────────────────────────────────
class _AnimatedGasBar extends StatefulWidget {
  final int? gasDelta;
  const _AnimatedGasBar({this.gasDelta});

  @override
  State<_AnimatedGasBar> createState() => _AnimatedGasBarState();
}

class _AnimatedGasBarState extends State<_AnimatedGasBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  double _target() => ((widget.gasDelta ?? 0).abs() / 600.0).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = Tween<double>(
      begin: 0,
      end: _target(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedGasBar old) {
    super.didUpdateWidget(old);
    if (old.gasDelta != widget.gasDelta) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: _target(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final delta = widget.gasDelta;
    final isElevated = delta != null && delta.abs() > 100;
    final barColor = isElevated ? AppColors.burntOrange : AppColors.alertOk;
    final label = delta != null ? (delta >= 0 ? '+$delta' : '$delta') : '--';

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.air_rounded,
                    size: 14,
                    color: AppColors.burntOrange,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'GAS DELTA (MQ)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.warmGraphite,
                    ),
                  ),
                ],
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: barColor,
                ),
                child: Text(label),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 14,
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                ),
                FractionallySizedBox(
                  widthFactor: _anim.value,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor.withValues(alpha: 0.7), barColor],
                      ),
                    ),
                  ),
                ),
                // Threshold marker at 100/600 ≈ 16.7%
                Positioned(
                  left: MediaQuery.sizeOf(context).width * 0.167 - 50,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1.5,
                    color: AppColors.warmGraphite.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Baseline threshold: ±100 ADC',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.warmGraphite,
                ),
              ),
              Text(
                isElevated ? '⚠ ELEVATED' : '● NOMINAL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class InspectionScreen extends ConsumerStatefulWidget {
  const InspectionScreen({super.key});

  @override
  ConsumerState<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends ConsumerState<InspectionScreen> {
  Timer? _pollingTimer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    if (!_isPolling) {
      _isPolling = true;
      _pollingTimer = Timer.periodic(
        AppConfig.liveInspectionPollInterval,
        (_) => _refreshData(),
      );
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  bool _isSimulating = false;

  Future<void> _simulateTelemetry({required bool isLeak}) async {
    if (_isSimulating) return;
    setState(() => _isSimulating = true);

    final deviceId = ref.read(activeDeviceIdProvider);
    if (deviceId == null || deviceId.isEmpty) {
      if (mounted) {
        setState(() => _isSimulating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No hardware node selected for test simulation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final repo = ref.read(deviceRepositoryProvider);
    final baseUrl = ref.read(backendUrlProvider).valueOrNull ?? '';

    // DATA INTEGRITY GUARD:
    // Prevent synthetic lab test frames from polluting the live production cloud database.
    if (baseUrl.contains('onrender.com')) {
      if (mounted) {
        setState(() => _isSimulating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🛡️ Production Guard: Cloud database protected against synthetic frames. Connect to local test bench to inject frames.',
            ),
            backgroundColor: AppColors.carbon,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final rms = isLeak ? 1860.0 : 310.0;
    final gas = isLeak ? 465 : 42;
    final leak = isLeak ? 0.92 : 0.04;
    // Firmware valid values: OK | CAUTION | DANGER
    final alert = isLeak ? 'DANGER' : 'OK';
    final temp = isLeak ? 36.8 : 27.2;

    final success = await repo.sendTelemetryLog(
      deviceId: deviceId,
      rms: rms,
      gas: gas,
      leak: leak,
      alert: alert,
      temp: temp,
      session: 999999,
      trainee: 'TR-SIM-DEMO',
    );

    if (mounted) {
      setState(() => _isSimulating = false);
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isLeak
                      ? '⚠️ Ultrasonic Leak Frame Synced to Local Rig'
                      : '✅ Nominal Baseline Frame Synced to Local Rig')
                : 'Telemetry broadcast buffered locally',
          ),
          backgroundColor: isLeak
              ? AppColors.darkBurntOrange
              : AppColors.carbon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      ref.invalidate(deviceStatusProvider);
      ref.invalidate(recentEventsProvider);
      ref.invalidate(latestTelemetryProvider);
    }
  }

  // Show a simple dialog to pick which device to inspect.
  Future<void> _showDevicePicker(BuildContext ctx) async {
    final devices = ref.read(devicesProvider).valueOrNull?.items ?? [];
    if (!ctx.mounted) return;
    final chosen = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select Device'),
        content: devices.isEmpty
            ? const Text('No registered devices found.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (_, i) {
                    final d = devices[i];
                    return ListTile(
                      leading: Icon(
                        Icons.sensors,
                        color: d.isActive
                            ? AppColors.burntOrange
                            : AppColors.warmGraphite,
                      ),
                      title: Text(d.deviceId),
                      subtitle: Text(d.name ?? ''),
                      trailing: d.isActive
                          ? const StatusPill(
                              label: 'ACTIVE',
                              type: StatusType.active,
                            )
                          : null,
                      onTap: () => Navigator.pop(dialogCtx, d.deviceId),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (chosen != null) {
      ref.read(selectedDeviceIdProvider.notifier).state = chosen;
      _refreshData();
    }
  }

  // Show bottom sheet to configure the backend URL.
  void _showBackendSettings(BuildContext ctx) {
    final currentUrl =
        ref.read(backendUrlProvider).valueOrNull ?? AppConfig.defaultApiBaseUrl;
    final controller = TextEditingController(text: currentUrl);
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BACKEND URL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.warmGraphite,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cloud: https://naadyantra.onrender.com\n'
              'Emulator: http://10.0.2.2:8000\n'
              'Physical device: http://<LAN_IP>:8000',
              style: TextStyle(fontSize: 11, color: AppColors.warmGraphite),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://192.168.x.x:8000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(backendUrlProvider.notifier).resetToDefault();
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Reset to Cloud'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final url = controller.text.trim();
                      if (url.isNotEmpty) {
                        ref.read(backendUrlProvider.notifier).setUrl(url);
                        _refreshData();
                      }
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDeviceId = ref.watch(activeDeviceIdProvider);
    final deviceStatus = ref.watch(deviceStatusProvider);
    final recentEvents = ref.watch(recentEventsProvider);
    final latestTelAsync = ref.watch(latestTelemetryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Derive live reading from the new latestTelemetryProvider.
    final latestTel = latestTelAsync.valueOrNull;
    final latest = latestTel?.event;
    final isStale = latestTel?.isStale ?? true;
    final stalenessLabel = latestTel?.stalenessLabel ?? 'no data';

    // Sparkline history still comes from the event list (last 10).
    final events = recentEvents.valueOrNull ?? [];
    final rmsHistory = events
        .where((e) => e.rms != null)
        .map((e) => e.rms!)
        .toList()
        .reversed
        .toList();

    final isLeakCritical =
        latest?.leakProbability != null && latest!.leakProbability! > 0.6;

    // No device selected — show picker prompt instead of the full screen.
    if (selectedDeviceId == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Row(
            children: [
              PulsingBeacon(size: 8, color: AppColors.burntOrange),
              SizedBox(width: 8),
              Text(
                'LIVE DIAGNOSTIC PROBE',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sensors_off_rounded,
                  size: 48,
                  color: AppColors.softSand,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No device selected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pureWhite,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select a registered ESP32 node to begin live inspection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtleGray),
                ),
                const SizedBox(height: 24),
                IndustrialButton(
                  label: 'Select Device',
                  icon: Icons.sensors_rounded,
                  onPressed: () => _showDevicePicker(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            PulsingBeacon(
              size: 8,
              color: (latestTel?.isLive ?? false)
                  ? AppColors.alertOk
                  : AppColors.burntOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedDeviceId,
                style: AppTypography.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.pureWhite : AppColors.carbon,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Stale badge — shown in AppBar when data is stale
          if (isStale && latestTel?.hasData == true)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkBurntOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.burntOrange,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'STALE · $stalenessLabel',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.burntOrange,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.sensors_rounded,
              color: isDark ? AppColors.softSand : AppColors.warmGraphite,
            ),
            tooltip: 'Change device',
            onPressed: () => _showDevicePicker(context),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_ethernet_rounded,
              color: isDark ? AppColors.softSand : AppColors.warmGraphite,
            ),
            tooltip: 'Backend URL',
            onPressed: () => _showBackendSettings(context),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.softSand : AppColors.warmGraphite,
            ),
            tooltip: 'Sync Probes',
            onPressed: _refreshData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.inspection,
        lightScrimOpacity: 0.58,
        darkScrimOpacity: 0.50,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Live Status Banner ──────────────────────────
              StaggeredEntrance(
                index: 0,
                child: _buildStatusBanner(isDark, deviceStatus),
              ),
              const SizedBox(height: 12),

              // ── Error state (combined — show once) ────────────
              if (recentEvents.hasError || deviceStatus.hasError)
                StaggeredEntrance(
                  index: 1,
                  child: _buildErrorCard(
                    recentEvents.error ?? deviceStatus.error!,
                    isDark,
                  ),
                ),

              // ── Device header ────────────────────────────────
              deviceStatus.when(
                data: (status) => StaggeredEntrance(
                  index: 1,
                  child: _buildNodeHeaderCard(status, isDark),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // ── RMS Arc Gauge + Sparkline ─────────────────────
              StaggeredEntrance(
                index: 2,
                child: _buildRmsSection(context, latest, rmsHistory, isDark),
              ),
              const SizedBox(height: 12),

              // ── Leak Ring + Gas Bar + Sensor Chips ───────────
              StaggeredEntrance(
                index: 3,
                child: _buildHazardSection(
                  context,
                  latest,
                  isLeakCritical,
                  isDark,
                ),
              ),
              const SizedBox(height: 12),

              // ── TEST BENCH Simulator (DEBUG ONLY) ─────────────
              if (kDebugMode)
                StaggeredEntrance(
                  index: 4,
                  child: _buildSimulatorCard(context, isDark),
                ),
              if (kDebugMode) const SizedBox(height: 12),

              // ── Live Event Stream ────────────────────────────
              StaggeredEntrance(
                index: 5,
                child: _buildRecentEventsCard(context, recentEvents, isDark),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── STATUS BANNER ─────────────────────────────────────────────────────────
  Widget _buildStatusBanner(bool isDark, AsyncValue<DeviceStatus> status) {
    final isOnline = status.valueOrNull?.isOnline ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
        ),
      ),
      child: Row(
        children: [
          PulsingBeacon(
            size: 8,
            color: isOnline ? AppColors.alertOk : AppColors.warmGraphite,
          ),
          const SizedBox(width: 8),
          StatusPill(
            label: 'LIVE STREAM',
            type: isOnline ? StatusType.active : StatusType.neutral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Polling every ${AppConfig.liveInspectionPollInterval.inSeconds}s · ADC1_CH4 · IIR DC-block',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.warmGraphite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.sensors_rounded,
            size: 16,
            color: AppColors.burntOrange,
          ),
        ],
      ),
    );
  }

  // ── ERROR CARD ─────────────────────────────────────────────────────────────
  Widget _buildErrorCard(Object error, bool isDark) {
    return IndustrialCard(
      borderColor: AppColors.alertDanger,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.alertDanger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to reach telemetry probe: $error',
              style: const TextStyle(
                color: AppColors.alertDanger,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }

  // ── NODE HEADER ────────────────────────────────────────────────────────────
  Widget _buildNodeHeaderCard(DeviceStatus status, bool isDark) {
    return IndustrialCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              DiagnosticRadarSweep(size: 48, isScanning: status.isOnline),
              Icon(
                status.isOnline
                    ? Icons.wifi_tethering_rounded
                    : Icons.portable_wifi_off_rounded,
                color: status.isOnline
                    ? AppColors.alertOk
                    : AppColors.warmGraphite,
                size: 20,
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NODE: ${status.deviceId}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  status.isOnline
                      ? 'Receiving acoustic telemetry packets'
                      : 'Awaiting device handshake',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warmGraphite,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: status.isOnline ? 'ONLINE' : 'OFFLINE',
                type: status.isOnline ? StatusType.online : StatusType.offline,
              ),
              const SizedBox(height: 4),
              Text(
                status.lastSeenAt != null
                    ? 'Last: ${DateFormat("HH:mm:ss").format(status.lastSeenAt!)}'
                    : 'No ping yet',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.warmGraphite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── RMS GAUGE + SPARKLINE ──────────────────────────────────────────────────
  Widget _buildRmsSection(
    BuildContext context,
    Event? latest,
    List<double> rmsHistory,
    bool isDark,
  ) {
    final rms = latest?.rms ?? 0.0;
    final isCritical = rms > 400;

    return IndustrialCard(
      title: 'ACOUSTIC RMS TRANSDUCER',
      subtitle: '12-bit ADC · Piezo Contact Transducer · ADC1_CH4',
      trailing: StatusPill(
        label: rms == 0
            ? 'AWAITING'
            : (isCritical ? 'ANOMALY DETECTED' : 'NOMINAL BASELINE'),
        type: rms == 0
            ? StatusType.neutral
            : (isCritical ? StatusType.danger : StatusType.ok),
      ),
      child: Column(
        children: [
          // Precision Arc Gauge
          _AnimatedArcGauge(
            value: rms,
            maxValue: 4096,
            label: 'RMS',
            unit: 'ADC',
            color: isCritical ? AppColors.alertDanger : AppColors.burntOrange,
          ),

          const SizedBox(height: 6),

          // Industrial Calibration Scale Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.industrialIvory,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '0 ADC\nBASELINE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warmGraphite,
                        height: 1.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCritical
                            ? AppColors.alertDanger.withValues(alpha: 0.12)
                            : AppColors.burntOrange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCritical
                              ? AppColors.alertDanger
                              : AppColors.burntOrange,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCritical
                                ? Icons.warning_rounded
                                : Icons.tune_rounded,
                            size: 11,
                            color: isCritical
                                ? AppColors.alertDanger
                                : AppColors.burntOrange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LEAK TRIGGER ≥ 400 ADC',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: isCritical
                                  ? AppColors.alertDanger
                                  : AppColors.burntOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      '4095 ADC\n12-BIT FS',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warmGraphite,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // Calibration Scale Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.warmStone,
                        ),
                        // Safe zone
                        FractionallySizedBox(
                          widthFactor: (400.0 / 4096.0).clamp(0.0, 1.0),
                          child: Container(
                            color: AppColors.alertOk.withValues(alpha: 0.5),
                          ),
                        ),
                        // Current fill
                        if (rms > 0)
                          FractionallySizedBox(
                            widthFactor: (rms / 4096.0).clamp(0.0, 1.0),
                            child: Container(
                              color: isCritical
                                  ? AppColors.alertDanger
                                  : AppColors.burntOrange,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sparkline history or Oscilloscope Standby
          if (rmsHistory.length >= 2) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RMS BUFFER (LAST 10 EVENTS)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.warmGraphite,
                  ),
                ),
                StatusPill(
                  label: '${rms.toStringAsFixed(0)} ADC PEAK',
                  type: isCritical ? StatusType.danger : StatusType.active,
                ),
              ],
            ),
            const SizedBox(height: 6),
            RepaintBoundary(
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: rmsHistory,
                    lineColor: isCritical
                        ? AppColors.alertDanger
                        : AppColors.burntOrange,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ] else ...[
            _OscilloscopeStandbyView(isDark: isDark),
          ],

          const SizedBox(height: 12),

          // Hardware specifications telemetry chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildHardwareSpecChip('ADC', '12-bit ADC1_CH4', isDark),
              _buildHardwareSpecChip('FILTER', 'IIR DC-block R=0.995', isDark),
              _buildHardwareSpecChip('ISR', 'FreeRTOS 1024-smp', isDark),
              _buildHardwareSpecChip('HOP', '50% hop', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSpecChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.industrialIvory,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.warmGraphite,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: isDark ? AppColors.pureWhite : AppColors.carbon,
            ),
          ),
        ],
      ),
    );
  }

  // ── HAZARD MATRIX ──────────────────────────────────────────────────────────
  Widget _buildHazardSection(
    BuildContext context,
    Event? latest,
    bool isLeakCritical,
    bool isDark,
  ) {
    return IndustrialCard(
      title: 'HAZARD MATRIX',
      subtitle: 'Leak · Gas · Thermal · Moisture · UV',
      trailing: StatusPill(
        label: latest == null
            ? 'AWAITING'
            : (isLeakCritical ? 'ANOMALY DETECTED' : 'NOMINAL BASELINE'),
        type: latest == null
            ? StatusType.neutral
            : (isLeakCritical ? StatusType.danger : StatusType.ok),
      ),
      child: Column(
        children: [
          // Leak ring + side sensor chips
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leak Ring
              Column(
                children: [
                  _AnimatedLeakRing(leakProbability: latest?.leakProbability),
                  const SizedBox(height: 4),
                  Text(
                    latest?.modelLabel ?? 'ONNX MODEL',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmGraphite,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Sensor status chips
              Expanded(
                child: Column(
                  children: [
                    _buildSensorChip(
                      icon: Icons.thermostat_rounded,
                      label: 'TEMP',
                      value: latest?.temperature != null
                          ? '${latest!.temperature!.toStringAsFixed(1)}°C'
                          : 'DISABLED',
                      isActive: latest?.hasTemperatureData ?? false,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildSensorChip(
                      icon: Icons.water_drop_outlined,
                      label: 'WET',
                      value: latest?.wet == null
                          ? 'DISABLED'
                          : (latest!.wet! ? 'DETECTED' : 'DRY'),
                      isActive: latest?.wet == true,
                      isDark: isDark,
                      dangerWhenActive: true,
                    ),
                    const SizedBox(height: 8),
                    _buildSensorChip(
                      icon: Icons.wb_sunny_outlined,
                      label: 'UV Δ',
                      value: latest?.uvDelta != null
                          ? '${latest!.uvDelta! >= 0 ? "+" : ""}${latest.uvDelta}'
                          : 'DISABLED',
                      isActive: latest?.hasUvData ?? false,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildSensorChip(
                      icon: Icons.memory_rounded,
                      label: 'UPTIME',
                      value: latest?.deviceUptimeMs != null
                          ? '${(latest!.deviceUptimeMs! / 1000).toStringAsFixed(0)}s'
                          : '--',
                      isActive: latest?.deviceUptimeMs != null,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.warmStone),
          const SizedBox(height: 12),

          // Animated Gas Bar
          _AnimatedGasBar(gasDelta: latest?.gasDelta),

          const SizedBox(height: 12),

          // Event label + cause
          if (latest != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLeakCritical
                    ? AppColors.alertDanger.withValues(alpha: 0.08)
                    : AppColors.alertOk.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLeakCritical
                      ? AppColors.alertDanger.withValues(alpha: 0.35)
                      : AppColors.alertOk.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLeakCritical
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: isLeakCritical
                        ? AppColors.alertDanger
                        : AppColors.alertOk,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latest.cause ??
                          (isLeakCritical
                              ? 'High acoustic resonance in 28–39 kHz window indicates active pipe orifice leak.'
                              : 'Acoustic background matches baseline laminar pipe flow profile.'),
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: isLeakCritical
                            ? AppColors.darkBurntOrange
                            : AppColors.warmGraphite,
                        fontWeight: isLeakCritical
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: latest.alert ?? 'NOMINAL',
                    type: _getStatusType(latest.alert),
                  ),
                ],
              ),
            )
          else
            const Text(
              'Awaiting first telemetry event from device.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warmGraphite,
                fontStyle: FontStyle.italic,
              ),
            ),

          // ── TinyML Hazard Fusion (hz / hz_c) ──────────────────────────
          if (latest != null && latest.hasHazardData) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.industrialIvory,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.memory_rounded,
                    size: 13,
                    color: AppColors.warmGraphite,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'TINYML HAZARD FUSION',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmGraphite,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  // Hazard state label
                  if (latest.hazardStateLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkBurntOrange.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.darkBurntOrange,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        latest.hazardStateLabel!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBurntOrange,
                          letterSpacing: 0.6,
                        ),
                      ),
                    )
                  else
                    const Text(
                      'NORMAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.alertOk,
                        letterSpacing: 0.6,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Confidence score — explicitly NOT labeled as probability
                  Text(
                    'CONF: ${latest.hazardConf ?? '--'}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.warmGraphite,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorChip({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    required bool isDark,
    bool dangerWhenActive = false,
  }) {
    final Color accent = dangerWhenActive && isActive
        ? AppColors.alertDanger
        : (isActive ? AppColors.burntOrange : AppColors.warmGraphite);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.industrialIvory,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.warmStone),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // ── SIMULATOR CARD ────────────────────────────────────────────────────────
  Widget _buildSimulatorCard(BuildContext context, bool isDark) {
    return IndustrialCard(
      title: '[TEST BENCH TOOL] Rig Simulation Broadcaster',
      subtitle: 'Isolated Synthetic Telemetry (Trainee: TR-SIM-DEMO)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.alertCaution.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.alertCaution.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.science_rounded,
                  size: 16,
                  color: AppColors.alertCaution,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TEST BENCH ISOLATION: Broadcasts synthetic frames tagged as trainee "TR-SIM-DEMO" on session 999999 to test API ingestion when physical ESP32 hardware is detached. Synthetic records are not valid for certified trainee assessments.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.warmGraphite,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSimulating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Broadcasting Synthetic Frame to Cloud...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.burntOrange,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IndustrialButton(
                  label: 'Broadcast Nominal Test Frame',
                  icon: Icons.check_circle_outline_rounded,
                  variant: IndustrialButtonVariant.secondary,
                  onPressed: () => _simulateTelemetry(isLeak: false),
                ),
                const SizedBox(height: 8),
                IndustrialButton(
                  label: 'Broadcast Leak Test Frame',
                  icon: Icons.warning_amber_rounded,
                  onPressed: () => _simulateTelemetry(isLeak: true),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── EVENTS STREAM ─────────────────────────────────────────────────────────
  Widget _buildRecentEventsCard(
    BuildContext context,
    AsyncValue<List<Event>> recentEventsAsync,
    bool isDark,
  ) {
    return IndustrialCard(
      title: 'Live Anomaly Stream',
      subtitle: 'Triggered Event Log from Acoustic Sensors',
      trailing: IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 18),
        onPressed: _refreshData,
      ),
      child: recentEventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 32,
                      color: AppColors.alertOk,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No Live Anomalies Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'RMS level remains within baseline calibration thresholds.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warmGraphite,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.take(10).length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventTile(context, event, isDark);
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => Text(
          'Failed to load events: $error',
          style: const TextStyle(color: AppColors.alertDanger, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildEventTile(BuildContext context, Event event, bool isDark) {
    final alertColor = _getAlertColor(event.alert);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: alertColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (event.cause ?? 'ANOMALY').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm:ss').format(event.serverTimestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.warmGraphite,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'RMS: ${event.rms?.toStringAsFixed(1) ?? "0.0"} · Gas Δ: ${event.gasDelta ?? 0} · Leak: ${event.leakProbability != null ? "${(event.leakProbability! * 100).toInt()}%" : "--"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warmGraphite,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            label: event.alert ?? 'NORMAL',
            type: _getStatusType(event.alert),
          ),
        ],
      ),
    );
  }

  Color _getAlertColor(String? alert) {
    if (alert == null) return AppColors.warmGraphite;
    switch (alert.toUpperCase()) {
      case 'DANGER':
      case 'CRITICAL':
        return AppColors.alertDanger;
      case 'CAUTION':
      case 'WARNING':
        return AppColors.alertCaution;
      case 'OK':
      case 'NOMINAL':
        return AppColors.alertOk;
      default:
        return AppColors.warmGraphite;
    }
  }

  StatusType _getStatusType(String? alert) {
    if (alert == null) return StatusType.neutral;
    switch (alert.toUpperCase()) {
      case 'DANGER':
      case 'CRITICAL':
        return StatusType.danger;
      case 'CAUTION':
      case 'WARNING':
        return StatusType.caution;
      case 'OK':
      case 'NOMINAL':
        return StatusType.ok;
      default:
        return StatusType.neutral;
    }
  }
}
