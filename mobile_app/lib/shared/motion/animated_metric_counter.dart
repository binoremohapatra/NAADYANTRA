import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Animated Metric Counter
///
/// Smoothly tweens numeric changes using tabular monospaced figures.
/// When non-numeric text is provided, renders stably with fade transitions.
class AnimatedMetricCounter extends StatelessWidget {
  final double value;
  final String? unit;
  final String label;
  final int fractionDigits;
  final Color? accentColor;
  final TextStyle? style;

  const AnimatedMetricCounter({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.fractionDigits = 1,
    this.accentColor,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    final defaultTextColor = isDark ? AppColors.pureWhite : AppColors.carbon;
    final color = accentColor ?? defaultTextColor;

    final baseStyle =
        style ??
        TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    final captionColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.warmGraphite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: captionColor,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (isReduced)
              Text(value.toStringAsFixed(fractionDigits), style: baseStyle)
            else
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: value),
                duration: MotionTokens.durationMedium,
                curve: MotionTokens.curveDecelerate,
                builder: (context, val, child) {
                  return Text(
                    val.toStringAsFixed(fractionDigits),
                    style: baseStyle,
                  );
                },
              ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: captionColor,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
