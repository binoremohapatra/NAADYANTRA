import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// Industrial Surface Card
/// Clean, elevated container with crisp borders, subtle header badge,
/// and tactile interactive spring press feedback.
class IndustrialCard extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leadingIcon;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;

  const IndustrialCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.leadingIcon,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  State<IndustrialCard> createState() => _IndustrialCardState();
}

class _IndustrialCardState extends State<IndustrialCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.985,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    final defaultBg = isDark ? AppColors.darkSurface : AppColors.pureWhite;
    final defaultBorder = isDark ? AppColors.darkBorder : AppColors.warmStone;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null ||
            widget.leadingIcon != null ||
            widget.trailing != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                if (widget.leadingIcon != null) ...[
                  widget.leadingIcon!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.title != null)
                        Text(
                          widget.title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: defaultBorder),
        ],
        Padding(
          padding: widget.padding ?? const EdgeInsets.all(16),
          child: widget.child,
        ),
      ],
    );

    final cardWidget = Container(
      margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.borderColor ?? defaultBorder,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.carbon.withValues(alpha: 0.035),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: widget.onTap != null
          ? Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: !isReduced
                    ? (highlighted) {
                        if (highlighted) {
                          _controller.forward();
                        } else {
                          _controller.reverse();
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(12),
                splashColor: AppColors.burntOrange.withValues(alpha: 0.08),
                highlightColor: AppColors.burntOrange.withValues(alpha: 0.04),
                child: content,
              ),
            )
          : content,
    );

    if (widget.onTap == null || isReduced) {
      return cardWidget;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: cardWidget,
    );
  }
}
