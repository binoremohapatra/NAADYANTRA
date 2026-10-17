import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

class MetricReadout extends StatefulWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const MetricReadout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  State<MetricReadout> createState() => _MetricReadoutState();
}

class _MetricReadoutState extends State<MetricReadout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    // Try parsing numeric value for animated rolling count
    final cleaned = widget.value.replaceAll(RegExp(r'[^\d.]'), '');
    final numValue = double.tryParse(cleaned);
    final hasDecimal = widget.value.contains('.');
    final prefix = widget.value.startsWith('+') ? '+' : '';

    Widget valueWidget;
    if (numValue != null && !isReduced) {
      valueWidget = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: numValue * 0.7, end: numValue),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, val, _) {
          final displayStr = hasDecimal
              ? '$prefix${val.toStringAsFixed(1)}'
              : '$prefix${val.toInt()}';
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              displayStr,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                color:
                    widget.accentColor ??
                    (isDark ? AppColors.darkTextPrimary : AppColors.carbon),
              ),
            ),
          );
        },
      );
    } else {
      valueWidget = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          widget.value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
            color:
                widget.accentColor ??
                (isDark ? AppColors.darkTextPrimary : AppColors.carbon),
          ),
        ),
      );
    }

    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              widget.accentColor?.withValues(alpha: 0.35) ??
              (isDark ? AppColors.darkBorder : AppColors.warmStone),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.carbon.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color:
                      widget.accentColor ??
                      (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.warmGraphite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: valueWidget),
              if (widget.unit != null && widget.unit!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  widget.unit!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.warmGraphite,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return content;
    }

    if (isReduced) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: content,
      ),
    );
  }
}
