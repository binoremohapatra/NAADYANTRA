import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// [ShimmerBox] — NAADYANTRA brand-themed skeleton loading widget.
///
/// Renders a warm-toned sliding shimmer highlight over a rounded rectangle.
/// No external dependencies — uses Flutter's built-in [AnimationController].
/// Respects `MediaQuery.disableAnimationsOf(context)`.
///
/// Usage:
/// ```dart
/// ShimmerBox(width: double.infinity, height: 48)
/// ShimmerBox(width: 120, height: 14, radius: 4)
/// ShimmerBox.card(height: 96)  // pre-composed card shimmer
/// ```
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8.0,
  });

  /// A pre-composed card shimmer with title and content lines.
  static Widget card({double height = 100}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: double.infinity, height: height, radius: 12),
        const SizedBox(height: 10),
      ],
    );
  }

  /// A pre-composed list row shimmer.
  static Widget row({double lineHeight = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ShimmerBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: double.infinity,
                  height: lineHeight,
                  radius: 4,
                ),
                const SizedBox(height: 6),
                ShimmerBox(width: 120, height: lineHeight - 2, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MotionTokens.isReducedMotion(context)) {
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

    final baseColor = isDark
        ? AppColors.darkSurfaceElevated
        : AppColors.warmStone.withValues(alpha: 0.45);
    final highlightColor = isDark
        ? AppColors.darkBorder
        : AppColors.softSand.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
