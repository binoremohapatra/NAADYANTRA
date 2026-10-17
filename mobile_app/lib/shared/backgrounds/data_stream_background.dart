import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Data Stream / Chronological Waterfall Background
///
/// Designed specifically for Session Archive and Historical Telemetry logs.
/// Renders vertical cascading telemetry data columns, hex markers, and timestamp
/// track graduations drifting gently downward like an industrial telemetry audit tape.
class DataStreamBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const DataStreamBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<DataStreamBackground> createState() => _DataStreamBackgroundState();
}

class _DataStreamBackgroundState extends State<DataStreamBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
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
          painter: _DataStreamPainter(
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
          painter: _DataStreamPainter(
            progress: _controller.value,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _DataStreamPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double opacity;

  _DataStreamPainter({
    required this.progress,
    required this.isDark,
    required this.opacity,
  });

  static const List<String> _hexTokens = [
    '0x4A',
    '0x9E',
    '192k',
    'RMS',
    '48k',
    '0x1F',
    'LEAK',
    'OK',
    'dB',
    'HEX',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colCount = 6;
    final colWidth = size.width / colCount;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      fontSize: 9,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: (isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite)
          .withValues(alpha: 0.35 * opacity),
    );

    for (int col = 0; col < colCount; col++) {
      final x = (col * colWidth) + (colWidth * 0.5);

      // Subtle vertical track rule
      linePaint.color = (isDark ? AppColors.darkBorder : AppColors.warmStone)
          .withValues(alpha: 0.28 * opacity);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

      // Cascading packet marks moving downwards
      final speedMultiplier = 0.8 + (col % 3) * 0.4;
      final offsetRatio = (progress * speedMultiplier + (col * 0.17)) % 1.0;

      // Draw 5 packets per column
      for (int row = 0; row < 5; row++) {
        final rowT = (offsetRatio + (row / 5.0)) % 1.0;
        final y = rowT * size.height;

        // Glowing telemetry bit
        final isHighlighted = (col + row) % 4 == 0;
        dotPaint.color = isHighlighted
            ? AppColors.burntOrange.withValues(alpha: 0.45 * opacity)
            : (isDark ? AppColors.warmGraphite : AppColors.warmStone)
                  .withValues(alpha: 0.25 * opacity);

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, y),
            width: isHighlighted ? 6 : 4,
            height: 2,
          ),
          dotPaint,
        );

        // Occasional technical hex stamp
        if (isHighlighted && row % 2 == 0) {
          final token = _hexTokens[(col + row) % _hexTokens.length];
          final textPainter = TextPainter(
            text: TextSpan(text: token, style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(x + 8, y - 4));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DataStreamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
